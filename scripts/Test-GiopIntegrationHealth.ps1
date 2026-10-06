param([switch]$State)
. "$PSScriptRoot/GiopIntegration.Common.ps1"
$cfg = Get-GiopIntegrationConfig
try {
    Invoke-RestMethod "http://127.0.0.1:$($cfg.GIOP_INTEGRATION_PORT)/health"
    if ($State) {
        Invoke-RestMethod "http://127.0.0.1:$($cfg.GIOP_INTEGRATION_PORT)/api/v1/episodes" `
            -Headers @{ 'X-GIOP-Webhook-Secret' = $cfg.GIOP_WEBHOOK_SECRET }
    }
} catch { throw 'Integration health/state request failed.' }
