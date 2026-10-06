# Offline contract tests: Invoke-RestMethod is replaced by an in-memory JSON-RPC fake.
# No Docker or live Zabbix calls. Fixture secrets are synthetic and temp-only.
$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
$fixture=Join-Path ([IO.Path]::GetTempPath()) ('giop-provisioning-test-'+[guid]::NewGuid().ToString('N'))
$global:giopTestObjects=@{}
$global:giopTestWrites=0
$global:giopTestDuplicateMedia=$false
function Assert-Test($Condition,$Message) {if (-not $Condition) {throw $Message}}
function Invoke-RestMethod {
    param($Uri,$Method,$ContentType,$TimeoutSec,$Body)
    $rpc=$Body|ConvertFrom-Json
    $kind,$verb=$rpc.method.Split('.')
    $p=$rpc.params
    $result=$null
    switch ($rpc.method) {
        'apiinfo.version' {$result='7.0.31'}
        'user.login' {$result='synthetic-test-session'}
        'user.logout' {$result=$true}
        'host.get' {$result=@(@{hostid='10683';host='GUA-LAB-AGENT-001';status='0';hostgroups=@(@{groupid='22'})})}
        'trigger.get' {$result=@(@{triggerid='25228';description='GIOP-LAB: controlled web workload TCP unavailable';priority='3';status='0';value='0';hosts=@(@{hostid='10683'})})}
        'hostgroup.get' {$result=@(@{groupid='22';name='GIOP-LAB Targets'})}
        'role.get' {$result=@(@{roleid='1';name='User role';type='1'})}
        default {
            if ($verb -eq 'get') {
                $result=@()
                if ($global:giopTestObjects.ContainsKey($kind)) {$result=@($global:giopTestObjects[$kind])}
                if ($kind -eq 'mediatype' -and $global:giopTestDuplicateMedia) {$result=@($global:giopTestObjects[$kind],$global:giopTestObjects[$kind])}
            } elseif ($verb -in @('create','update')) {
                $global:giopTestWrites++
                $idField=@{mediatype='mediatypeid';usergroup='usrgrpid';user='userid';action='actionid'}[$kind]
                $id=@{mediatype='101';usergroup='102';user='103';action='104'}[$kind]
                $record=$p|ConvertTo-Json -Depth 30|ConvertFrom-Json
                $record|Add-Member $idField $id -Force
                if ($kind -eq 'user') {
                    $record.PSObject.Properties.Remove('passwd')
                    $record|Add-Member userdirectoryid '0' -Force
                }
                if ($kind -eq 'usergroup') {$record|Add-Member users @() -Force}
                $global:giopTestObjects[$kind]=$record
                $result=@{}; $result[$idField+'s']=@($id)
            } else {throw 'Unexpected test RPC method.'}
        }
    }
    # JSON roundtrip mirrors arrays/PSCustomObject shapes and removes references.
    return (@{jsonrpc='2.0';result=$result;id=1}|ConvertTo-Json -Depth 40|ConvertFrom-Json)
}
try {
    New-Item -ItemType Directory -Force (Join-Path $fixture 'scripts'),(Join-Path $fixture 'docs/demo')|Out-Null
    Copy-Item (Join-Path $root 'scripts/Enable-GiopZabbixDelivery.ps1') (Join-Path $fixture 'scripts')
    Copy-Item (Join-Path $root 'docs/demo/phase3-automatic-delivery.md') (Join-Path $fixture 'docs/demo')
    [IO.File]::WriteAllText((Join-Path $fixture '.env'), "GIOP_WEBHOOK_SECRET=synthetic-test-secret-32-characters`nZABBIX_API_TOKEN=synthetic-test-token`nZABBIX_NOTIFICATION_PASSWORD=synthetic-test-password`n")
    $target=Join-Path $fixture 'scripts/Enable-GiopZabbixDelivery.ps1'
    & $target -WhatIf
    Assert-Test ($global:giopTestWrites -eq 0) 'WhatIf performed a mutation.'
    Assert-Test (-not (Test-Path (Join-Path $fixture '.env.zabbix-alert'))) 'WhatIf wrote scoped secret config.'
    & $target -SkipDockerSetup
    Assert-Test ($global:giopTestWrites -eq 4) 'Expected exactly four initial creates.'
    $action=$global:giopTestObjects.action
    Assert-Test ($action.filter.evaltype -eq 1 -and $action.filter.conditions.Count -eq 2) 'Action must use AND and two pilot conditions.'
    Assert-Test ($action.operations.Count -eq 1 -and $action.recovery_operations.Count -eq 1 -and $action.update_operations.Count -eq 0) 'Unexpected operations.'
    & $target -SkipDockerSetup
    Assert-Test ($global:giopTestWrites -eq 4) 'Second provisioning was not a no-op.'
    # Preserve unrelated templates, rights, group memberships and other user media.
    $global:giopTestObjects.mediatype.message_templates+=@([pscustomobject]@{eventsource=1;recovery=0;subject='unrelated';message='keep'})
    $global:giopTestObjects.usergroup.hostgroup_rights+=@([pscustomobject]@{id='999';permission=2})
    $global:giopTestObjects.user.usrgrps+=@([pscustomobject]@{usrgrpid='999'})
    $global:giopTestObjects.user.medias+=@([pscustomobject]@{mediatypeid='999';sendto=@('lab@example.invalid');active=0;severity=8;period='1-7,00:00-24:00'})
    $global:giopTestObjects.mediatype.maxattempts=3
    & $target -SkipDockerSetup
    Assert-Test ($global:giopTestWrites -eq 5) 'Expected only one drift update.'
    Assert-Test ($global:giopTestObjects.mediatype.message_templates.Count -eq 3) 'Unrelated template removed.'
    Assert-Test ($global:giopTestObjects.user.medias.Count -eq 2 -and $global:giopTestObjects.user.usrgrps.Count -eq 2) 'Unrelated user configuration removed.'
    Assert-Test ($global:giopTestObjects.usergroup.hostgroup_rights.Count -eq 2) 'Unrelated rights removed.'
    $global:giopTestObjects.user.timezone='UTC'
    $global:giopTestObjects.usergroup.gui_access=0
    $global:giopTestObjects.action.status=1
    & $target -SkipDockerSetup
    Assert-Test ($global:giopTestWrites -eq 8) 'Expected three managed drift updates.'
    Assert-Test ($global:giopTestObjects.user.medias.Count -eq 2 -and $global:giopTestObjects.user.usrgrps.Count -eq 2) 'User update removed unrelated configuration.'
    Assert-Test ($global:giopTestObjects.usergroup.hostgroup_rights.Count -eq 2) 'Group update removed unrelated rights.'
    Assert-Test ($null -eq $global:giopTestObjects.user.PSObject.Properties['passwd']) 'User update reset password.'
    & $target -SkipDockerSetup
    Assert-Test ($global:giopTestWrites -eq 8) 'Drift-corrected rerun was not a no-op.'
    $global:giopTestDuplicateMedia=$true
    $rejected=$false
    try {& $target -SkipDockerSetup} catch {$rejected=$_.Exception.Message -like '*Multiple matches*'}
    Assert-Test $rejected 'Duplicate matches were not rejected.'
    Assert-Test ($global:giopTestWrites -eq 8) 'Duplicate collision mutated state.'
    $global:giopTestDuplicateMedia=$false
    $global:giopTestObjects.action.filter.conditions[1].value='999'
    $rejected=$false
    try {& $target -SkipDockerSetup} catch {$rejected=$_.Exception.Message -like '*nonpilot*'}
    Assert-Test $rejected 'Nonpilot Action collision was not rejected.'
    Assert-Test ($global:giopTestWrites -eq 8) 'Nonpilot collision mutated state.'
    Write-Output 'PASS: WhatIf, create, no-op rerun, drift update, preservation, duplicate rejection, pilot-only guards.'
} finally {
    # Only delete the checked absolute, randomly named fixture under the OS temp root.
    $absolute=[IO.Path]::GetFullPath($fixture)
    $tempRoot=[IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\')+'\'
    if ($absolute.StartsWith($tempRoot,[StringComparison]::OrdinalIgnoreCase) -and
        [IO.Path]::GetFileName($absolute) -match '^giop-provisioning-test-[a-f0-9]{32}$') {
        Remove-Item -LiteralPath $absolute -Recurse -Force
    }
}
