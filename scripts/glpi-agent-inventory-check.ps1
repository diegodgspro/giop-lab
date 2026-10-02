[CmdletBinding()]
param()
$ErrorActionPreference='Stop'
$root=Split-Path -Parent $PSScriptRoot
$keys=@('GLPI_API_BASE_URL','GLPI_API_USERNAME','GLPI_API_PASSWORD','GLPI_OAUTH_CLIENT_ID','GLPI_OAUTH_CLIENT_SECRET')
$cfg=@{}
Get-Content -LiteralPath (Join-Path $root '.env') | ForEach-Object { if($_ -match '^([^#=]+)=(.*)$' -and $keys -contains $matches[1]){$cfg[$matches[1]]=$matches[2]} }
$base=$cfg.GLPI_API_BASE_URL.TrimEnd('/')
$args=@('-sS','-X','POST',"${base}/api.php/token",'-H','Accept: application/json','-H','Content-Type: application/x-www-form-urlencoded')
foreach($field in @('grant_type=password','scope=api',"username=$($cfg.GLPI_API_USERNAME)","password=$($cfg.GLPI_API_PASSWORD)","client_id=$($cfg.GLPI_OAUTH_CLIENT_ID)","client_secret=$($cfg.GLPI_OAUTH_CLIENT_SECRET)")){$args+=@('--data-urlencode',$field)}
$token=(((& curl.exe @args)-join "`n")|ConvertFrom-Json).access_token;if(!$token){throw 'OAuth acquisition failed.'}
$headers=@{Authorization="Bearer $token";Accept='application/json'}
$all=@();$start=0;do{$response=Invoke-RestMethod -Method Get -Uri "${base}/api.php/Assets/Computer?start=${start}&limit=100" -Headers $headers;$page=@($response|ForEach-Object{$_});$all+=$page;$start+=$page.Count}while($page.Count -eq 100)
$item=@($all|Where-Object{$_.name -ceq 'GUA-LAB-INVENTORY-001' -and -not $_.is_deleted}|Select-Object -First 1)
if(!$item){'INVENTORY_ENDPOINT=NOT_FOUND';exit 1}
$computer=$item[0]
"INVENTORY_ENDPOINT=FOUND ID=$($computer.id) NAME=$($computer.name) LOCATION=$($computer.location.name) LAST_INVENTORY=$($computer.last_inventory_update)"
