[CmdletBinding()]
param()
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot '../lib/GiopRunbooks.ps1')
$result=Invoke-GiopRunbook -RunbookId RB-OPS-001
$result | ConvertTo-Json -Depth 24
if ($result.overall_status -ne 'PASS') { exit 1 }
