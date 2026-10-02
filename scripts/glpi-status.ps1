[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
& docker compose --env-file (Join-Path $root '.env') -f (Join-Path $root 'docker/docker-compose.yml') ps glpi glpi-db
