[CmdletBinding()]
param([switch]$ValidateOnly,[switch]$RepairSyntheticDuplicates)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
$plan = Get-Content -Raw -LiteralPath (Join-Path $repoRoot 'data/glpi-phase2-seed.json') | ConvertFrom-Json
$approvedKeys = @('GLPI_API_BASE_URL','GLPI_API_USERNAME','GLPI_API_PASSWORD','GLPI_OAUTH_CLIENT_ID','GLPI_OAUTH_CLIENT_SECRET')
$cfg = @{}
Get-Content -LiteralPath (Join-Path $repoRoot '.env') | ForEach-Object {
  if ($_ -match '^([^#=]+)=(.*)$' -and $approvedKeys -contains $matches[1]) { $cfg[$matches[1]] = $matches[2] }
}
$base = $cfg.GLPI_API_BASE_URL.TrimEnd('/')
$tokenArgs = @('-sS','-X','POST',"${base}/api.php/token",'-H','Accept: application/json','-H','Content-Type: application/x-www-form-urlencoded')
foreach ($field in @('grant_type=password','scope=api',"username=$($cfg.GLPI_API_USERNAME)","password=$($cfg.GLPI_API_PASSWORD)","client_id=$($cfg.GLPI_OAUTH_CLIENT_ID)","client_secret=$($cfg.GLPI_OAUTH_CLIENT_SECRET)")) { $tokenArgs += @('--data-urlencode',$field) }
$token = (((& curl.exe @tokenArgs) -join "`n") | ConvertFrom-Json).access_token
if (-not $token) { throw 'OAuth token acquisition failed.' }
$getHeaders = @{ Authorization = "Bearer $token"; Accept = 'application/json' }
$jsonHeaders = @{} + $getHeaders; $jsonHeaders['Content-Type'] = 'application/json'

function Get-Collection([string]$path) {
  $all = @(); $start = 0; $limit = 100
  do {
    $response = Invoke-RestMethod -Method Get -Uri "${base}/api.php/${path}?start=${start}&limit=${limit}" -Headers $getHeaders
    $page = @($response | ForEach-Object { $_ })
    $all += $page; $start += $page.Count
  } while ($page.Count -eq $limit)
  foreach ($item in $all) { Write-Output $item }
}
function Ensure-Object([string]$path,[string]$name,[hashtable]$body,[hashtable]$cache) {
  if ($cache.ContainsKey($name)) { return [pscustomobject]@{ object=$cache[$name]; action='reused' } }
  try { $created = Invoke-RestMethod -Method Post -Uri "${base}/api.php/${path}" -Headers $jsonHeaders -Body ($body | ConvertTo-Json -Depth 8) }
  catch { throw "Create failed for ${path}/${name}: $($_.ErrorDetails.Message)" }
  $read = Invoke-RestMethod -Method Get -Uri "${base}/api.php/${path}/$($created.id)" -Headers $getHeaders
  $cache[$name] = $read
  return [pscustomobject]@{ object=$read; action='created' }
}
function New-Name([string]$prefix,[int]$number) { '{0}{1:D3}' -f $prefix,$number }

# The precheck is intentionally read-only and has no Content-Type header.
foreach ($path in @('Administration/Entity','Dropdowns/Location','Assets/Computer','Assets/NetworkEquipment','Assistance/Ticket')) { $null = Invoke-RestMethod -Method Get -Uri "${base}/api.php/${path}" -Headers $getHeaders }
if ($ValidateOnly) { 'PRECHECK=PASS'; exit 0 }

$entityCache = @{}; foreach($entry in @(Get-Collection 'Administration/Entity')) { $entityCache[$entry.name] = $entry }
$locationCache = @{}; foreach($entry in @(Get-Collection 'Dropdowns/Location')) { $locationCache[$entry.name] = $entry }
$allComputers = @(Get-Collection 'Assets/Computer' | Where-Object { -not $_.is_deleted })
$duplicateComputers = @($allComputers | Where-Object { $_.name -like 'GUA-LAB-*' } | Group-Object name | Where-Object { $_.Count -gt 1 })
if ($duplicateComputers.Count -gt 0 -and -not $RepairSyntheticDuplicates) { throw "Synthetic duplicate computers detected ($($duplicateComputers.Count) names). Re-run only with -RepairSyntheticDuplicates after review." }
foreach($group in $duplicateComputers) {
  $keep = @($group.Group | Sort-Object id | Select-Object -First 1)[0]
  foreach($duplicate in @($group.Group | Where-Object { $_.id -ne $keep.id })) {
    $null = Invoke-RestMethod -Method Delete -Uri "${base}/api.php/Assets/Computer/$($duplicate.id)" -Headers $getHeaders
    Write-Host "REMOVED_SYNTHETIC_DUPLICATE TYPE=Computer ID=$($duplicate.id) NAME=$($duplicate.name)"
  }
}
if ($duplicateComputers.Count -gt 0) { $allComputers = @(Get-Collection 'Assets/Computer') }
$computerCache = @{}; foreach($entry in $allComputers) { $computerCache[$entry.name] = $entry }
$networkCache = @{}; foreach($entry in @(Get-Collection 'Assets/NetworkEquipment')) { $networkCache[$entry.name] = $entry }
$ticketCache = @{}; foreach($entry in @(Get-Collection 'Assistance/Ticket')) { $ticketCache[$entry.name] = $entry }
$result = @{ Entity=@(); Location=@(); Computer=@(); NetworkEquipment=@(); Ticket=@(); TicketItemAssociation='Not exposed by the High-Level API schema' }

# Entity creation is deliberately excluded: the API token can read entities but the
# running GLPI authorization rejects entity creation. Locations remain the native
# synthetic topology and are the counted Phase 2 dataset.
if ($entityCache.ContainsKey($plan.entity)) { $result.Entity += @{ id=$entityCache[$plan.entity].id; name=$plan.entity; action='reused' } }
else { $result.Entity += @{ id=$null; name=$plan.entity; action='not-created-api-403' } }
$locations = @($plan.locations.central + $plan.locations.secretariat + $plan.locations.administrative + $plan.locations.school + $plan.locations.earlyEducation + $plan.locations.remote)
foreach ($locationName in $locations) {
  $class = if ($locationName -like 'LAB-SECRETARIA-*') {'secretariat'} elseif ($locationName -like 'LAB-UNIDADE-*') {'administrative'} elseif ($locationName -like 'LAB-ESCOLA-*') {'school'} elseif ($locationName -like 'LAB-CRECHE-*') {'earlyEducation'} elseif ($locationName -like 'LAB-REMOTE-*') {'remote'} else {'central'}
  $item = Ensure-Object 'Dropdowns/Location' $locationName @{ name=$locationName; comment="Synthetic GIOP-LAB $class location; not a real municipal facility." } $locationCache
  $result.Location += @{ id=$item.object.id; name=$item.object.name; locationClass=$class; action=$item.action }
}

$locationOrder = @('LAB-CPD','LAB-PACO','LAB-EDUCATION-HQ','LAB-PACO','LAB-EDUCATION-HQ') + $locations
$serverRoles = @('WEB','DB','FILE','DNS','AUTH','BACKUP','MON','ITSM','APP','MGMT','AUTOMATION')
for ($i=0; $i -lt $serverRoles.Count; $i++) {
  $name = "GUA-LAB-SRV-$($serverRoles[$i])-001"; $loc = $locationCache[$locationOrder[$i % 5]]
  $item = Ensure-Object 'Assets/Computer' $name @{ name=$name; comment="Synthetic GIOP-LAB server-class CI: $($serverRoles[$i])"; location=@{id=$loc.id}; is_recursive=$true } $computerCache
  $result.Computer += @{id=$item.object.id;name=$item.object.name;role='server';location=$loc.name;action=$item.action}
}
for ($i=1; $i -le 116; $i++) {
  $name = New-Name 'GUA-LAB-PC-' $i; $loc=$locationCache[$locationOrder[($i*7 + 3) % $locationOrder.Count]]
  $item=Ensure-Object 'Assets/Computer' $name @{name=$name;comment='Synthetic GIOP-LAB workstation-class CI';location=@{id=$loc.id};is_recursive=$true} $computerCache
  $result.Computer += @{id=$item.object.id;name=$item.object.name;role='workstation';location=$loc.name;action=$item.action}
}

$networkSpecs=@(@{prefix='GUA-LAB-SW-';count=15;role='switch'},@{prefix='GUA-LAB-AP-';count=20;role='access-point'},@{prefix='GUA-LAB-RTR-';count=5;role='router'},@{prefix='GUA-LAB-FW-';count=3;role='firewall'},@{prefix='GUA-LAB-CPE-';count=8;role='wan-cpe'})
$networkLocations=@('LAB-CPD','LAB-PACO','LAB-EDUCATION-HQ','LAB-CPD','LAB-PACO')+$locations
foreach($spec in $networkSpecs){for($i=1;$i -le $spec.count;$i++){$name=New-Name $spec.prefix $i;$loc=$locationCache[$networkLocations[($i*5+$result.NetworkEquipment.Count)%$networkLocations.Count]];$item=Ensure-Object 'Assets/NetworkEquipment' $name @{name=$name;comment="Synthetic GIOP-LAB $($spec.role) network device";location=@{id=$loc.id};is_recursive=$true} $networkCache;$result.NetworkEquipment+=@{id=$item.object.id;name=$item.object.name;role=$spec.role;location=$loc.name;action=$item.action}}}

$ticketGroups=@(@{category='Endpoint';count=24;target='Computer';text='Synthetic workstation connectivity issue'},@{category='Network';count=21;target='NetworkEquipment';text='Synthetic Wi-Fi or WAN degradation'},@{category='Server';count=16;target='Computer';text='Synthetic server service or capacity warning'},@{category='Identity';count=11;target='Computer';text='Synthetic authentication or access issue'},@{category='Backup';count=8;target='Computer';text='Synthetic backup execution failure'},@{category='Peripheral';count=6;target='Computer';text='Synthetic printer or peripheral queue issue'},@{category='Application';count=7;target='Computer';text='Synthetic application service failure'})
$statusPlan=@(@{id=1;name='New';count=14},@{id=2;name='Processing';count=18},@{id=4;name='Pending';count=7},@{id=5;name='Solved';count=21},@{id=6;name='Closed';count=33})
$statuses=@();foreach($s in $statusPlan){1..$s.count|%{$statuses+=,$s}}
$ticketNumber=0;$categoryIndex=0
foreach($group in $ticketGroups){for($i=1;$i -le $group.count;$i++){$ticketNumber++;$name=New-Name 'LAB-INCIDENT-' $ticketNumber;$priority=if($group.category -in @('Network','Server','Backup') -and ($i%5 -eq 0)){5}elseif($group.category -in @('Network','Server','Backup')){4}elseif($i%6 -eq 0){2}else{3};$body=@{name=$name;content="$($group.text). Category: $($group.category). Synthetic GIOP-LAB incident.";urgency=$priority;impact=$priority;priority=$priority;type=1};$item=Ensure-Object 'Assistance/Ticket' $name $body $ticketCache;$target=if($group.target -eq 'Computer'){$result.Computer[($ticketNumber-1)%$result.Computer.Count]}else{$result.NetworkEquipment[($ticketNumber-1)%$result.NetworkEquipment.Count]};$desired=$statuses[$ticketNumber-1];$read=$item.object;if($read.status.id -ne $desired.id){$null=Invoke-RestMethod -Method Patch -Uri "${base}/api.php/Assistance/Ticket/$($read.id)" -Headers $jsonHeaders -Body (@{status=@{id=$desired.id}}|ConvertTo-Json);$read=Invoke-RestMethod -Method Get -Uri "${base}/api.php/Assistance/Ticket/$($read.id)" -Headers $getHeaders};$result.Ticket+=@{id=$read.id;name=$read.name;category=$group.category;priority=$read.priority;status=$read.status.name;statusId=$read.status.id;ci=@{type=$group.target;id=$target.id;name=$target.name};action=$item.action}}}

$manifestDir=Join-Path $repoRoot 'artifacts';New-Item -ItemType Directory -Force -Path $manifestDir|Out-Null;$result|ConvertTo-Json -Depth 8|Set-Content -LiteralPath (Join-Path $manifestDir 'glpi-phase2-created.json') -Encoding utf8
$counts=@{Locations=@($result.Location).Count;Computers=@($result.Computer).Count;NetworkEquipment=@($result.NetworkEquipment).Count;Tickets=@($result.Ticket).Count};"SEED_COMPLETE LOCATIONS=$($counts.Locations) COMPUTERS=$($counts.Computers) NETWORK=$($counts.NetworkEquipment) TICKETS=$($counts.Tickets)"
