[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$envFile = Join-Path $root '.env'
if (-not (Test-Path $envFile)) { throw 'Missing .env. Copy .env.example to .env and replace all CHANGE_ME placeholders.' }
if (Select-String -Path $envFile -Pattern 'CHANGE_ME' -Quiet) { throw '.env still contains CHANGE_ME placeholders.' }
& docker compose --env-file $envFile -f (Join-Path $root 'docker/docker-compose.yml') up -d --remove-orphans
& $PSScriptRoot\lab-status.ps1
