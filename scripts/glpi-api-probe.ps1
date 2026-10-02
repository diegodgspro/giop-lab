[CmdletBinding()]
param([switch]$IncompleteProbe)
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$approvedKeys = @('GLPI_API_BASE_URL', 'GLPI_API_USERNAME', 'GLPI_API_PASSWORD', 'GLPI_OAUTH_CLIENT_ID', 'GLPI_OAUTH_CLIENT_SECRET')
$cfg = @{}
Get-Content (Join-Path $root '.env') | ForEach-Object {
    if ($_ -match '^([^#=]+)=(.*)$' -and $approvedKeys -contains $matches[1]) { $cfg[$matches[1]] = $matches[2] }
}
$baseUrl = $cfg.GLPI_API_BASE_URL.TrimEnd('/')
$tokenUrl = "$baseUrl/api.php/token"
$curlArgs = @('-sS', '-w', "`n%{http_code}", '-X', 'POST', $tokenUrl, '-H', 'Accept: application/json', '-H', 'Content-Type: application/x-www-form-urlencoded', '--data-urlencode', 'grant_type=password', '--data-urlencode', 'scope=api')
if (-not $IncompleteProbe) {
    $curlArgs += @('--data-urlencode', "username=$($cfg.GLPI_API_USERNAME)", '--data-urlencode', "password=$($cfg.GLPI_API_PASSWORD)", '--data-urlencode', "client_id=$($cfg.GLPI_OAUTH_CLIENT_ID)", '--data-urlencode', "client_secret=$($cfg.GLPI_OAUTH_CLIENT_SECRET)")
}
try {
    $raw = (& curl.exe @curlArgs) -join "`n"
    $parts = $raw -split "`n(?=\d{3}$)"
    $status = $parts[-1]
    $response = ($parts[0] | ConvertFrom-Json)
    if ($IncompleteProbe) {
        $detail = if ($response.hint) { $response.hint } elseif ($response.error_description) { $response.error_description } else { 'none' }
        Write-Host "TOKEN_URL=$tokenUrl PROBE_HTTP=$status OAUTH_ERROR=$($response.error) DETAIL=$detail"
    }
    elseif ($response.access_token) {
        $headers = @{ Authorization = "Bearer $($response.access_token)"; Accept = 'application/json' }
        try {
            $null = Invoke-RestMethod -Method Get -Uri "$baseUrl/api.php/v2.3.0/Administration/Profile" -Headers $headers -ErrorAction Stop
            Write-Host "TOKEN_URL=$tokenUrl OAUTH_HTTP=$status TOKEN_ACQUISITION=SUCCESS API_READ_HTTP=200 IDENTITY_CONFIRMATION=REQUIRES_USER_SCOPE"
        }
        catch {
            $httpStatus = if ($_.Exception.Response) { [int]$_.Exception.Response.StatusCode } else { 'unknown' }
            Write-Host "TOKEN_URL=$tokenUrl OAUTH_HTTP=$status TOKEN_ACQUISITION=SUCCESS IDENTITY_READ_HTTP=$httpStatus"
        }
    }
    elseif ($response.error) {
        $detail = if ($response.error_description) { $response.error_description } elseif ($response.hint) { $response.hint } elseif ($response.message) { $response.message } elseif ($response.detail) { $response.detail } else { 'none' }
        Write-Host "OAUTH_HTTP=$status OAUTH_ERROR=$($response.error) DETAIL=$detail"
    }
    else { Write-Host "OAUTH_HTTP=$status RESPONSE=UNEXPECTED" }
}
catch { Write-Host "OAUTH_PROBE_FAILURE=$($_.Exception.GetType().Name)" }
