$ErrorActionPreference = 'Stop'
function Get-GiopIntegrationConfig {
    $cfg = @{}
    foreach ($line in [IO.File]::ReadAllLines((Join-Path (Split-Path $PSScriptRoot -Parent) '.env'))) {
        if ($line -match '^\s*(GIOP_WEBHOOK_SECRET|GIOP_INTEGRATION_PORT)\s*=(.*)$') {
            $cfg[$matches[1]] = $matches[2].Trim().Trim('"').Trim("'")
        }
    }
    if (-not $cfg.GIOP_WEBHOOK_SECRET) { throw 'Configure GIOP_WEBHOOK_SECRET in ignored .env.' }
    if (-not $cfg.GIOP_INTEGRATION_PORT) { $cfg.GIOP_INTEGRATION_PORT = '8090' }
    if ($cfg.GIOP_INTEGRATION_PORT -notmatch '^\d{1,5}$') { throw 'Invalid integration port.' }
    return $cfg
}
function Send-GiopEvent {
    param([hashtable]$Payload)
    $cfg = Get-GiopIntegrationConfig
    try {
        Invoke-RestMethod -Method Post -Uri "http://127.0.0.1:$($cfg.GIOP_INTEGRATION_PORT)/api/v1/zabbix/events" `
            -Headers @{ 'X-GIOP-Webhook-Secret' = $cfg.GIOP_WEBHOOK_SECRET } `
            -ContentType 'application/json' -Body ($Payload | ConvertTo-Json -Compress)
    } catch { throw 'Integration request failed. Inspect health and non-secret integration state.' }
}
