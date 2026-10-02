[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$envPath = Join-Path $root '.env'
$approvedKeys = @('GLPI_API_BASE_URL', 'GLPI_API_USERNAME', 'GLPI_API_PASSWORD', 'GLPI_OAUTH_CLIENT_ID', 'GLPI_OAUTH_CLIENT_SECRET')
$cfg = @{}
Get-Content $envPath | ForEach-Object {
    if ($_ -match '^([^#=]+)=(.*)$' -and $approvedKeys -contains $matches[1]) { $cfg[$matches[1]] = $matches[2] }
}
foreach ($key in $approvedKeys) {
    $present = $cfg.ContainsKey($key)
    $value = if ($present) { [string]$cfg[$key] } else { '' }
    $leading = $present -and $value.Length -gt 0 -and [char]::IsWhiteSpace($value[0])
    $trailing = $present -and $value.Length -gt 0 -and [char]::IsWhiteSpace($value[$value.Length - 1])
    $quoted = $present -and $value.Length -ge 2 -and (($value[0] -eq '"' -and $value[$value.Length - 1] -eq '"') -or ($value[0] -eq "'" -and $value[$value.Length - 1] -eq "'"))
    Write-Host "$key PRESENT=$present EMPTY=$([string]::IsNullOrEmpty($value)) LENGTH=$($value.Length) LEADING_WHITESPACE=$leading TRAILING_WHITESPACE=$trailing SURROUNDING_QUOTES=$quoted"
}
Write-Host "BASE_URL_EXPECTED_MATCH=$($cfg['GLPI_API_BASE_URL'] -ceq 'http://localhost:8081')"
Write-Host "USERNAME_EXPECTED_MATCH=$($cfg['GLPI_API_USERNAME'] -ceq 'giop-lab-api')"
$valid = ($approvedKeys | ForEach-Object { $cfg.ContainsKey($_) -and -not [string]::IsNullOrEmpty($cfg[$_]) }) -notcontains $false
$valid = $valid -and ($cfg['GLPI_API_BASE_URL'] -ceq 'http://localhost:8081') -and ($cfg['GLPI_API_USERNAME'] -ceq 'giop-lab-api')
$valid = $valid -and (($approvedKeys | ForEach-Object { $v=[string]$cfg[$_]; -not ([char]::IsWhiteSpace($v[0]) -or [char]::IsWhiteSpace($v[$v.Length-1]) -or ($v.Length -ge 2 -and (($v[0] -eq '"' -and $v[$v.Length-1] -eq '"') -or ($v[0] -eq "'" -and $v[$v.Length-1] -eq "'")))) }) -notcontains $false)
Write-Host "STRUCTURAL_VALIDATION_PASS=$valid"
if (-not $valid) { exit 1 }
