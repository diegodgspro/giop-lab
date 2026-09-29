[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$envFile = Join-Path $root '.env'
$compose = Join-Path $root 'docker/docker-compose.yml'
& docker compose --env-file $envFile -f $compose config --quiet
$settings = Get-Content $envFile | Where-Object { $_ -match '^ZABBIX_FRONTEND_PORT=' }
$port = if ($settings) { ($settings -split '=', 2)[1] } else { '8080' }
$response = Invoke-WebRequest -UseBasicParsing -TimeoutSec 20 "http://localhost:$port/"
if ($response.StatusCode -ne 200) { throw "Frontend returned HTTP $($response.StatusCode)." }
$agentCheck = & docker compose --env-file $envFile -f $compose exec -T zabbix-agent2 zabbix_agent2 -t lab.web.status
$agentCheck | Write-Host
if ($agentCheck -notmatch '\[s\|1\]') { throw 'Synthetic agent health check did not return 1.' }
Write-Host 'Smoke test passed: Compose configuration, Zabbix frontend, and synthetic agent check are reachable.'
