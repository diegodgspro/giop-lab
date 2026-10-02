[CmdletBinding()]
param()
$ErrorActionPreference='Stop'
$root=Split-Path -Parent $PSScriptRoot
$keys=@('GLPI_API_BASE_URL','GLPI_API_USERNAME','GLPI_API_PASSWORD','GLPI_OAUTH_CLIENT_ID','GLPI_OAUTH_CLIENT_SECRET')
$cfg=@{}
Get-Content (Join-Path $root '.env') | ForEach-Object { if($_ -match '^([^#=]+)=(.*)$' -and $keys -contains $matches[1]){$cfg[$matches[1]]=$matches[2]} }
$base=$cfg.GLPI_API_BASE_URL.TrimEnd('/')
$form=@('grant_type=password','scope=api',"username=$($cfg.GLPI_API_USERNAME)","password=$($cfg.GLPI_API_PASSWORD)","client_id=$($cfg.GLPI_OAUTH_CLIENT_ID)","client_secret=$($cfg.GLPI_OAUTH_CLIENT_SECRET)")
$args=@('-sS','-w',"`n%{http_code}",'-X','POST',"$base/api.php/token",'-H','Accept: application/json','-H','Content-Type: application/x-www-form-urlencoded')
foreach($field in $form){$args+=@('--data-urlencode',$field)}
$raw=(& curl.exe @args)-join "`n";$parts=$raw-split "`n(?=\d{3}$)";$token=($parts[0]|ConvertFrom-Json).access_token
if(-not $token){throw 'OAuth token acquisition failed.'}
$headers=@{Authorization="Bearer $token";Accept='application/json'}
function Ensure-GlpiObject([string]$path,[string]$name,[hashtable]$body){
  try { $items=Invoke-RestMethod -Method Get -Uri "${base}/api.php/${path}?start=0&limit=100" -Headers $headers }
  catch { throw "API read failed for ${path}: $($_.ErrorDetails.Message)" }
  $found=@($items)|Where-Object {$_.name -ceq $name}|Select-Object -First 1
  if($found){Write-Host "$path NAME=$name ID=$($found.id) ACTION=REUSED";return $found}
  $postHeaders=@{}+$headers;$postHeaders['Content-Type']='application/json'
  $created=Invoke-RestMethod -Method Post -Uri "${base}/api.php/${path}" -Headers $postHeaders -Body ($body|ConvertTo-Json)
  $read=Invoke-RestMethod -Method Get -Uri "${base}/api.php/${path}/$($created.id)" -Headers $headers
  Write-Host "$path NAME=$name ID=$($read.id) ACTION=CREATED";return $read
}
$null=Ensure-GlpiObject 'Administration/Entity' 'GIOP-LAB' @{name='GIOP-LAB';comment='Synthetic GIOP-LAB entity'}
foreach($location in @('LAB-CPD','LAB-ADMIN','LAB-EDUCATION','LAB-REMOTE-SITE')){$null=Ensure-GlpiObject 'Dropdowns/Location' $location @{name=$location;comment='Synthetic GIOP-LAB location'}}
foreach($server in @('GUA-LAB-SRV-WEB-001','GUA-LAB-SRV-DB-001','GUA-LAB-PC-001')){$null=Ensure-GlpiObject 'Assets/Computer' $server @{name=$server;comment='Synthetic GIOP-LAB CI';is_recursive=$true}}
foreach($network in @('GUA-LAB-SW-001','GUA-LAB-AP-001')){$null=Ensure-GlpiObject 'Assets/NetworkEquipment' $network @{name=$network;comment='Synthetic GIOP-LAB network CI';is_recursive=$true}}
