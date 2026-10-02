[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$envFile = Join-Path $root '.env'
$compose = Join-Path $root 'docker/docker-compose.yml'
& docker compose --env-file $envFile -f $compose config --quiet
$response = Invoke-WebRequest -UseBasicParsing -TimeoutSec 20 'http://localhost:8081/'
if ($response.StatusCode -ne 200) { throw "GLPI returned HTTP $($response.StatusCode)." }
& docker compose --env-file $envFile -f $compose exec -T glpi php bin/console db:check
Write-Host 'GLPI smoke test passed: frontend HTTP 200 and database schema is OK.'
