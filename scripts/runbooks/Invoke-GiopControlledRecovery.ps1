[CmdletBinding()]
param([switch]$Execute,[ValidateRange(15,300)][int]$WaitSeconds=180)
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot '../lib/GiopRunbooks.ps1')
$result=Invoke-GiopRunbook -RunbookId RB-OPS-003 -Execute:$Execute -WaitSeconds $WaitSeconds
$result | ConvertTo-Json -Depth 24
if ($result.overall_status -ne 'PASS') { exit 1 }
