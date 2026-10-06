param([Parameter(Mandatory)][ValidatePattern('^[1-9][0-9]{0,19}$')][string]$EventId)
. "$PSScriptRoot/GiopIntegration.Common.ps1"
Send-GiopEvent @{
    kind = 'PROBLEM'; event_id = $EventId; host_id = '10683'; trigger_id = '25228'
    host = 'GUA-LAB-SRV-WEB-001'; trigger = 'GIOP-LAB: controlled web workload TCP unavailable'
    severity = 3; event_time = [DateTimeOffset]::UtcNow.ToString('o')
}
