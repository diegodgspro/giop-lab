<#
.SYNOPSIS
Validates the Phase 3A contract using only the dedicated integration identity.
.DESCRIPTION
Defaults to ReadOnly. Business requests in ReadOnly are exclusively GETs.
WriteTest explicitly creates one synthetic ticket and one follow-up, retains
them for operator review, and never retries mutations or changes ticket status.
Run WriteTest only after separate authorization for live fixture creation.
Run from one operator machine. Pending-write records under LocalApplicationData
block blind retries after uncertain outcomes; retain them for reconciliation.
No credentials, response bodies, tokens, or exception details are logged.
#>
[CmdletBinding(DefaultParameterSetName = 'ReadOnly')]
param(
    [Parameter(ParameterSetName = 'ReadOnly')]
    [switch]$ReadOnly,
    [Parameter(Mandatory = $true, ParameterSetName = 'WriteTest')]
    [switch]$WriteTest
)

$ErrorActionPreference = 'Stop'
$VerbosePreference = 'SilentlyContinue'
$DebugPreference = 'SilentlyContinue'
$ProgressPreference = 'SilentlyContinue'
$cfg = @{}
$headers = @{}
$denials = [System.Collections.Generic.List[string]]::new()
$results = [ordered]@{
    OAuth = 'NOT_RUN'
    ComputerRead = 'NOT_RUN'
    TicketReadSearch = 'NOT_RUN'
    ExternalIdFilter = 'NOT_RUN'
    FollowupRead = 'NOT_RUN'
    PAGINATION_CONTRACT = 'NOT_RUN'
    PAGINATION_VALIDATED = 'NO'
    PRECREATE_SEARCH_COMPLETE = 'NO'
}
$failed = $false
$fixtureLock = $null
$fixtureState = $null
$fixtureStatePath = $null

function Stop-Contract {
    param([string]$Reason)
    $results['CONTRACT_RESULT'] = $Reason
    $results.PAGINATION_VALIDATED = 'NO'
    throw 'Controlled contract validation stopped.'
}

function Invoke-ContractRequest {
    param(
        [ValidateSet('GET', 'POST')][string]$Method,
        [string]$Path,
        [object]$Body,
        [switch]$TokenRequest
    )
    # Central allowlist: OAuth is the sole POST permitted in ReadOnly.
    if ($TokenRequest) {
        if ($Method -ne 'POST' -or $Path -ne '/api.php/token') {
            throw 'Invalid token request.'
        }
    } elseif ($Method -ne 'GET') {
        if (-not $WriteTest) {
            throw 'Business writes require WriteTest.'
        }
        if ($results.PAGINATION_VALIDATED -ne 'YES' -or
            $results.PRECREATE_SEARCH_COMPLETE -ne 'YES') {
            Stop-Contract 'WRITE_PAGINATION_GATE_FAILED'
        }
        if ($Path -match '/Timeline/Followup$' -and
            $results.FOLLOWUP_COLLECTION_COMPLETE -ne 'YES') {
            Stop-Contract 'WRITE_FOLLOWUP_COMPLETENESS_GATE_FAILED'
        }
        if ($Path -notmatch '^/api\.php/v2\.3\.0/Assistance/Ticket(?:/[1-9][0-9]*/Timeline/Followup)?$') {
            throw 'Write route is outside the fixture allowlist.'
        }
    }
    $request = @{
        Uri = "$base$Path"
        Method = $Method
        Headers = $headers
        UseBasicParsing = $true
        TimeoutSec = 30
        ErrorAction = 'Stop'
    }
    if ($TokenRequest) {
        $request.Headers = @{ Accept = 'application/json' }
        $request.ContentType = 'application/x-www-form-urlencoded'
        $request.Body = $Body
    } elseif ($Method -eq 'POST') {
        $request.ContentType = 'application/json'
        $request.Body = $Body | ConvertTo-Json -Depth 5 -Compress
    }
    try {
        $response = Invoke-WebRequest @request
        $status = [int]$response.StatusCode
        $data = $null
        try {
            $data = ConvertFrom-Json -InputObject $response.Content
            # Preserve zero/one-element JSON arrays in Windows PowerShell 5.1.
            if ($response.Content.TrimStart().StartsWith('[')) {
                $data = @(ConvertFrom-Json -InputObject $response.Content)
            }
        } catch {
            return @{ Status = $status; ValidJson = $false; Data = $null }
        }
        return @{ Status = $status; ValidJson = $true; Data = $data; Headers = $response.Headers }
    } catch {
        $status = 0
        if ($_.Exception.Response) { $status = [int]$_.Exception.Response.StatusCode }
        if ($status -in @(401, 403)) { $denials.Add("$Method $Path HTTP=$status") }
        # Never emit raw exception/error response: it can contain sensitive data.
        return @{ Status = $status; ValidJson = $false; Data = $null }
    }
}

# Verified against the running GLPI 11.0.9 v2.3.0 OpenAPI and source:
# Ticket: start is zero-based, limit defaults to 100 in OpenAPI (no maximum
# declared; runtime passes an explicit limit through without a clamp).
# Content-Range describes the requested window, not necessarily actual records.
# Empty searches observed: HTTP 200, [], Content-Range 0--1/0.
# HTTP 206 means start + limit < total; HTTP 200 means the final window.
# Followup: getITILTimelineItems ignores start/limit, uses an internal limit of
# 1000, discards pagination headers, and wraps entries as {type, item}.
# Therefore a headerless follow-up result of 1000 or more cannot prove absence.
function ConvertTo-GlpiCollection {
    param($Response)
    if ($Response.Status -notin @(200, 206) -or -not $Response.ValidJson) {
        Stop-Contract 'COLLECTION_READ_FAILED'
    }
    $data = $Response.Data
    if ($data -is [System.Array]) {
        $records = $data
    } elseif ($null -ne $data -and $data -is [pscustomobject]) {
        $containers = @(@('items', 'collection', 'results') | Where-Object {
            $null -ne $data.PSObject.Properties[$_]
        })
        if (@($containers).Count -eq 1) {
            $records = $data.($containers[0])
            if ($records -isnot [System.Array]) { Stop-Contract 'COLLECTION_RESPONSE_SHAPE_UNKNOWN' }
        } elseif (@($containers).Count -eq 0 -and $null -ne $data.PSObject.Properties['id']) {
            $records = @($data)
        } else { Stop-Contract 'COLLECTION_RESPONSE_SHAPE_UNKNOWN' }
    } else { Stop-Contract 'COLLECTION_RESPONSE_SHAPE_UNKNOWN' }
    $normalized = [System.Collections.Generic.List[object]]::new()
    foreach ($record in $records) {
        if ($record -isnot [pscustomobject]) { Stop-Contract 'COLLECTION_RESPONSE_SHAPE_UNKNOWN' }
        if ($null -ne $record.PSObject.Properties['item']) {
            if ($record.type -cne 'Followup' -or $record.item -isnot [pscustomobject]) {
                Stop-Contract 'COLLECTION_RESPONSE_SHAPE_UNKNOWN'
            }
            $record = $record.item
        }
        if ([string]$record.id -notmatch '^[1-9][0-9]*$') {
            Stop-Contract 'COLLECTION_RESPONSE_SHAPE_UNKNOWN'
        }
        $normalized.Add($record)
    }
    return ,($normalized.ToArray())
}

function Get-GlpiPagedCollection {
    param(
        [string]$Path,
        [string]$DiagnosticPrefix,
        [ValidateRange(1, 100)][int]$PageSize = 25
    )
    $results["${DiagnosticPrefix}_COMPLETE"] = 'NO'
    $items = [System.Collections.Generic.List[object]]::new()
    $seen = @{}
    $seenPages = @{}
    $separator = if ($Path.Contains('?')) { '&' } else { '?' }
    $isFollowup = $Path -match '/Timeline/Followup(?:\?|$)'
    $start = 0L
    $knownTotal = $null
    $lastId = 0L
    for ($page = 0; $page -lt 100; $page++) {
        # Followup is a capped, non-paged endpoint in this runtime. Sending start
        # would silently re-read the first window; never pretend it advances.
        $requestPath = if ($isFollowup) { $Path } else {
            "${Path}${separator}start=$start&limit=$PageSize&sort=id:asc"
        }
        $response = Invoke-ContractRequest GET $requestPath
        $records = ConvertTo-GlpiCollection $response
        $results["${DiagnosticPrefix}_PAGES"] = $page + 1
        $results["${DiagnosticPrefix}_LAST_HTTP"] = $response.Status
        $signature = (@($records | ForEach-Object { [string]$_.id }) -join ',')
        if ($records.Count -gt 0 -and $seenPages.ContainsKey($signature)) {
            Stop-Contract 'COLLECTION_REPEATED_PAGE'
        }
        $seenPages[$signature] = $true
        $overlap = $false
        $previousId = $lastId
        foreach ($item in $records) {
            $id = [string]$item.id
            if (-not $isFollowup -and [long]$id -le $previousId) {
                Stop-Contract 'COLLECTION_ORDER_INCONSISTENT'
            }
            $previousId = [long]$id
            if ($seen.ContainsKey($id)) { $overlap = $true; continue }
            $seen[$id] = $true
            $items.Add($item)
        }
        # Deduplicate by ID, but overlapping windows still make completeness
        # ambiguous (collection drift or a server ignoring pagination).
        if ($overlap) { Stop-Contract 'COLLECTION_OVERLAPPING_PAGES' }
        $lastId = $previousId
        $results["${DiagnosticPrefix}_UNIQUE_IDS"] = $items.Count
        $range = [string]$response.Headers['Content-Range']
        $complete = $false
        if ($range) {
            if ($range -notmatch '^(?:items\s+)?(\d+)-(-?\d+)/(\d+)$') {
                Stop-Contract 'COLLECTION_RANGE_METADATA_UNKNOWN'
            }
            $rangeStart = [long]$matches[1]
            $rangeEnd = [long]$matches[2]
            $total = [long]$matches[3]
            if ($isFollowup -or $rangeStart -ne $start -or
                ($null -ne $knownTotal -and $knownTotal -ne $total) -or $start -gt $total) {
                Stop-Contract 'COLLECTION_PAGINATION_INCONSISTENT'
            }
            $knownTotal = $total
            $expectedCount = [Math]::Min([long]$PageSize, $total - $start)
            # ResourceAccessor uses the requested limit to compute end; its
            # strict > comparison can emit end==total at the final boundary.
            $requestedEnd = [Math]::Max(0L, $start + $PageSize - 1)
            if ($requestedEnd -gt $total) { $requestedEnd = $total - 1 }
            $actualEnd = $start + $records.Count - 1
            $emptyRange = $total -eq 0 -and $start -eq 0 -and
                $records.Count -eq 0 -and $rangeEnd -in @(-1, 0)
            if ($records.Count -ne $expectedCount -or
                (-not $emptyRange -and $rangeEnd -ne $requestedEnd -and $rangeEnd -ne $actualEnd)) {
                Stop-Contract 'COLLECTION_PAGINATION_INCONSISTENT'
            }
            $next = $start + $records.Count
            $complete = $next -eq $total
            if (($complete -and $response.Status -ne 200) -or
                (-not $complete -and $response.Status -ne 206)) {
                Stop-Contract 'COLLECTION_STATUS_RANGE_CONFLICT'
            }
        } elseif (-not $isFollowup -and $response.Data -is [pscustomobject] -and
            ($null -ne $response.Data.PSObject.Properties['total'] -or
             $null -ne $response.Data.PSObject.Properties['total_count'])) {
            $totalFields = @(@('total', 'total_count') | Where-Object {
                $null -ne $response.Data.PSObject.Properties[$_]
            })
            $totalText = [string]$response.Data.($totalFields[0])
            if ($totalText -notmatch '^\d+$' -or
                ($totalFields.Count -gt 1 -and [string]$response.Data.total_count -ne $totalText)) {
                Stop-Contract 'COLLECTION_TOTAL_METADATA_UNKNOWN'
            }
            $total = [long]$totalText
            if (($null -ne $knownTotal -and $knownTotal -ne $total) -or $start -gt $total -or
                $records.Count -ne [Math]::Min([long]$PageSize, $total - $start)) {
                Stop-Contract 'COLLECTION_PAGINATION_INCONSISTENT'
            }
            $knownTotal = $total
            $complete = $start + $records.Count -eq $total
            if ($complete -and $response.Status -ne 200) {
                Stop-Contract 'COLLECTION_STATUS_RANGE_CONFLICT'
            }
        } elseif ($isFollowup) {
            # Source-confirmed internal cap. Below it, the full visible list is
            # returned. At the cap there is no metadata to distinguish truncation.
            if ($response.Status -ne 200 -or $records.Count -ge 1000) {
                Stop-Contract 'FOLLOWUP_COLLECTION_COMPLETENESS_UNPROVEN'
            }
            $complete = $true
        } else {
            # Headerless Ticket fallback: a short nonempty page alone proves
            # nothing. Continue until a successful empty window at advancing start.
            if ($null -ne $knownTotal) { Stop-Contract 'COLLECTION_METADATA_DISAPPEARED' }
            if ($records.Count -gt $PageSize) { Stop-Contract 'COLLECTION_LIMIT_IGNORED' }
            $complete = $records.Count -eq 0 -and $response.Status -eq 200
        }
        if ($complete) {
            if ($null -ne $knownTotal -and $items.Count -ne $knownTotal) {
                Stop-Contract 'COLLECTION_UNIQUE_COUNT_MISMATCH'
            }
            $results["${DiagnosticPrefix}_COMPLETE"] = 'YES'
            return ,($items.ToArray())
        }
        $nextStart = $start + $records.Count
        if ($nextStart -le $start) { Stop-Contract 'COLLECTION_NON_ADVANCING' }
        $start = $nextStart
    }
    Stop-Contract 'COLLECTION_PAGE_LIMIT_EXCEEDED'
}

function Set-FixturePending {
    param([string]$Operation)
    $fixtureState[$Operation] = $true
    # Persist intent BEFORE sending: an uncertain outcome must never permit a
    # blind second POST, including after a process restart.
    [System.IO.File]::WriteAllText($fixtureStatePath, ($fixtureState | ConvertTo-Json -Compress))
}

function Clear-FixturePending {
    param([string]$Operation)
    $fixtureState[$Operation] = $false
    [System.IO.File]::WriteAllText($fixtureStatePath, ($fixtureState | ConvertTo-Json -Compress))
}

function Test-FollowupMarker {
    param([string]$Content)
    return ($Content -cmatch ('(?<![A-Za-z0-9:_-])' +
        [regex]::Escape($followupMarker) + '(?![A-Za-z0-9:_-])'))
}

try {
    $keys = @('GLPI_API_BASE_URL', 'GLPI_INTEGRATION_USERNAME',
        'GLPI_INTEGRATION_PASSWORD', 'GLPI_INTEGRATION_OAUTH_CLIENT_ID',
        'GLPI_INTEGRATION_OAUTH_CLIENT_SECRET')
    $envPath = Join-Path (Split-Path -Parent $PSScriptRoot) '.env'
    foreach ($line in [System.IO.File]::ReadAllLines($envPath)) {
        if ($line -match '^\s*([^#=\s]+)\s*=(.*)$' -and $keys -contains $matches[1]) {
            $key = $matches[1]
            $value = $matches[2].Trim()
            if ($value.Length -ge 2 -and
                (($value.StartsWith('"') -and $value.EndsWith('"')) -or
                 ($value.StartsWith("'") -and $value.EndsWith("'")))) {
                $value = $value.Substring(1, $value.Length - 2)
            }
            $cfg[$key] = $value
        }
    }
    foreach ($key in $keys) {
        if ([string]::IsNullOrWhiteSpace($cfg[$key])) { throw 'Required configuration missing.' }
    }
    if ($cfg.GLPI_INTEGRATION_USERNAME -cne 'giop-lab-zabbix-glpi') {
        throw 'Dedicated integration identity required.'
    }
    $base = $cfg.GLPI_API_BASE_URL.TrimEnd('/')
    $baseUri = [uri]$base
    # Prevent sending credentials over plaintext outside the local lab.
    if (-not $baseUri.IsAbsoluteUri -or $baseUri.UserInfo -or $baseUri.Query -or
        $baseUri.Fragment -or $baseUri.AbsolutePath -ne '/' -or
        ($baseUri.Scheme -ne 'https' -and
         -not ($baseUri.Scheme -eq 'http' -and $baseUri.IsLoopback))) {
        throw 'Invalid API base URL.'
    }
    $oauth = Invoke-ContractRequest -Method POST -Path '/api.php/token' -TokenRequest -Body @{
        grant_type = 'password'; scope = 'api'
        username = $cfg.GLPI_INTEGRATION_USERNAME
        password = $cfg.GLPI_INTEGRATION_PASSWORD
        client_id = $cfg.GLPI_INTEGRATION_OAUTH_CLIENT_ID
        client_secret = $cfg.GLPI_INTEGRATION_OAUTH_CLIENT_SECRET
    }
    if ($oauth.Status -ne 200 -or -not $oauth.ValidJson -or
        [string]::IsNullOrWhiteSpace($oauth.Data.access_token) -or
        $oauth.Data.token_type -ine 'Bearer') {
        $results.OAuth = "FAIL HTTP=$($oauth.Status)"
        throw 'OAuth acquisition failed.'
    }
    $results.OAuth = 'PASS HTTP=200'
    # Use the identity's assigned profile; never discover or switch to Admin.
    $headers = @{ Authorization = "Bearer $($oauth.Data.access_token)"
        Accept = 'application/json'; 'GLPI-Entity' = '0'; 'GLPI-Entity-Recursive' = 'false' }
    $api = '/api.php/v2.3.0'
    $computer = Invoke-ContractRequest GET "$api/Assets/Computer/1"
    $computerOk = $computer.Status -eq 200 -and $computer.ValidJson -and $computer.Data.id -eq 1
    $results.ComputerRead = "$(if ($computerOk) { 'PASS' } else { 'FAIL' }) HTTP=$($computer.Status)"
    if (-not $computerOk) { $failed = $true }

    $tickets = Get-GlpiPagedCollection "$api/Assistance/Ticket" 'TICKET_COLLECTION'
    $searchFilter = [uri]::EscapeDataString('id==1')
    $search = Get-GlpiPagedCollection "$api/Assistance/Ticket?filter=$searchFilter" 'TICKET_ID_SEARCH' -PageSize 2
    $searchOk = @($search | Where-Object { $_.id -ne 1 }).Count -eq 0
    $results.TicketReadSearch = "$(if ($searchOk) { 'PASS' } else { 'FAIL' })"
    if ($search.Count -eq 0) { $results.TicketReadSearch += ' POSITIVE_MATCH_UNPROVEN' }
    if (-not $searchOk) { Stop-Contract 'FILTER_RESULT_MISMATCH' }

    $ticketName = 'LAB-P3A-CONTRACT-001'
    $marker = 'GIOP-LAB:P3:LAB-P3A-CONTRACT-001'
    $followupMarker = 'GIOP-LAB:P3:FOLLOWUP:LAB-P3A-CONTRACT-001'
    $filter = [uri]::EscapeDataString("external_id==$marker")
    $ticketId = 1
    $externalMatches = Get-GlpiPagedCollection "$api/Assistance/Ticket?filter=$filter" 'EXTERNAL_ID_COLLECTION' -PageSize 2
    $nameFilter = [uri]::EscapeDataString("name==$ticketName")
    $nameMatches = Get-GlpiPagedCollection "$api/Assistance/Ticket?filter=$nameFilter" 'EXACT_NAME_COLLECTION' -PageSize 2
    $results['EXTERNAL_ID_SEARCH'] = if ($externalMatches.Count -gt 1) { 'DUPLICATE' } else { [string]$externalMatches.Count }
    $results['EXACT_NAME_SEARCH'] = if ($nameMatches.Count -gt 1) { 'DUPLICATE' } else { [string]$nameMatches.Count }
    if ($externalMatches.Count -gt 1 -or $nameMatches.Count -gt 1) {
        $results['TICKET_PRECHECK'] = 'DUPLICATE_STATE'
        Stop-Contract 'DUPLICATE_STATE'
    }
    if (@($externalMatches | Where-Object { $_.external_id -cne $marker }).Count -or
        @($nameMatches | Where-Object { $_.name -cne $ticketName }).Count) {
        Stop-Contract 'FILTER_RESULT_MISMATCH'
    }
    $results.ExternalIdFilter = 'SYNTAX_PASS POSITIVE_MATCH_UNPROVEN'
    $results.PAGINATION_CONTRACT = 'PASS'
    $results.PAGINATION_VALIDATED = 'YES'
    $results.PRECREATE_SEARCH_COMPLETE = 'YES'
    if ($WriteTest) {
        $results['IDEMPOTENCY_READY'] = 'NO'
        if ($failed) { Stop-Contract 'READ_CONTRACT_FAILED' }
        # Serialize this operator test locally; do not run from multiple machines.
        # State contains only pending flags, never credentials or response bodies.
        $sha = [System.Security.Cryptography.SHA256]::Create()
        try {
            $instanceKey = [BitConverter]::ToString($sha.ComputeHash(
                [Text.Encoding]::UTF8.GetBytes("$base|$marker"))).Replace('-', '')
        } finally { $sha.Dispose() }
        $stateRoot = Join-Path ([Environment]::GetFolderPath('LocalApplicationData')) 'GIOP-LAB/contract-tests'
        $null = [System.IO.Directory]::CreateDirectory($stateRoot)
        $fixtureStatePath = Join-Path $stateRoot "$instanceKey.json"
        try {
            $fixtureLock = [System.IO.File]::Open((Join-Path $stateRoot "$instanceKey.lock"),
                [System.IO.FileMode]::OpenOrCreate, [System.IO.FileAccess]::ReadWrite,
                [System.IO.FileShare]::None)
        } catch { Stop-Contract 'CONCURRENT_WRITE_TEST_BLOCKED' }
        $fixtureState = @{ TicketPending = $false; FollowupPending = $false }
        if ([System.IO.File]::Exists($fixtureStatePath)) {
            $savedState = ConvertFrom-Json -InputObject ([System.IO.File]::ReadAllText($fixtureStatePath))
            if ($savedState.TicketPending -isnot [bool] -or $savedState.FollowupPending -isnot [bool]) {
                Stop-Contract 'LOCAL_STATE_INVALID'
            }
            $fixtureState.TicketPending = $savedState.TicketPending
            $fixtureState.FollowupPending = $savedState.FollowupPending
        }
        # Repeat under the local fixture lock; both searches must complete.
        $results.PRECREATE_SEARCH_COMPLETE = 'NO'
        $externalMatches = Get-GlpiPagedCollection "$api/Assistance/Ticket?filter=$filter" 'EXTERNAL_ID_COLLECTION' -PageSize 2
        $nameFilter = [uri]::EscapeDataString("name==$ticketName")
        $nameMatches = Get-GlpiPagedCollection "$api/Assistance/Ticket?filter=$nameFilter" 'EXACT_NAME_COLLECTION' -PageSize 2
        $results['EXTERNAL_ID_SEARCH'] = if ($externalMatches.Count -gt 1) { 'DUPLICATE' } else { [string]$externalMatches.Count }
        $results['EXACT_NAME_SEARCH'] = if ($nameMatches.Count -gt 1) { 'DUPLICATE' } else { [string]$nameMatches.Count }
        if ($externalMatches.Count -gt 1 -or $nameMatches.Count -gt 1) {
            $results['TICKET_PRECHECK'] = 'DUPLICATE_STATE'
            Stop-Contract 'DUPLICATE_STATE'
        }
        # Reject ignored/approximate filters rather than treating them as absence.
        if (@($externalMatches | Where-Object { $_.external_id -cne $marker }).Count -or
            @($nameMatches | Where-Object { $_.name -cne $ticketName }).Count) {
            Stop-Contract 'FILTER_RESULT_MISMATCH'
        }
        $results.PRECREATE_SEARCH_COMPLETE = 'YES'
        if ($externalMatches.Count -eq 1) {
            $ticketId = [long]$externalMatches[0].id
            $results['TICKET_ID'] = $ticketId
            if ($externalMatches[0].name -cne $ticketName -or $nameMatches.Count -ne 1 -or
                $nameMatches[0].id -ne $ticketId) {
                $results['TICKET_PRECHECK'] = 'INCONSISTENT_STATE'
                Stop-Contract 'INCONSISTENT_STATE'
            }
            $results['TICKET_CREATE'] = 'REUSED'
            $results['TICKET_COUNTS'] = '0 created / 1 reused'
        } elseif ($nameMatches.Count -eq 1) {
            $results['TICKET_ID'] = [long]$nameMatches[0].id
            $results['TICKET_PRECHECK'] = 'INCONSISTENT_STATE'
            Stop-Contract 'INCONSISTENT_STATE'
        } else {
            if ($fixtureState.TicketPending -or $fixtureState.FollowupPending) {
                Stop-Contract 'UNCERTAIN_PREVIOUS_WRITE_OPERATOR_RECONCILIATION_REQUIRED'
            }
            $results['TICKET_PRECHECK'] = 'PASS'
            Set-FixturePending 'TicketPending'
            $created = Invoke-ContractRequest POST "$api/Assistance/Ticket" -Body @{
                name = $ticketName
                content = '<p>Synthetic Phase 3A integration contract validation. Not a real municipal incident.</p>'
                external_id = $marker
                type = 1
            }
            if ($created.Status -ne 201 -or -not $created.ValidJson -or
                [string]$created.Data.id -notmatch '^[1-9][0-9]*$') {
                Stop-Contract 'TICKET_CREATE_UNCONFIRMED_OPERATOR_RECONCILIATION_REQUIRED'
            }
            $ticketId = [long]$created.Data.id
            $results['TICKET_ID'] = $ticketId
            $results['TICKET_CREATE'] = 'CREATED'
            $results['TICKET_COUNTS'] = '1 created / 0 reused'
        }
        $results['TICKET_PRECHECK'] = 'PASS'
        $readback = Invoke-ContractRequest GET "$api/Assistance/Ticket/$ticketId"
        if ($readback.Status -ne 200 -or -not $readback.ValidJson -or
            $readback.Data.id -ne $ticketId -or $readback.Data.name -cne $ticketName -or
            $readback.Data.external_id -cne $marker) {
            $results['EXTERNAL_ID_READBACK'] = 'FAIL'
            $results['EXTERNAL_ID_ROUNDTRIP'] = 'FAIL'
            Stop-Contract 'EXTERNAL_ID_ROUNDTRIP_FAILED'
        }
        $results['EXTERNAL_ID_READBACK'] = 'PASS'
        $positive = Get-GlpiPagedCollection "$api/Assistance/Ticket?filter=$filter" 'POSITIVE_EXTERNAL_ID_COLLECTION' -PageSize 2
        if ($positive.Count -ne 1 -or $positive[0].id -ne $ticketId -or
            $positive[0].external_id -cne $marker) {
            $results['EXTERNAL_ID_FILTER'] = 'FAIL'
            Stop-Contract 'EXTERNAL_ID_POSITIVE_FILTER_FAILED'
        }
        $results.ExternalIdFilter = 'POSITIVE_PASS'
        $results['EXTERNAL_ID_FILTER'] = 'PASS'
        $results['POSITIVE_MATCH'] = 'TRUE'
        $results['EXTERNAL_ID_MATCH_ID'] = $ticketId
        Clear-FixturePending 'TicketPending'

        # Read every follow-up individually; collection projections may omit content.
        $existingFollowups = Get-GlpiPagedCollection "$api/Assistance/Ticket/$ticketId/Timeline/Followup" 'FOLLOWUP_COLLECTION'
        $matchingFollowups = [System.Collections.Generic.List[object]]::new()
        foreach ($existing in $existingFollowups) {
            $existingId = [long]$existing.id
            $detail = Invoke-ContractRequest GET "$api/Assistance/Ticket/$ticketId/Timeline/Followup/$existingId"
            if ($detail.Status -ne 200 -or -not $detail.ValidJson -or
                $detail.Data.id -ne $existingId -or $null -eq $detail.Data.content) {
                Stop-Contract 'FOLLOWUP_RECONCILIATION_INCOMPLETE'
            }
            if (Test-FollowupMarker ([string]$detail.Data.content)) {
                $matchingFollowups.Add($detail.Data)
            }
        }
        if ($matchingFollowups.Count -gt 1) { Stop-Contract 'DUPLICATE_FOLLOWUP_STATE' }
        if ($matchingFollowups.Count -eq 1) {
            $followupId = [long]$matchingFollowups[0].id
            $results['FOLLOWUP_CREATE'] = 'REUSED'
            $results['FOLLOWUP_COUNTS'] = '0 created / 1 reused'
        } else {
            if ($fixtureState.FollowupPending) {
                Stop-Contract 'UNCERTAIN_PREVIOUS_FOLLOWUP_OPERATOR_RECONCILIATION_REQUIRED'
            }
            Set-FixturePending 'FollowupPending'
            $added = Invoke-ContractRequest POST "$api/Assistance/Ticket/$ticketId/Timeline/Followup" -Body @{
                content = "<p>Synthetic Phase 3A integration contract validation follow-up. Not a real municipal incident.</p><p>$followupMarker</p>"
                is_private = $false
            }
            if ($added.Status -ne 201 -or -not $added.ValidJson -or
                [string]$added.Data.id -notmatch '^[1-9][0-9]*$') {
                Stop-Contract 'FOLLOWUP_CREATE_UNCONFIRMED_OPERATOR_RECONCILIATION_REQUIRED'
            }
            $followupId = [long]$added.Data.id
            $results['FOLLOWUP_CREATE'] = 'CREATED'
            $results['FOLLOWUP_COUNTS'] = '1 created / 0 reused'
        }
        $followupReadback = Invoke-ContractRequest GET "$api/Assistance/Ticket/$ticketId/Timeline/Followup/$followupId"
        if ($followupReadback.Status -ne 200 -or -not $followupReadback.ValidJson -or
            $followupReadback.Data.id -ne $followupId -or
            -not (Test-FollowupMarker ([string]$followupReadback.Data.content)) -or
            $null -eq $followupReadback.Data.is_private -or
            [string]$followupReadback.Data.is_private -notin @('False', '0')) {
            $results['FOLLOWUP_READBACK'] = 'FAIL'
            Stop-Contract 'FOLLOWUP_READBACK_FAILED'
        }
        Clear-FixturePending 'FollowupPending'
        $results['FOLLOWUP_READBACK'] = 'PASS'
        $results.FollowupRead = 'PASS'
        $results['IDEMPOTENCY_READY'] = 'YES'
    }

    if (-not $WriteTest) {
        $followups = Get-GlpiPagedCollection "$api/Assistance/Ticket/$ticketId/Timeline/Followup" 'FOLLOWUP_COLLECTION'
        $results.FollowupRead = 'COLLECTION_PASS'
        if ($followups.Count -gt 0) {
            $followupId = [string]$followups[0].id
            $item = Invoke-ContractRequest GET "$api/Assistance/Ticket/$ticketId/Timeline/Followup/$followupId"
            $itemOk = $item.Status -eq 200 -and $item.ValidJson -and $item.Data.id -eq $followupId
            $results.FollowupRead += " ITEM_$(if ($itemOk) { 'PASS' } else { 'FAIL' }) HTTP=$($item.Status)"
            if (-not $itemOk) { $failed = $true }
        } else { $results.FollowupRead += ' ITEM_READ_UNPROVEN_EMPTY_COLLECTION' }
    }

} catch {
    $failed = $true
    if ($results.OAuth -eq 'NOT_RUN') { $results.OAuth = 'NOT_RUN CONFIGURATION_INVALID' }
    # Suppress raw errors, including remote bodies and sensitive request data.
} finally {
    if ($fixtureLock) { $fixtureLock.Dispose() }
    $headers.Clear()
    $cfg.Clear()
    $oauth = $null
    foreach ($entry in $results.GetEnumerator()) { Write-Output "$($entry.Key)=$($entry.Value)" }
    Write-Output "HTTP401403: $(if ($denials.Count) { $denials -join '; ' } else { 'NONE_OBSERVED' })"
}
if ($failed) { exit 1 }
