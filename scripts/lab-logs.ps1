[CmdletBinding()]
param([string]$Service = '')
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$args = @('--env-file', (Join-Path $root '.env'), '-f', (Join-Path $root 'docker/docker-compose.yml'), 'logs', '--tail', '200')
if ($Service) { $args += $Service }
& docker compose @args
