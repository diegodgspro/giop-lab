<#
Configure the single Zabbix 7.0.31 pilot through JSON-RPC. No outage is triggered.
-WhatIf: reads/login/logout only; no API mutations, file writes or Docker changes.
#>
[CmdletBinding(SupportsShouldProcess=$true, ConfirmImpact='Low')]
param([switch]$SkipDockerSetup)
$ErrorActionPreference='Stop'
$VerbosePreference='SilentlyContinue'
$DebugPreference='SilentlyContinue'
$ProgressPreference='SilentlyContinue'
function Initialize-GiopDelivery {
$ErrorActionPreference = 'Stop'
if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
    throw 'Docker CLI required; run from the operator terminal or use -SkipDockerSetup when already prepared.'
}
. "$PSScriptRoot/GiopIntegration.Common.ps1"
$root = Split-Path $PSScriptRoot -Parent
$cfg = Get-GiopIntegrationConfig
if ($cfg.GIOP_WEBHOOK_SECRET -notmatch '^[A-Za-z0-9_-]{32,}$') {
    throw 'Webhook secret must use at least 32 ASCII letters, digits, underscores or hyphens.'
}
$scopedPath = Join-Path $root '.env.zabbix-alert'
# UTF-8 without BOM, LF: never write values to stdout or process arguments.
[IO.File]::WriteAllText($scopedPath, ('GIOP_WEBHOOK_SECRET=' + $cfg.GIOP_WEBHOOK_SECRET + "`n"),
    [Text.UTF8Encoding]::new($false))
Push-Location $root
try {
    docker compose --env-file .env -f docker/docker-compose.yml -f docker/docker-compose.integration-source.yml config --quiet
    if ($LASTEXITCODE -ne 0) { throw 'Source Compose validation failed.' }
    docker compose --env-file .env -f docker/docker-compose.yml -f docker/docker-compose.integration-source.yml up -d --no-deps zabbix-server
    if ($LASTEXITCODE -ne 0) { throw 'Zabbix source layer failed.' }
    docker exec gua-lab-zabbix-server-001 sh -c 'test -x /usr/lib/zabbix/alertscripts/giop-alert.sh && test -r /run/giop/alert.env && sh -n /usr/lib/zabbix/alertscripts/giop-alert.sh'
    if ($LASTEXITCODE -ne 0) { throw 'Alert script/config access validation failed.' }
    docker exec gua-lab-zabbix-server-001 curl --silent --show-error --fail --max-time 10 http://integration:8090/health
    if ($LASTEXITCODE -ne 0) { throw 'Zabbix to integration connectivity failed.' }
} finally {
    Pop-Location
    $cfg.Clear()
}

}

$root=Split-Path $PSScriptRoot -Parent
$cfg=@{}
$token=$null
$loggedIn=$false
$mutex=$null
$ownsMutex=$false
function Invoke-GiopRpc {
    param([string]$Method, [object]$Params)
    $allowed=@('apiinfo.version','user.login','user.logout','host.get','trigger.get','hostgroup.get','role.get',
        'mediatype.get','mediatype.create','mediatype.update','usergroup.get','usergroup.create','usergroup.update',
        'user.get','user.create','user.update','action.get','action.create','action.update')
    if ($Method -notin $allowed -or ($WhatIfPreference -and $Method -match '\.(create|update)$')) { throw 'Unsupported or dry-run mutation blocked.' }
    $body=@{jsonrpc='2.0';method=$Method;params=$Params;id=1}
    if ($token -and $Method -notin @('apiinfo.version','user.login')) {$body.auth=$token}
    try {
        $r=Invoke-RestMethod -Uri $apiUrl -Method Post -ContentType application/json-rpc -TimeoutSec 20 -Body ($body|ConvertTo-Json -Depth 30 -Compress)
        if ($r.error -or $null -eq $r.PSObject.Properties['result']) {throw 'API rejected'}
        return $r.result
    } catch {throw "Zabbix API failed: $Method. No mutation retry; inspect configuration before rerunning."}
}
function Get-One {
    param([string]$Method,[hashtable]$Query,[string]$Label)
    $rows=@(Invoke-GiopRpc $Method $Query)
    if ($rows.Count -gt 1) {throw "Multiple matches for $Label; refusing duplicates."}
    if ($rows.Count -eq 1) {return $rows[0]}
    return $null
}
function Test-Desired {
    param($Actual,$Desired)
    if ($null -eq $Actual) {return $null -eq $Desired}
    if ($Desired -is [System.Collections.IDictionary]) {
        foreach ($key in $Desired.Keys) {
            if ($Actual -is [System.Collections.IDictionary]) {$value=$Actual[$key]} else {$value=$Actual.$key}
            if (-not (Test-Desired $value $Desired[$key])) {return $false}
        }
        return $true
    }
    if ($Desired -is [array]) {
        $items=@($Actual); $used=@{}
        if ($items.Count -ne $Desired.Count) {return $false}
        foreach ($wanted in $Desired) {
            $found=$false
            for ($i=0;$i -lt $items.Count;$i++) {
                if (-not $used.ContainsKey($i) -and (Test-Desired $items[$i] $wanted)) {$used[$i]=$true;$found=$true;break}
            }
            if (-not $found) {return $false}
        }
        return $true
    }
    return [string]$Actual -ceq [string]$Desired
}
function Set-ManagedObject {
    param([string]$Kind,[string]$IdField,[string]$ResultField,[hashtable]$Query,[hashtable]$Desired,[string]$Label,[string]$CreatePassword)
    # Search again before mutation; never retry a failed/ambiguous POST.
    $existing=Get-One "$Kind.get" $Query $Label
    if ($existing -and (Test-Desired $existing $Desired)) {Write-Host "UNCHANGED: $Label";return [string]$existing.$IdField}
    $verb=if ($existing) {'update'} else {'create'}
    if ($PSCmdlet.ShouldProcess($Label,"$Kind.$verb")) {
        $params=@{}+$Desired
        if ($existing) {$params[$IdField]=[string]$existing.$IdField}
        elseif ($Kind -eq 'user') {$params.passwd=$CreatePassword}
        $result=Invoke-GiopRpc "$Kind.$verb" $params
        $ids=@($result.$ResultField)
        if ($ids.Count -ne 1 -or [string]$ids[0] -notmatch '^[1-9][0-9]*$') {throw "Unconfirmed result for $Label."}
        $readback=Get-One "$Kind.get" $Query $Label
        if (-not $readback -or -not (Test-Desired $readback $Desired)) {throw "Readback mismatch for $Label; inspect before rerunning."}
        Write-Host "APPLIED: $Label"
        return [string]$ids[0]
    }
    if ($existing) {return [string]$existing.$IdField}
    return "planned-$Kind"
}
try {
    $keys=@('GIOP_WEBHOOK_SECRET','ZABBIX_FRONTEND_PORT','ZABBIX_API_URL','ZABBIX_API_TOKEN','ZABBIX_API_USERNAME',
        'ZABBIX_API_PASSWORD','ZABBIX_ADMIN_PASSWORD','ZABBIX_NOTIFICATION_PASSWORD')
    foreach ($line in [IO.File]::ReadAllLines((Join-Path $root '.env'))) {
        if ($line -match '^\s*([^#=\s]+)\s*=(.*)$' -and $matches[1] -in $keys) {$cfg[$matches[1]]=$matches[2].Trim().Trim('"').Trim("'")}
    }
    if ($cfg.GIOP_WEBHOOK_SECRET -notmatch '^[A-Za-z0-9_-]{32,}$') {throw 'Configure GIOP_WEBHOOK_SECRET in ignored .env.'}
    $port=if ($cfg.ZABBIX_FRONTEND_PORT) {$cfg.ZABBIX_FRONTEND_PORT} else {'8080'}
    if ($port -notmatch '^\d{1,5}$') {throw 'Invalid Zabbix port.'}
    $apiUrl=if ($cfg.ZABBIX_API_URL) {$cfg.ZABBIX_API_URL} else {"http://127.0.0.1:$port/api_jsonrpc.php"}
    $uri=[uri]$apiUrl
    if (-not $uri.IsAbsoluteUri -or -not $uri.IsLoopback -or $uri.Scheme -notin @('http','https') -or $uri.UserInfo -or
        $uri.Query -or $uri.Fragment -or $uri.AbsolutePath -ne '/api_jsonrpc.php') {throw 'Use a localhost JSON-RPC URL without embedded credentials.'}
    $mutex=[Threading.Mutex]::new($false,'Local\GIOP-LAB-Zabbix-Pilot-Provisioning')
    try {$ownsMutex=$mutex.WaitOne(0)} catch [Threading.AbandonedMutexException] {$ownsMutex=$true}
    if (-not $ownsMutex) {throw 'Another local provisioning run is active.'}
    $version=Invoke-GiopRpc apiinfo.version @{}
    if ($version -ne '7.0.31') {throw 'Expected Zabbix 7.0.31; revalidate before another version.'}
    Write-Host "API_VERSION=$version"
    if ($cfg.ZABBIX_API_TOKEN) {$token=$cfg.ZABBIX_API_TOKEN}
    else {
        $username=if ($cfg.ZABBIX_API_USERNAME) {$cfg.ZABBIX_API_USERNAME} else {'Admin'}
        $password=if ($cfg.ZABBIX_API_PASSWORD) {$cfg.ZABBIX_API_PASSWORD} else {$cfg.ZABBIX_ADMIN_PASSWORD}
        if (-not $password) {throw 'Configure Zabbix API authentication in ignored .env.'}
        $token=Invoke-GiopRpc user.login @{username=$username;password=$password}
        $password=$null;$loggedIn=$true
    }
    # Preflight all identities/collisions before Docker or API mutations.
    $hostRow=Get-One host.get @{hostids=@('10683');output=@('hostid','host','name','status');selectHostGroups=@('groupid')} 'pilot host'
    $trigger=Get-One trigger.get @{triggerids=@('25228');output=@('triggerid','description','priority','status','value');selectHosts=@('hostid')} 'pilot trigger'
    if (-not $hostRow -or -not $trigger -or $hostRow.status -ne '0' -or $trigger.status -ne '0' -or
        $trigger.description -cne 'GIOP-LAB: controlled web workload TCP unavailable' -or $trigger.priority -ne '3' -or
        @($trigger.hosts).Count -ne 1 -or $trigger.hosts[0].hostid -ne '10683') {throw 'Pilot identity/enabled state/severity mismatch.'}
    if ($trigger.value -ne '0') {throw 'Pilot must be OK before provisioning; restore workload first.'}
    $hostGroup=Get-One hostgroup.get @{filter=@{name='GIOP-LAB Targets'};output=@('groupid','name')} 'pilot host group'
    if (-not $hostGroup -or $hostGroup.groupid -notin @($hostRow.hostgroups|ForEach-Object {$_.groupid})) {throw 'Pilot host group mismatch.'}
    $role=Get-One role.get @{filter=@{name='User role';type=1};output=@('roleid','name','type')} 'User role'
    if (-not $role) {throw 'Expected existing User role not found.'}
    $mq=@{filter=@{name='GIOP LAB'};output='extend';selectMessageTemplates='extend'}
    $gq=@{filter=@{name='GIOP LAB Notifications'};output='extend';selectHostGroupRights='extend';selectUsers=@('userid')}
    $uq=@{filter=@{username='giop-lab-notifications'};output='extend';selectMedias='extend';selectUsrgrps=@('usrgrpid')}
    $aq=@{filter=@{name='GIOP-LAB - Pilot Event to Incident'};output='extend';selectFilter='extend';selectOperations='extend';selectRecoveryOperations='extend';selectUpdateOperations='extend'}
    $media=Get-One mediatype.get $mq 'GIOP LAB'
    $group=Get-One usergroup.get $gq 'GIOP LAB Notifications'
    $user=Get-One user.get $uq 'giop-lab-notifications'
    $action=Get-One action.get $aq 'GIOP-LAB - Pilot Event to Incident'
    if ($media -and ($media.type -ne '1' -or $media.exec_path -cne 'giop-alert.sh')) {throw 'Media collision; unrelated configuration preserved.'}
    if ($user -and ($user.roleid -ne $role.roleid -or $user.userdirectoryid -ne '0')) {throw 'Recipient collision; existing role/provisioning preserved.'}
    if ($group -and @($group.users|Where-Object {-not $user -or $_.userid -ne $user.userid}).Count) {throw 'Group has unrelated users; refusing changes.'}
    $conditions=@(@{conditiontype=1;operator=0;value='10683'},@{conditiontype=2;operator=0;value='25228'})
    if ($action -and ($action.eventsource -ne '0' -or -not (Test-Desired $action.filter @{evaltype=1;conditions=$conditions}))) {throw 'Action collision/nonpilot conditions; refusing changes.'}
    if ($action) {
        foreach ($op in @($action.operations)+@($action.recovery_operations)+@($action.update_operations)) {
            if ($op.operationtype -ne '0' -or -not $media -or -not $user -or $op.opmessage.mediatypeid -ne $media.mediatypeid -or
                @($op.opmessage_grp | Where-Object {$null -ne $_}).Count -gt 0 -or @($op.opmessage_usr).Count -ne 1 -or $op.opmessage_usr[0].userid -ne $user.userid) {throw 'Action has unrelated operations; refusing replacement.'}
        }
    }
    if (-not $user -and -not $cfg.ZABBIX_NOTIFICATION_PASSWORD) {
        if ($WhatIfPreference) {Write-Host 'REQUIRED_FOR_APPLY: ZABBIX_NOTIFICATION_PASSWORD in ignored .env'}
        else {throw 'Configure ZABBIX_NOTIFICATION_PASSWORD in ignored .env to create the recipient.'}
    }
    $problem='{"kind":"PROBLEM","event_id":"{EVENT.ID}","host_id":"10683","trigger_id":"25228","host":"GUA-LAB-SRV-WEB-001","trigger":"GIOP-LAB: controlled web workload TCP unavailable","severity":{EVENT.NSEVERITY},"event_time":"{EVENT.DATE}T{EVENT.TIME}-03:00"}'
    $recovery='{"kind":"RECOVERY","event_id":"{EVENT.RECOVERY.ID}","problem_event_id":"{EVENT.ID}","host_id":"10683","trigger_id":"25228","host":"GUA-LAB-SRV-WEB-001","trigger":"GIOP-LAB: controlled web workload TCP unavailable","severity":{EVENT.NSEVERITY},"event_time":"{EVENT.RECOVERY.DATE}T{EVENT.RECOVERY.TIME}-03:00"}'
    $doc=[IO.File]::ReadAllText((Join-Path $root 'docs/demo/phase3-automatic-delivery.md'))
    if (-not $doc.Contains($problem) -or -not $doc.Contains($recovery)) {throw 'Documented payloads differ from provisioning templates.'}
    if (-not $SkipDockerSetup -and $PSCmdlet.ShouldProcess('Zabbix source layer','Write scoped secret file and apply Compose')) {Initialize-GiopDelivery}
    $templates=@(@{eventsource=0;recovery=0;subject='GIOP LAB PROBLEM';message=$problem},@{eventsource=0;recovery=1;subject='GIOP LAB RECOVERY';message=$recovery})
    if ($media) {$templates+=@($media.message_templates|Where-Object {$_.eventsource -ne '0' -or $_.recovery -notin @('0','1')}|ForEach-Object {@{eventsource=$_.eventsource;recovery=$_.recovery;subject=$_.subject;message=$_.message}})}
    $mediaId=Set-ManagedObject mediatype mediatypeid mediatypeids $mq @{
        name='GIOP LAB';type=1;exec_path='giop-alert.sh';status=0;maxsessions=1;maxattempts=1;attempt_interval='10s'
        parameters=@(@{sortorder=0;value='{ALERT.MESSAGE}'});message_templates=$templates
    } 'GIOP LAB'
    $rights=@(@{id=[string]$hostGroup.groupid;permission=2})
    if ($group) {$rights+=@($group.hostgroup_rights|Where-Object {$_.id -ne $hostGroup.groupid}|ForEach-Object {@{id=$_.id;permission=$_.permission}})}
    $groupId=Set-ManagedObject usergroup usrgrpid usrgrpids $gq @{name='GIOP LAB Notifications';gui_access=3;users_status=0;hostgroup_rights=$rights} 'GIOP LAB Notifications'
    $groups=@(@{usrgrpid=$groupId})
    $medias=@(@{mediatypeid=$mediaId;sendto='giop-lab';active=0;severity=8;period='1-7,00:00-24:00'})
    if ($user) {
        $groups+=@($user.usrgrps|Where-Object {$_.usrgrpid -ne $groupId}|ForEach-Object {@{usrgrpid=$_.usrgrpid}})
        $medias+=@($user.medias|Where-Object {$_.mediatypeid -ne $mediaId}|ForEach-Object {@{mediatypeid=$_.mediatypeid;sendto=$_.sendto;active=$_.active;severity=$_.severity;period=$_.period}})
    }
    $userId=Set-ManagedObject user userid userids $uq @{username='giop-lab-notifications';roleid=[string]$role.roleid;timezone='America/Sao_Paulo';usrgrps=$groups;medias=$medias} 'giop-lab-notifications' $cfg.ZABBIX_NOTIFICATION_PASSWORD
    $op=@{operationtype=0;esc_step_from=1;esc_step_to=1;esc_period='0s';evaltype=0;opmessage=@{default_msg=1;mediatypeid=$mediaId};opmessage_usr=@(@{userid=$userId});opconditions=@()}
    $rop=@{operationtype=0;opmessage=@{default_msg=1;mediatypeid=$mediaId};opmessage_usr=@(@{userid=$userId})}
    $null=Set-ManagedObject action actionid actionids $aq @{
        name='GIOP-LAB - Pilot Event to Incident';eventsource=0;status=0;esc_period='1h';pause_suppressed=1;notify_if_canceled=0
        filter=@{evaltype=1;conditions=$conditions};operations=@($op);recovery_operations=@($rop);update_operations=@()
    } 'GIOP-LAB - Pilot Event to Incident'
    Write-Host 'PILOT_ONLY: host 10683 AND trigger 25228; no outage triggered.'
} finally {
    if ($loggedIn -and $token) {try {$null=Invoke-GiopRpc user.logout @{}} catch {Write-Warning 'Logout failed; token suppressed.'}}
    if ($ownsMutex) {$mutex.ReleaseMutex()}
    if ($mutex) {$mutex.Dispose()}
    $token=$null;$password=$null;$cfg.Clear()
}
