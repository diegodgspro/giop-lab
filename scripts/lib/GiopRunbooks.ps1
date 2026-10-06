# Operator-local SYNTHETIC LAB runbooks. No remotely callable command executor.
$script:GiopRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$script:GiopBaseline = '42e3cbab9758624dfe3be42459f6931ae3519197'
$script:GiopSecrets = @()

function Get-GiopUtc { [DateTime]::UtcNow.ToString('o') }

function Get-GiopSettings {
    $cfg = @{}
    foreach ($line in [IO.File]::ReadAllLines((Join-Path $script:GiopRoot '.env'))) {
        if ($line -match '^\s*([A-Z0-9_]+)\s*=(.*)$') {
            $cfg[$matches[1]] = $matches[2].Trim().Trim('"').Trim("'")
        }
    }
    $script:GiopSecrets = @($cfg.Keys | Where-Object { $_ -match 'PASSWORD|SECRET|TOKEN|CLIENT_ID' } | ForEach-Object { $cfg[$_] } | Where-Object { $_ })
    foreach ($key in @('ZABBIX_FRONTEND_PORT', 'GLPI_FRONTEND_PORT', 'GIOP_INTEGRATION_PORT')) {
        if ($cfg[$key] -and ($cfg[$key] -notmatch '^\d{1,5}$' -or [int]$cfg[$key] -gt 65535 -or [int]$cfg[$key] -lt 1)) { throw 'Invalid local port configuration' }
    }
    return $cfg
}

function Get-GiopSetting($Cfg, $Override, $Fallback, $Default = '') {
    if ($Cfg[$Override]) { return $Cfg[$Override] }
    if ($Cfg[$Fallback]) { return $Cfg[$Fallback] }
    return $Default
}

function Get-GiopFrontend($Port) {
    try {
        $r = Invoke-WebRequest -UseBasicParsing -Uri "http://127.0.0.1:$Port/" -TimeoutSec 5 -MaximumRedirection 0
        if ($r.StatusCode -eq 200) { return 'PASS' }
        return 'DEGRADED'
    } catch {
        # A redirect to the local login page proves frontend connectivity only.
        if ($_.Exception.Response -and [int]$_.Exception.Response.StatusCode -in @(301,302,303)) { return 'PASS' }
        return 'UNKNOWN'
    }
}

function Get-GiopContainers {
    $states = @{}
    foreach ($name in @('gua-lab-srv-web-001','gua-lab-zabbix-server-001','gua-lab-glpi-001','giop-lab-integration-integration-1','giop-lab-control-center-control-center-1')) {
        try {
            # Project only operational state/identity. Never inspect Env or full Docker JSON.
            $text = & docker inspect --format '{{json .State.Status}}|{{if .State.Health}}{{.State.Health.Status}}{{else}}not_configured{{end}}|{{json .Config.Labels}}' $name 2>$null
            if ($LASTEXITCODE -ne 0) { throw 'State unavailable' }
            $parts = ($text -join '').Split('|')
            $labels=$parts[2] | ConvertFrom-Json
            $states[$name] = @{ status=$parts[0].Trim('"'); health=$parts[1]; service=$labels.'com.docker.compose.service'; project=$labels.'com.docker.compose.project' }
        } catch { $states[$name] = @{status='unknown';health='unknown';service='unknown';project='unknown'} }
    }
    return $states
}

function Get-GiopZabbix($Cfg) {
    $port = Get-GiopSetting $Cfg 'ZABBIX_FRONTEND_PORT' '' '8080'
    $url = "http://127.0.0.1:$port/api_jsonrpc.php"
    $token = Get-GiopSetting $Cfg 'CONTROL_CENTER_ZABBIX_API_TOKEN' 'ZABBIX_API_TOKEN'
    $loggedIn = $false
    function Read-Zabbix($Method, $Params) {
        if ($Method -notin @('apiinfo.version','user.login','user.logout','host.get','trigger.get','item.get','problem.get','event.get')) { throw 'Read-only method required' }
        $body = @{jsonrpc='2.0';id=1;method=$Method;params=$Params}
        if ($token -and $Method -notin @('apiinfo.version','user.login')) { $body.auth=$token }
        $r = Invoke-RestMethod -Method Post -Uri $url -ContentType 'application/json' -Body ($body | ConvertTo-Json -Depth 12 -Compress) -TimeoutSec 5
        if ($r.error -or $null -eq $r.result) { throw 'Zabbix read unavailable' }
        return $r.result
    }
    try {
        $version = Read-Zabbix 'apiinfo.version' @{}
        if (-not $token) {
            $username = Get-GiopSetting $Cfg 'CONTROL_CENTER_ZABBIX_USERNAME' 'ZABBIX_API_USERNAME' 'Admin'
            $password = Get-GiopSetting $Cfg 'CONTROL_CENTER_ZABBIX_PASSWORD' 'ZABBIX_API_PASSWORD' $Cfg.ZABBIX_ADMIN_PASSWORD
            $token = Read-Zabbix 'user.login' @{username=$username;password=$password}
            $loggedIn = $true
        }
        $hosts = @(Read-Zabbix 'host.get' @{hostids=@('10683');output=@('hostid','host','name','status')})
        $triggers = @(Read-Zabbix 'trigger.get' @{triggerids=@('25228');output=@('triggerid','description','value','status','expression');expandExpression=$true;selectHosts=@('hostid')})
        $items = @(Read-Zabbix 'item.get' @{hostids=@('10683');filter=@{key_='net.tcp.service[http,gua-lab-srv-web-001,80]'};output=@('itemid','hostid','key_','lastvalue','lastclock','state','status')})
        $problems = @(Read-Zabbix 'problem.get' @{objectids=@('25228');source=0;object=0;recent=$false;output=@('eventid','objectid','clock','name')})
        $events = @(Read-Zabbix 'event.get' @{objectids=@('25228');source=0;object=0;output=@('eventid','objectid','clock','value','r_eventid');sortfield='eventid';sortorder='DESC';limit=8})
        return @{status='PASS';version=$version;hosts=$hosts;triggers=$triggers;items=$items;problems=$problems;events=$events}
    } finally {
        if ($loggedIn) { try { $null = Read-Zabbix 'user.logout' @{} } catch {} }
    }
}

function Get-GiopGlpi($Cfg, $Episode) {
    $port = Get-GiopSetting $Cfg 'GLPI_FRONTEND_PORT' '' '8081'
    $base = "http://127.0.0.1:$port"
    $auth = Invoke-RestMethod -Method Post -Uri "$base/api.php/token" -TimeoutSec 5 -Body @{
        grant_type='password';scope='api'
        username=(Get-GiopSetting $Cfg 'CONTROL_CENTER_GLPI_USERNAME' 'GLPI_INTEGRATION_USERNAME')
        password=(Get-GiopSetting $Cfg 'CONTROL_CENTER_GLPI_PASSWORD' 'GLPI_INTEGRATION_PASSWORD')
        client_id=(Get-GiopSetting $Cfg 'CONTROL_CENTER_GLPI_CLIENT_ID' 'GLPI_INTEGRATION_OAUTH_CLIENT_ID')
        client_secret=(Get-GiopSetting $Cfg 'CONTROL_CENTER_GLPI_CLIENT_SECRET' 'GLPI_INTEGRATION_OAUTH_CLIENT_SECRET')
    }
    $headers = @{Authorization="Bearer $($auth.access_token)";'GLPI-Entity'='0';'GLPI-Entity-Recursive'='false'}
    $computer = Invoke-RestMethod -Uri "$base/api.php/v2.3.0/Assets/Computer/1" -Headers $headers -TimeoutSec 5
    $result = @{status='PASS';computer=@{id=$computer.id;name=$computer.name};ticket=$null;recovery_followup=$null}
    if ($Episode -and "$($Episode.glpi_ticket_id)" -match '^[1-9][0-9]*$') {
        $id = [int]$Episode.glpi_ticket_id
        $t = Invoke-RestMethod -Uri "$base/api.php/v2.3.0/Assistance/Ticket/$id" -Headers $headers -TimeoutSec 5
        $result.ticket = @{id=$t.id;name=$t.name;status=$t.status;external_id=$t.external_id}
        if ($Episode.followup_id -and $Episode.recovery_event_id) {
            $followup = Invoke-RestMethod -Uri "$base/api.php/v2.3.0/Assistance/Ticket/$id/Timeline/Followup/$([int]$Episode.followup_id)" -Headers $headers -TimeoutSec 5
            # Never persist raw ticket/follow-up content. Record only validated reference evidence.
            $content = [string]$followup.content
            $result.recovery_followup = @{id=$followup.id;confirmed=($followup.id -eq $Episode.followup_id -and $content.Contains("Recovery event ID: $($Episode.recovery_event_id)") -and $content.Contains("Original event: $($Episode.event_id)"))}
        }
    }
    return $result
}

function Get-GiopObservation {
    $cfg = Get-GiopSettings
    $zport = Get-GiopSetting $cfg 'ZABBIX_FRONTEND_PORT' '' '8080'
    $gport = Get-GiopSetting $cfg 'GLPI_FRONTEND_PORT' '' '8081'
    $iport = Get-GiopSetting $cfg 'GIOP_INTEGRATION_PORT' '' '8090'
    $s = @{observed_at=(Get-GiopUtc);containers=(Get-GiopContainers);workload_connectivity='UNKNOWN';zabbix_frontend=(Get-GiopFrontend $zport);glpi_frontend=(Get-GiopFrontend $gport);zabbix=@{status='UNKNOWN'};glpi=@{status='UNKNOWN'};integration=@{status='UNKNOWN'};control_center=@{status='UNKNOWN'};episode=$null}
    if ($s.containers['gua-lab-srv-web-001'].status -eq 'running') {
        try {
            $null = & docker exec gua-lab-srv-web-001 wget -q -T 5 -O /dev/null http://127.0.0.1/healthz 2>$null
            $s.workload_connectivity=if ($LASTEXITCODE -eq 0) {'PASS'} else {'DEGRADED'}
        } catch {}
    } elseif ($s.containers['gua-lab-srv-web-001'].status -ne 'unknown') { $s.workload_connectivity='DEGRADED' }
    try { $s.zabbix = Get-GiopZabbix $cfg } catch {}
    try {
        $h = Invoke-RestMethod -Uri "http://127.0.0.1:$iport/health" -TimeoutSec 5
        $episodes = Invoke-RestMethod -Uri "http://127.0.0.1:$iport/api/v1/episodes" -Headers @{'X-GIOP-Webhook-Secret'=$cfg.GIOP_WEBHOOK_SECRET} -TimeoutSec 5
        $s.integration = @{status=$(if ($h.status -eq 'ok' -and $h.database -eq 'ok') {'PASS'} else {'DEGRADED'});mode=$h.mode}
        $pilot = @($episodes | Where-Object { $_.host_id -eq '10683' -and $_.trigger_id -eq '25228' } | Sort-Object { [DateTimeOffset]::Parse($_.problem_time).UtcDateTime } -Descending)
        # Manual synthetic IDs are not chronology. Prefer the current actual Zabbix Problem,
        # then recent actual Zabbix events, rather than the numerically largest episode ID.
        $actual = @($pilot | Where-Object { $_.event_id -in @($s.zabbix.problems | ForEach-Object { $_.eventid }) })
        if (-not $actual.Count) { $actual = @($pilot | Where-Object { $_.event_id -in @($s.zabbix.events | Where-Object { $_.value -eq '1' } | ForEach-Object { $_.eventid }) }) }
        if ($actual.Count) { $pilot=$actual }
        if ($pilot.Count) {
            $e=$pilot[0];$projected=@{}
            foreach ($key in @('event_id','host_id','trigger_id','ci_uid','glpi_ticket_id','status','mode','recovery_event_id','followup_id','problem_time','recovery_time')) { $projected[$key]=$e.$key }
            $s.episode=$projected
        }
    } catch {}
    try { $s.glpi = Get-GiopGlpi $cfg $s.episode } catch {}
    try {
        $h = Invoke-RestMethod -Uri 'http://127.0.0.1:8091/health' -TimeoutSec 5
        $s.control_center = @{status=$(if ($h.status -eq 'ok' -and $h.read_only -and $h.synthetic) {'PASS'} else {'FAIL'})}
    } catch {}
    return $s
}

function Test-GiopRepository {
    try {
        $top = (& git -C $script:GiopRoot rev-parse --show-toplevel 2>$null) -join ''
        $tag = (& git -C $script:GiopRoot rev-parse 'giop-lab-v0.4.0^{}' 2>$null) -join ''
        if ([IO.Path]::GetFullPath($top) -ne $script:GiopRoot -or $tag -ne $script:GiopBaseline) { return $false }
        & git -C $script:GiopRoot merge-base --is-ancestor $script:GiopBaseline HEAD 2>$null
        if ($LASTEXITCODE -ne 0) { return $false }
        $approved = (& git -C $script:GiopRoot show 'giop-lab-v0.4.0:docker/docker-compose.yml' 2>$null) -join "`n"
        $current = [IO.File]::ReadAllText((Join-Path $script:GiopRoot 'docker/docker-compose.yml')).Replace("`r`n","`n").TrimEnd()
        return $approved.TrimEnd() -ceq $current
    } catch { return $false }
}

function Test-GiopPreconditions($Snapshot) {
    $z=$Snapshot.zabbix;$container=$Snapshot.containers['gua-lab-srv-web-001']
    $hostMatch = @($z.hosts).Count -eq 1 -and $z.hosts[0].hostid -eq '10683' -and $z.hosts[0].host -ceq 'GUA-LAB-AGENT-001' -and $z.hosts[0].name -ceq 'GUA-LAB-SRV-WEB-001 synthetic monitor' -and $z.hosts[0].status -eq '0'
    $triggerMatch = @($z.triggers).Count -eq 1 -and $z.triggers[0].triggerid -eq '25228' -and $z.triggers[0].description -ceq 'GIOP-LAB: controlled web workload TCP unavailable' -and $z.triggers[0].expression -ceq 'last(/GUA-LAB-AGENT-001/net.tcp.service[http,gua-lab-srv-web-001,80])=0' -and $z.triggers[0].status -eq '0' -and @($z.triggers[0].hosts).Count -eq 1 -and $z.triggers[0].hosts[0].hostid -eq '10683'
    $itemMatch = @($z.items).Count -eq 1 -and $z.items[0].hostid -eq '10683' -and $z.items[0].key_ -ceq 'net.tcp.service[http,gua-lab-srv-web-001,80]' -and $z.items[0].status -eq '0' -and $z.items[0].state -eq '0'
    $episodeMatch = $true
    if ($triggerMatch -and $z.triggers[0].value -eq '1') {
        $e=$Snapshot.episode
        $episodeMatch = $e -and $e.mode -eq 'live' -and $e.status -eq 'PROBLEM_OPEN' -and $e.ci_uid -ceq 'urn:uuid:9e68f0af-8b55-4b0e-95e4-07dc02a7f6cb' -and $e.glpi_ticket_id -and $Snapshot.glpi.ticket.id -eq $e.glpi_ticket_id -and $Snapshot.glpi.ticket.name -ceq "GIOP-LAB Zabbix synthetic event $($e.event_id)" -and $Snapshot.glpi.ticket.external_id -like "giop:v1:*:problem:$($e.event_id)" -and @($z.problems | Where-Object { $_.eventid -eq $e.event_id }).Count -eq 1
    }
    return @{
        repository_and_approved_compose=(Test-GiopRepository)
        target_identity=($container.service -ceq 'web-workload' -and $container.project -ceq 'giop-lab' -and $container.status -in @('running','exited','created'))
        integration_live=($Snapshot.integration.status -eq 'PASS' -and $Snapshot.integration.mode -eq 'live')
        pilot_host=[bool]$hostMatch;pilot_trigger=[bool]$triggerMatch;pilot_item=[bool]$itemMatch
        problem_episode=[bool]$episodeMatch
        mapped_computer=($Snapshot.glpi.status -eq 'PASS' -and $Snapshot.glpi.computer.id -eq 1 -and $Snapshot.glpi.computer.name -ceq 'GUA-LAB-SRV-WEB-001')
    }
}

function Get-GiopHealthResults($Snapshot) {
    $c=$Snapshot.containers['gua-lab-srv-web-001'];$z=$Snapshot.zabbix
    $workload = if ($c.status -eq 'unknown' -or $Snapshot.workload_connectivity -eq 'UNKNOWN') {'UNKNOWN'} elseif ($c.status -ne 'running' -or $c.health -ne 'healthy' -or $Snapshot.workload_connectivity -ne 'PASS') {'DEGRADED'} else {'PASS'}
    $pilot = if ($z.status -ne 'PASS' -or @($z.triggers).Count -ne 1 -or @($z.items).Count -ne 1) {'UNKNOWN'} elseif ($z.triggers[0].status -ne '0' -or $z.items[0].state -ne '0') {'FAIL'} elseif ($z.triggers[0].value -ne '0' -or $z.items[0].lastvalue -ne '1') {'DEGRADED'} else {'PASS'}
    return @{synthetic_web_workload=$workload;zabbix_frontend=$Snapshot.zabbix_frontend;zabbix_api=$z.status;zabbix_pilot=$pilot;glpi_frontend=$Snapshot.glpi_frontend;glpi_api=$Snapshot.glpi.status;integration=$Snapshot.integration.status;control_center=$Snapshot.control_center.status}
}

function Get-GiopOverall($Results) {
    $values=@($Results.Values)
    if ($values -contains 'FAIL') { return 'FAIL' }
    if ($values -contains 'DEGRADED') { return 'DEGRADED' }
    if ($values -contains 'UNKNOWN') { return 'UNKNOWN' }
    return 'PASS'
}

function Invoke-GiopWorkloadRecovery($Action) {
    if ($Action -notin @('start','restart')) { throw 'Unsupported fixed action' }
    # No container/service/host/command parameter is exposed by the operator scripts.
    # Windows PowerShell 5.1 treats Docker's normal progress on stderr as ErrorRecords.
    # Suppress that stream, use the native exit code, and restore the caller preference.
    $previousPreference=$ErrorActionPreference
    try {
        $ErrorActionPreference='Continue'
        $null = & docker compose --env-file (Join-Path $script:GiopRoot '.env') -f (Join-Path $script:GiopRoot 'docker/docker-compose.yml') $Action web-workload 2>$null
        $nativeExit=$LASTEXITCODE
    } finally { $ErrorActionPreference=$previousPreference }
    if ($nativeExit -ne 0) { throw 'Controlled workload action failed' }
}

function Test-GiopRecovery($Before, $After, $ActionTime) {
    $c=$After.containers['gua-lab-srv-web-001'];$z=$After.zabbix
    $validation = @{workload_running=($c.status -eq 'running');workload_health=($c.health -eq 'healthy' -and $After.workload_connectivity -eq 'PASS');zabbix_recovery_observed=$false;integration_state_observed=$After.episode.status;glpi_ticket_reference=$After.episode.glpi_ticket_id;integration_recovery=$null;glpi_followup=$null}
    if ($z.status -eq 'PASS' -and @($z.triggers).Count -eq 1 -and @($z.items).Count -eq 1) {
        $validation.zabbix_recovery_observed = ($z.triggers[0].value -eq '0' -and $z.items[0].lastvalue -eq '1' -and $z.items[0].state -eq '0' -and [long]$z.items[0].lastclock -ge $ActionTime)
    }
    if ($Before.zabbix.triggers[0].value -eq '1') {
        $e=$After.episode;$old=$Before.episode
        $event=@($z.events | Where-Object { $_.eventid -eq $old.event_id -and $_.r_eventid -eq $e.recovery_event_id -and $_.r_eventid -ne '0' })
        $validation.zabbix_recovery_observed = $validation.zabbix_recovery_observed -and $event.Count -eq 1
        $validation.integration_recovery = ($After.integration.status -eq 'PASS' -and $e.event_id -eq $old.event_id -and $e.glpi_ticket_id -eq $old.glpi_ticket_id -and $e.status -eq 'RECOVERED_PENDING_OPERATOR_VALIDATION' -and $e.recovery_event_id -and $e.followup_id)
        $validation.glpi_followup = ($After.glpi.status -eq 'PASS' -and $After.glpi.ticket.id -eq $old.glpi_ticket_id -and $After.glpi.recovery_followup.confirmed -eq $true)
    }
    $passed=$validation.workload_running -and $validation.workload_health -and $validation.zabbix_recovery_observed
    if ($null -ne $validation.integration_recovery) { $passed=$passed -and $validation.integration_recovery -and $validation.glpi_followup }
    return @{passed=[bool]$passed;checks=$validation}
}

function Write-GiopAudit($Record) {
    $Record.finished_at=Get-GiopUtc
    $json=$Record | ConvertTo-Json -Depth 24
    # Defense in depth after field projection; never persist a known local secret.
    foreach ($secret in $script:GiopSecrets) {
        $encoded=ConvertTo-Json -InputObject ([string]$secret) -Compress
        $json=$json.Replace($encoded.Substring(1,$encoded.Length-2),'[REDACTED]')
        $json=$json.Replace([string]$secret,'[REDACTED]')
    }
    $dir=Join-Path $script:GiopRoot "artifacts/runbooks/$($Record.execution_id)"
    $null=New-Item -ItemType Directory -Path $dir -Force
    $utf8=New-Object Text.UTF8Encoding($false)
    [IO.File]::WriteAllText((Join-Path $dir 'summary.json'),$json,$utf8)
    $safe=$json | ConvertFrom-Json
    $markdown="# $($safe.runbook_id) - SYNTHETIC LAB`n`nExecution: $($safe.execution_id)`nMode: $($safe.mode)`nStatus: $($safe.overall_status)`nStarted: $($safe.started_at)`nFinished: $($safe.finished_at)`nTarget: web-workload / gua-lab-srv-web-001`n`n## Service checks at collection`n`n"
    foreach ($property in $safe.results.health.PSObject.Properties) { $markdown+="- $($property.Name): $($property.Value)`n" }
    $episode=if ($safe.results.after.episode) { $safe.results.after.episode } else { $safe.results.observation.episode }
    $markdown+="`n## Pilot evidence (latest observation)`n`nHost: 10683 / GUA-LAB-SRV-WEB-001`nTrigger: 25228`nProblem: $($episode.event_id)`nTicket: $($episode.glpi_ticket_id)`nRecovery: $($episode.recovery_event_id)`nFollow-up: $($episode.followup_id)`n`n## Actions and validation`n`n"
    foreach ($action in $safe.actions) { $markdown+="- $($action.action): $($action.result); executed=$($action.executed)`n" }
    foreach ($property in $safe.validation.PSObject.Properties) { $markdown+="- $($property.Name): $($property.Value)`n" }
    $markdown+="`nReview summary.json for projected operational evidence. Human validation is required; automatic ticket closure is disabled.`n"
    [IO.File]::WriteAllText((Join-Path $dir 'summary.md'),$markdown,$utf8)
    [IO.File]::WriteAllText((Join-Path $dir 'diagnostics.txt'),"SYNTHETIC LAB - sanitized structured evidence`n$json`n",$utf8)
    Write-Host "Audit: $dir | $($safe.overall_status)"
    return $safe
}

function Invoke-GiopRunbook {
    param([ValidateSet('RB-OPS-001','RB-OPS-002','RB-OPS-003')][string]$RunbookId,[switch]$Execute,[ValidateRange(15,300)][int]$WaitSeconds=180)
    $record=@{execution_id=([DateTime]::UtcNow.ToString('yyyyMMddTHHmmssfffZ')+'-'+[Guid]::NewGuid().ToString('N').Substring(0,8));runbook_id=$RunbookId;environment='SYNTHETIC LAB';started_at=(Get-GiopUtc);finished_at=$null;operator_requested=$true;mode='read-only';target=@{service='web-workload';container='gua-lab-srv-web-001';host_id='10683';trigger_id='25228'};preconditions=@{};actions=@();results=@{};validation=@{};overall_status='UNKNOWN'}
    if ($RunbookId -eq 'RB-OPS-003') { $record.mode=if ($Execute) {'execute'} else {'dry-run'} }
    $mutex=$null;$locked=$false
    try {
        if ($Execute -and $RunbookId -ne 'RB-OPS-003') { throw 'Read-only runbook' }
        if ($RunbookId -eq 'RB-OPS-003' -and $Execute) {
            $mutex=New-Object Threading.Mutex($false,'Local\GIOP-LAB-Controlled-Recovery')
            $locked=$mutex.WaitOne(0)
            if (-not $locked) { throw 'Another local recovery is running' }
        }
        $snapshot=Get-GiopObservation
        $record.results=@{health=(Get-GiopHealthResults $snapshot);observation=$snapshot}
        if ($RunbookId -ne 'RB-OPS-003') {
            $record.overall_status=Get-GiopOverall $record.results.health
            $record.validation=@{collection_complete=($record.overall_status -ne 'UNKNOWN');read_only=$true}
        } else {
            $record.preconditions=Test-GiopPreconditions $snapshot
            $action=if ($snapshot.containers['gua-lab-srv-web-001'].status -eq 'running') {'restart'} else {'start'}
            $record.requested_action=$action
            Write-Host "Target: web-workload / gua-lab-srv-web-001`nAction: $action controlled synthetic service`nEnvironment: SYNTHETIC LAB`nMode: $($record.mode)"
            if (@($record.preconditions.Values | Where-Object { $_ -ne $true }).Count) {
                $record.overall_status='FAIL';$record.actions=@(@{action=$action;result='BLOCKED';executed=$false})
            } elseif (-not $Execute) {
                $record.overall_status='PASS';$record.actions=@(@{action=$action;result='PLAN_ONLY';executed=$false})
            } else {
                # Re-read identity immediately before action; no retries of the mutation.
                $fresh=Get-GiopObservation
                $freshChecks=Test-GiopPreconditions $fresh
                $record.pre_action_checks=$freshChecks
                if (@($freshChecks.Values | Where-Object { $_ -ne $true }).Count -or $fresh.episode.event_id -ne $snapshot.episode.event_id -or $fresh.containers['gua-lab-srv-web-001'].status -ne $snapshot.containers['gua-lab-srv-web-001'].status) { throw 'Pre-action state changed; stopped' }
                $actionTime=[long]([DateTimeOffset]::UtcNow.ToUnixTimeSeconds())
                $record.actions=@(@{action=$action;result='REQUESTED';executed=$true})
                Invoke-GiopWorkloadRecovery $action
                $record.actions[0].result='COMPLETED'
                $deadline=[DateTime]::UtcNow.AddSeconds($WaitSeconds)
                do {
                    $after=Get-GiopObservation
                    $check=Test-GiopRecovery $snapshot $after $actionTime
                    $record.validation=$check.checks
                    $record.results.after=$after
                    if ($check.passed) { break }
                    if ([DateTime]::UtcNow -lt $deadline) { Start-Sleep -Seconds 5 }
                } while ([DateTime]::UtcNow -lt $deadline)
                $record.overall_status=if ($check.passed) {'PASS'} else {'DEGRADED'}
            }
        }
    } catch {
        $record.overall_status='FAIL'
        $record.results.error='Runbook could not complete; inspect projected evidence and local configuration. Raw upstream errors are intentionally excluded.'
        if ($record.actions.Count -and $record.actions[0].result -eq 'REQUESTED') { $record.actions[0].result='UNCONFIRMED' }
    } finally {
        if ($locked) { $mutex.ReleaseMutex() }
        if ($mutex) { $mutex.Dispose() }
    }
    return Write-GiopAudit $record
}
