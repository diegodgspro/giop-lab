[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$required = @('README.md','PROJECT_STATE.md','.gitignore','.env.example','docker/docker-compose.yml','scripts/lab-up.ps1','scripts/lab-down.ps1','scripts/lab-status.ps1','scripts/lab-logs.ps1','scripts/lab-smoke-test.ps1','docs/architecture/lab-v0.1.md','docs/runbooks/RB-LAB-001-service-outage.md')
$missing = $required | Where-Object { -not (Test-Path (Join-Path $root $_)) }
if ($missing) { throw "Missing required files: $($missing -join ', ')" }
Write-Host 'Repository structure validation passed.'
