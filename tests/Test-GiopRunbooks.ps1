# Proportional offline tests. Docker/API calls are mocked; no workload outage.
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot '../scripts/lib/GiopRunbooks.ps1')
$script:tests=0
function Assert($Condition,$Message) { if (-not $Condition) { throw $Message } }
function Test-Case($Name,[scriptblock]$Body) { & $Body; $script:tests++; Write-Host "PASS $Name" }
function New-Fixture {
    return @{
        observed_at=(Get-GiopUtc);workload_connectivity='PASS';zabbix_frontend='PASS';glpi_frontend='PASS'
        containers=@{'gua-lab-srv-web-001'=@{status='running';health='healthy';service='web-workload';project='giop-lab'}}
        integration=@{status='PASS';mode='live'};control_center=@{status='PASS'}
        glpi=@{status='PASS';computer=@{id=1;name='GUA-LAB-SRV-WEB-001'};ticket=@{id=96;name='GIOP-LAB Zabbix synthetic event 101';external_id='giop:v1:synthetic-fixture:problem:101'};recovery_followup=@{id=3;confirmed=$true}}
        episode=@{event_id='101';host_id='10683';trigger_id='25228';mode='live';status='PROBLEM_OPEN';ci_uid='urn:uuid:9e68f0af-8b55-4b0e-95e4-07dc02a7f6cb';glpi_ticket_id=96;followup_id=$null;recovery_event_id=$null}
        zabbix=@{status='PASS';hosts=@(@{hostid='10683';host='GUA-LAB-AGENT-001';name='GUA-LAB-SRV-WEB-001 synthetic monitor';status='0'});triggers=@(@{triggerid='25228';description='GIOP-LAB: controlled web workload TCP unavailable';expression='last(/GUA-LAB-AGENT-001/net.tcp.service[http,gua-lab-srv-web-001,80])=0';hosts=@(@{hostid='10683'});status='0';value='0'});items=@(@{hostid='10683';key_='net.tcp.service[http,gua-lab-srv-web-001,80]';status='0';state='0';lastvalue='1';lastclock=([DateTimeOffset]::UtcNow.ToUnixTimeSeconds()+1)});problems=@(@{eventid='101'});events=@(@{eventid='101';value='1';r_eventid='102'})}
    }
}
$realRepositoryTest=${function:Test-GiopRepository}
$realAction=${function:Invoke-GiopWorkloadRecovery}
Test-Case 'correct repository and frozen Compose accepted' { Assert (& $realRepositoryTest) 'Repository identity failed' }
function Test-GiopRepository { return $script:repositoryApproved }
function Get-GiopObservation { if ($script:applied) { return $script:after };return $script:fixture }
function Invoke-GiopWorkloadRecovery($Action) { $script:actionCalls+=@($Action);$script:applied=$true }
function Reset-Fixture { $script:fixture=New-Fixture;$script:after=New-Fixture;$script:applied=$false;$script:actionCalls=@();$script:repositoryApproved=$true;$script:GiopSecrets=@('synthetic-secret-for-audit-test') }

Test-Case 'health healthy state and audit schema' {
    Reset-Fixture
    $r=Invoke-GiopRunbook RB-OPS-001
    Assert ($r.overall_status -eq 'PASS') 'Healthy state failed'
    foreach ($field in @('execution_id','runbook_id','environment','started_at','finished_at','operator_requested','mode','target','preconditions','actions','results','validation','overall_status')) { Assert ($r.PSObject.Properties.Name -contains $field) "Missing audit field $field" }
    Assert ($r.actions.Count -eq 0) 'Read-only runbook executed an action'
}
Test-Case 'health degraded state' {
    Reset-Fixture;$script:fixture.containers['gua-lab-srv-web-001'].status='exited';$script:fixture.workload_connectivity='DEGRADED';$script:fixture.zabbix.triggers[0].value='1'
    $r=Invoke-GiopRunbook RB-OPS-001
    Assert ($r.overall_status -eq 'DEGRADED') 'Degraded state hidden'
}
Test-Case 'health unknown and failed states' {
    Reset-Fixture;$script:fixture.control_center.status='UNKNOWN'
    Assert ((Get-GiopOverall (Get-GiopHealthResults $script:fixture)) -eq 'UNKNOWN') 'Unknown became healthy'
    $script:fixture.zabbix.items[0].state='1'
    Assert ((Get-GiopOverall (Get-GiopHealthResults $script:fixture)) -eq 'FAIL') 'Unsupported item not failed'
}
Test-Case 'diagnostics artifacts generated and known secrets excluded' {
    Reset-Fixture;$script:fixture.zabbix.hosts[0].name='synthetic-secret-for-audit-test'
    $r=Invoke-GiopRunbook RB-OPS-002
    $dir=Join-Path $script:GiopRoot "artifacts/runbooks/$($r.execution_id)"
    foreach ($name in @('summary.json','summary.md','diagnostics.txt')) {
        $path=Join-Path $dir $name
        Assert (Test-Path $path) "Missing $name"
        Assert (-not ([IO.File]::ReadAllText($path).Contains('synthetic-secret-for-audit-test'))) 'Secret persisted'
    }
    Assert ($script:actionCalls.Count -eq 0) 'Diagnostics wrote to workload'
}
Test-Case 'default approved target is plan only' {
    Reset-Fixture
    $r=Invoke-GiopRunbook RB-OPS-003
    Assert ($r.overall_status -eq 'PASS' -and $r.mode -eq 'dry-run' -and $r.actions[0].result -eq 'PLAN_ONLY') 'Dry run failed'
    Assert ($script:actionCalls.Count -eq 0) 'Default executed'
}
Test-Case 'incorrect container service blocked' {
    Reset-Fixture;$script:fixture.containers['gua-lab-srv-web-001'].service='glpi'
    $r=Invoke-GiopRunbook RB-OPS-003 -Execute
    Assert ($r.overall_status -eq 'FAIL' -and $r.actions[0].result -eq 'BLOCKED' -and $script:actionCalls.Count -eq 0) 'Wrong target executed'
}
Test-Case 'incorrect host identity blocked' {
    Reset-Fixture;$script:fixture.zabbix.hosts[0].hostid='999'
    $r=Invoke-GiopRunbook RB-OPS-003 -Execute
    Assert ($r.overall_status -eq 'FAIL' -and $script:actionCalls.Count -eq 0) 'Wrong host executed'
}
Test-Case 'incorrect trigger or expression blocked' {
    Reset-Fixture;$script:fixture.zabbix.triggers[0].triggerid='999'
    Assert (-not (Test-GiopPreconditions $script:fixture).pilot_trigger) 'Wrong trigger accepted'
    Reset-Fixture;$script:fixture.zabbix.triggers[0].expression='last(/other/other)=0'
    $r=Invoke-GiopRunbook RB-OPS-003 -Execute
    Assert ($r.overall_status -eq 'FAIL' -and $script:actionCalls.Count -eq 0) 'Wrong expression executed'
}
Test-Case 'ambiguous host blocked' {
    Reset-Fixture;$script:fixture.zabbix.hosts+=@($script:fixture.zabbix.hosts[0])
    $r=Invoke-GiopRunbook RB-OPS-003 -Execute
    Assert ($r.overall_status -eq 'FAIL' -and $script:actionCalls.Count -eq 0) 'Ambiguous identity executed'
}
Test-Case 'unknown integration and changed Compose blocked' {
    Reset-Fixture;$script:fixture.integration.mode='dry-run'
    Assert (-not (Test-GiopPreconditions $script:fixture).integration_live) 'Dry-run integration accepted'
    Reset-Fixture;$script:repositoryApproved=$false
    $r=Invoke-GiopRunbook RB-OPS-003 -Execute
    Assert ($r.overall_status -eq 'FAIL' -and $script:actionCalls.Count -eq 0) 'Unapproved Compose executed'
}
Test-Case 'problem without current correlated episode blocked' {
    Reset-Fixture;$script:fixture.zabbix.triggers[0].value='1';$script:fixture.episode.event_id='999'
    $r=Invoke-GiopRunbook RB-OPS-003 -Execute
    Assert ($r.overall_status -eq 'FAIL' -and $script:actionCalls.Count -eq 0) 'Mismatched problem executed'
}
Test-Case 'mismatched GLPI Ticket reference blocked' {
    Reset-Fixture;$script:fixture.zabbix.triggers[0].value='1';$script:fixture.glpi.ticket.name='Unrelated Ticket'
    $r=Invoke-GiopRunbook RB-OPS-003 -Execute
    Assert ($r.overall_status -eq 'FAIL' -and $script:actionCalls.Count -eq 0) 'Unrelated Ticket accepted'
}
Test-Case 'explicit approved recovery and post-action audit' {
    Reset-Fixture;$script:fixture.zabbix.triggers[0].value='1';$script:fixture.containers['gua-lab-srv-web-001'].status='exited'
    $script:after.episode.status='RECOVERED_PENDING_OPERATOR_VALIDATION';$script:after.episode.recovery_event_id='102';$script:after.episode.followup_id=3
    $r=Invoke-GiopRunbook RB-OPS-003 -Execute -WaitSeconds 15
    Assert ($r.overall_status -eq 'PASS' -and $r.actions[0].executed -and $r.validation.zabbix_recovery_observed -and $r.validation.glpi_followup) 'Recovery validation failed'
    Assert ($script:actionCalls.Count -eq 1 -and $script:actionCalls[0] -eq 'start') 'Unexpected action'
}
Test-Case 'recovery requires fresh item and confirmed GLPI followup' {
    Reset-Fixture;$script:fixture.zabbix.triggers[0].value='1';$script:after.episode.status='RECOVERED_PENDING_OPERATOR_VALIDATION';$script:after.episode.recovery_event_id='102';$script:after.episode.followup_id=3
    $script:after.glpi.recovery_followup.confirmed=$false
    Assert (-not (Test-GiopRecovery $script:fixture $script:after 1).passed) 'Missing followup accepted'
    $script:after.glpi.recovery_followup.confirmed=$true;$script:after.zabbix.items[0].lastclock=0
    Assert (-not (Test-GiopRecovery $script:fixture $script:after 1).passed) 'Stale item accepted'
}
Test-Case 'native recovery command is restricted to approved Compose service' {
    Reset-Fixture
    function docker { $script:dockerArgs=@($args);$global:LASTEXITCODE=0 }
    & $realAction 'start'
    Assert (($script:dockerArgs -join '|') -eq "compose|--env-file|$(Join-Path $script:GiopRoot '.env')|-f|$(Join-Path $script:GiopRoot 'docker/docker-compose.yml')|start|web-workload") 'Native target escaped allowlist'
    & $realAction 'restart'
    Assert ($script:dockerArgs[-1] -eq 'web-workload' -and $script:dockerArgs[-2] -eq 'restart') 'Restart target escaped allowlist'
    $blocked=$false;try { & $realAction 'arbitrary-command' } catch { $blocked=$true }
    Assert $blocked 'Arbitrary action accepted'
}
Test-Case 'unavailable collection still records sanitized failure audit' {
    function Get-GiopObservation { throw 'synthetic-secret-for-audit-test' }
    $r=Invoke-GiopRunbook RB-OPS-002
    Assert ($r.overall_status -eq 'FAIL' -and -not (($r | ConvertTo-Json -Depth 24).Contains('synthetic-secret-for-audit-test'))) 'Failure exposed secret or lost audit'
}
Write-Host "$script:tests runbook tests passed; no real Docker actions or API calls."
