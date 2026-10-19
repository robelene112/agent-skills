param(
    [ValidateSet('probe', 'search', 'read')][string]$Action = 'probe',
    [string]$QueryBase64 = ''
)

# Windows PowerShell 5.1 compatible. Dot-source to test with fake Outlook objects.
$ErrorActionPreference = 'Stop'

function Get-OutlookValue($Object, [string]$Name) {
    # Direct property syntax can silently turn a throwing getter into $null.
    # Invoke the adapter getter as a method so COM/property failures propagate.
    if ($null -eq $Object) { throw "Cannot read $Name from a missing Outlook object" }
    $property = $Object.PSObject.Properties[$Name]
    if ($null -eq $property) { throw "Outlook property unavailable: $Name" }
    return ,($property.get_Value())
}

function Get-OutlookUnread($Item) {
    $state = Get-OutlookValue $Item 'UnRead'
    if ($state -isnot [bool]) { throw 'The unread status could not be determined.' }
    return $state
}

function Get-TextOption($Options, [string]$Name, [string]$Default = '') {
    if (-not $Options.ContainsKey($Name)) { return $Default }
    if ($Options[$Name] -isnot [string]) { throw "$Name must be a string" }
    return $Options[$Name]
}

function Get-NumberOption($Options, [string]$Name, [int]$Default, [int]$Min, [int]$Max) {
    if (-not $Options.ContainsKey($Name)) { return $Default }
    $value = 0
    if (-not [int]::TryParse([string]$Options[$Name], [ref]$value) -or $value -lt $Min -or $value -gt $Max) {
        throw "$Name must be an integer between $Min and $Max"
    }
    return $value
}

function Get-UtcBoundary($Options, [string]$Name) {
    $text = Get-TextOption $Options $Name
    if (-not $text) { return $null }
    if ($text -notmatch '(Z|[+-]\d{2}:\d{2})$') { throw "$Name needs an explicit timezone offset or Z" }
    return [DateTimeOffset]::Parse($text, [Globalization.CultureInfo]::InvariantCulture).UtcDateTime
}

function Add-OutlookIssue($Context, [string]$Code, [string]$Target, [string]$Message) {
    [void]$Context.issues.Add([pscustomobject]@{code = $Code; target = $Target; message = $Message})
}

function Test-OutlookBudget($Context) {
    if ($Context.clock.Elapsed.TotalSeconds -lt $Context.seconds) { return $true }
    if (-not $Context.timed_out) {
        $Context.timed_out = $true
        Add-OutlookIssue $Context 'time_budget' '' 'Search stopped at its time budget; results are incomplete.'
    }
    return $false
}

function Get-OutlookFolders($Session, $Context) {
    $queue = New-Object 'System.Collections.Generic.Queue[object]'
    $visited = New-Object 'System.Collections.Generic.HashSet[string]'
    $stores = Get-OutlookValue $Session 'Stores'
    $storeCount = [int](Get-OutlookValue $stores 'Count')
    for ($i = 1; $i -le $storeCount; $i++) {
        if (-not (Test-OutlookBudget $Context)) { return }
        try {
            $store = $stores.Item($i)
            $id = [string](Get-OutlookValue $store 'StoreID')
            if (-not $id) { throw 'StoreID is unavailable' }
            $name = [string](Get-OutlookValue $store 'DisplayName')
            [void]$Context.stores.Add([pscustomobject]@{store_id = $id; name = $name})
            $queue.Enqueue(@{handle = $store.GetRootFolder(); store_id = $id; store_name = $name})
        } catch {
            Add-OutlookIssue $Context 'store_unavailable' ([string]$i) $_.Exception.Message
        }
    }
    while ($queue.Count -gt 0) {
        if (-not (Test-OutlookBudget $Context)) { return }
        if ($Context.folders.Count -ge $Context.max_folders) {
            Add-OutlookIssue $Context 'folder_limit' '' 'Folder discovery stopped at max_folders.'
            return
        }
        $node = $queue.Dequeue()
        try {
            $folder = $node.handle
            $entry = [string](Get-OutlookValue $folder 'EntryID')
            if (-not $entry) { throw 'Folder EntryID is unavailable' }
            if (-not $visited.Add($node.store_id + ':' + $entry)) { continue }
            $path = [string](Get-OutlookValue $folder 'FolderPath')
            [void]$Context.folders.Add([pscustomobject]@{
                handle = $folder; store_id = $node.store_id; store_name = $node.store_name
                folder_id = $entry; path = $path; mail_folder = ([int](Get-OutlookValue $folder 'DefaultItemType') -eq 0)
            })
            $children = Get-OutlookValue $folder 'Folders'
            $childCount = [int](Get-OutlookValue $children 'Count')
            for ($j = 1; $j -le $childCount; $j++) {
                if (-not (Test-OutlookBudget $Context)) { return }
                try {
                    $queue.Enqueue(@{handle = $children.Item($j); store_id = $node.store_id; store_name = $node.store_name})
                } catch { Add-OutlookIssue $Context 'folder_unavailable' $path $_.Exception.Message }
            }
        } catch { Add-OutlookIssue $Context 'folder_unavailable' $node.store_id $_.Exception.Message }
    }
}

function Get-OutlookFilter($Options, $After, $Before) {
    $parts = New-Object 'System.Collections.Generic.List[string]'
    $subject = Get-TextOption $Options 'subject'
    # Wildcards in user text are literal: use client matching for those queries.
    if ($subject -and $subject -notmatch '[%_\[\]]') {
        [void]$parts.Add(('"urn:schemas:httpmail:subject" LIKE ''%{0}%''' -f $subject.Replace("'", "''")))
    }
    foreach ($pair in @(@('>=', $After), @('<', $Before))) {
        if ($null -eq $pair[1]) { continue }
        $date = [datetime]$pair[1]
        $rounded = $date.AddTicks(-($date.Ticks % [TimeSpan]::TicksPerMinute))
        if ($pair[0] -eq '<' -and $rounded -lt $date) { $rounded = $rounded.AddMinutes(1) }
        # Outlook expects the Windows user's short date/time format, without seconds.
        $literal = $rounded.ToString('g', [Globalization.CultureInfo]::CurrentCulture).Replace("'", "''")
        [void]$parts.Add(('"urn:schemas:httpmail:datereceived" {0} ''{1}''' -f $pair[0], $literal))
    }
    if ($parts.Count -eq 0) { return '' }
    return '@SQL=' + [string]::Join(' AND ', $parts.ToArray())
}

function Test-LiteralContains([string]$Text, [string]$Term) {
    return (-not $Term) -or $Text.IndexOf($Term, [StringComparison]::OrdinalIgnoreCase) -ge 0
}

function Get-ClippedText([string]$Text, [int]$Limit) {
    $length = $Text.Length
    $take = $length
    if ($Limit -gt 0 -and $take -gt $Limit) { $take = $Limit }
    if ($take -lt $length -and $take -gt 0 -and [char]::IsHighSurrogate($Text[$take - 1])) { $take-- }
    return @{text = $Text.Substring(0, $take); characters = $length; truncated = ($take -lt $length)}
}

function Get-OutlookRecipients($Item, [string]$Path, $Context) {
    try {
        $recipients = Get-OutlookValue $Item 'Recipients'
        $count = [int](Get-OutlookValue $recipients 'Count')
    } catch {
        Add-OutlookIssue $Context 'recipients_unavailable' $Path $_.Exception.Message
        return
    }
    for ($i = 1; $i -le $count; $i++) {
        if (-not (Test-OutlookBudget $Context)) { return }
        try {
            $recipient = $recipients.Item($i)
            $name = [string](Get-OutlookValue $recipient 'Name')
            $email = [string](Get-OutlookValue $recipient 'Address')
            if ($email -notmatch '@') {
                try {
                    $accessor = Get-OutlookValue $recipient 'PropertyAccessor'
                    $smtp = [string]$accessor.GetProperty('http://schemas.microsoft.com/mapi/proptag/0x39FE001E')
                    if ($smtp -notmatch '@') { throw 'The recipient SMTP address was unavailable.' }
                    $email = $smtp
                } catch {
                    # Keep display-name/raw-address matching possible while
                    # reporting that SMTP address coverage is incomplete.
                    Add-OutlookIssue $Context 'recipient_resolution_failed' $Path $_.Exception.Message
                }
            }
            [pscustomobject]@{name = $name; email = $email; type = [int](Get-OutlookValue $recipient 'Type')}
        } catch { Add-OutlookIssue $Context 'recipient_unavailable' $Path $_.Exception.Message }
    }
}

function Get-OutlookMail($Item, [string]$StoreId, [string]$Path, $Options, $Context, [bool]$IncludeBody) {
    if ([int](Get-OutlookValue $Item 'Class') -ne 43) { return $null }
    $beforeUnread = Get-OutlookUnread $Item
    $wasSaved = [bool](Get-OutlookValue $Item 'Saved')
    $result = $null
    $restored = $false
    try {
        $subject = [string](Get-OutlookValue $Item 'Subject')
        $receivedValue = Get-OutlookValue $Item 'ReceivedTime'
        if ($receivedValue -isnot [datetime]) { throw 'ReceivedTime is unavailable' }
        $received = $receivedValue.ToUniversalTime()
        $senderName = [string](Get-OutlookValue $Item 'SenderName')
        $senderEmail = [string](Get-OutlookValue $Item 'SenderEmailAddress')
        if ([string](Get-OutlookValue $Item 'SenderEmailType') -eq 'EX' -and $senderEmail -notmatch '@') {
            try {
                $address = Get-OutlookValue $Item 'Sender'
                $exchange = $address.GetExchangeUser()
                if ($null -eq $exchange) { $exchange = $address.GetExchangeDistributionList() }
                $smtp = ''
                if ($null -ne $exchange) {
                    $smtp = [string](Get-OutlookValue $exchange 'PrimarySmtpAddress')
                    if ($smtp) { $senderEmail = $smtp }
                }
                if (-not $smtp) { throw 'The Exchange SMTP address was unavailable.' }
            } catch {
                Add-OutlookIssue $Context 'sender_resolution_failed' $Path $_.Exception.Message
            }
        }
        $isMatch = (Test-LiteralContains $subject (Get-TextOption $Options 'subject')) -and
            ((Test-LiteralContains $senderName (Get-TextOption $Options 'sender')) -or
             (Test-LiteralContains $senderEmail (Get-TextOption $Options 'sender')))
        if ($Options.ContainsKey('unread_only') -and $Options.unread_only -and -not $beforeUnread) { $isMatch = $false }
        if ($null -ne $Context.after -and $received -lt $Context.after) { $isMatch = $false }
        if ($null -ne $Context.before -and $received -ge $Context.before) { $isMatch = $false }
        $participant = Get-TextOption $Options 'participant'
        $recipients = @()
        if ($IncludeBody -or ($isMatch -and $participant)) {
            $recipients = @(Get-OutlookRecipients $Item $Path $Context)
        }
        if ($isMatch -and $participant) {
            $participantMatch = (Test-LiteralContains $senderName $participant) -or (Test-LiteralContains $senderEmail $participant)
            foreach ($recipient in $recipients) {
                if ((Test-LiteralContains $recipient.name $participant) -or (Test-LiteralContains $recipient.email $participant)) {
                    $participantMatch = $true
                    break
                }
            }
            $isMatch = $participantMatch
        }
        $body = ''
        $bodyTerm = Get-TextOption $Options 'body'
        if ($isMatch -and ($IncludeBody -or $bodyTerm)) {
            $body = [string](Get-OutlookValue $Item 'Body')
            if (-not (Test-LiteralContains $body $bodyTerm)) { $isMatch = $false }
        }
        if ($isMatch) {
            $result = [pscustomobject]@{
                entry_id = [string](Get-OutlookValue $Item 'EntryID'); store_id = $StoreId; folder = $Path
                subject = $subject; sender_name = $senderName; sender_email = $senderEmail
                received_utc = $received.ToString('o'); unread_before = $beforeUnread
                unread_after = $null; unread_restored = $false
            }
            if ($IncludeBody -or $participant) { $result | Add-Member NoteProperty recipients $recipients }
            if ($IncludeBody) {
                $limit = Get-NumberOption $Options 'body_chars' 8000 0 1000000
                $result | Add-Member NoteProperty body (Get-ClippedText $body $limit)
                if ($Options.ContainsKey('html') -and $Options.html) {
                    $result | Add-Member NoteProperty html (Get-ClippedText ([string](Get-OutlookValue $Item 'HTMLBody')) $limit)
                }
            }
        }
    } finally {
        try {
            # The sole permitted write: repair a formerly unread message after our read.
            if ($beforeUnread -and -not (Get-OutlookUnread $Item)) {
                $Item.PSObject.Properties['UnRead'].set_Value($true)
                if (-not $wasSaved) { throw 'Cannot save an unread repair on a previously unsaved item without persisting other edits.' }
                $Item.Save()
                if (-not (Get-OutlookUnread $Item)) { throw 'The unread flag was not restored.' }
                $restored = $true
                $Context.restored++
            }
            if ($null -ne $result) {
                $result.unread_after = Get-OutlookUnread $Item
                $result.unread_restored = $restored
            }
        } catch {
            $Context.read_state_failed = $true
            throw ('UNREAD_STATE_UNVERIFIED: ' + $_.Exception.Message)
        }
    }
    return $result
}

function Invoke-OutlookRequest($Application, [string]$Operation, [hashtable]$Options) {
    $allowed = @('max_folders', 'budget_seconds', 'store_id', 'folder_contains')
    if ($Operation -eq 'search') { $allowed += @('subject', 'sender', 'participant', 'body', 'received_after', 'received_before', 'max_candidates', 'limit', 'offset', 'unread_only') }
    if ($Operation -eq 'read') { $allowed += @('entry_id', 'body_chars', 'html') }
    if ($Operation -notin @('probe', 'search', 'read')) { throw 'Unknown operation' }
    foreach ($key in $Options.Keys) { if ($key -notin $allowed) { throw "Unknown option: $key" } }
    if ($Options.ContainsKey('html') -and $Options.html -isnot [bool]) { throw 'html must be boolean' }
    if ($Options.ContainsKey('unread_only') -and $Options.unread_only -isnot [bool]) { throw 'unread_only must be boolean' }
    $context = @{
        issues = (New-Object 'System.Collections.Generic.List[object]')
        folders = (New-Object 'System.Collections.Generic.List[object]')
        stores = (New-Object 'System.Collections.Generic.List[object]')
        clock = [Diagnostics.Stopwatch]::StartNew(); timed_out = $false; restored = 0; read_state_failed = $false
        seconds = (Get-NumberOption $Options 'budget_seconds' 30 1 120)
        max_folders = (Get-NumberOption $Options 'max_folders' 2000 1 20000)
        after = (Get-UtcBoundary $Options 'received_after'); before = (Get-UtcBoundary $Options 'received_before')
    }
    if ($null -ne $context.after -and $null -ne $context.before -and $context.after -ge $context.before) {
        throw 'received_after must precede received_before'
    }
    $session = Get-OutlookValue $Application 'Session'
    $environment = [ordered]@{
        host = $env:COMPUTERNAME; profile = [string](Get-OutlookValue $session 'CurrentProfileName'); outlook_version = [string](Get-OutlookValue $Application 'Version')
        offline = [bool](Get-OutlookValue $session 'Offline'); local_timezone = [TimeZoneInfo]::Local.Id
        server_completeness = 'not_verified'
    }
    if ($Operation -eq 'read') {
        $entry = Get-TextOption $Options 'entry_id'
        $store = Get-TextOption $Options 'store_id'
        if (-not $entry -or -not $store) { throw 'read requires entry_id and store_id' }
        $item = $session.GetItemFromID($entry, $store)
        $parent = Get-OutlookValue $item 'Parent'
        if ([string](Get-OutlookValue $parent 'StoreID') -ne $store -or [string](Get-OutlookValue $item 'EntryID') -ne $entry) { throw 'Message identity did not match the requested IDs' }
        $message = Get-OutlookMail $item $store ([string](Get-OutlookValue $parent 'FolderPath')) $Options $context $true
        if ($null -eq $message) { throw 'The requested item is not a MailItem' }
        return @{ok = $true; action = $Operation; environment = $environment; message = $message; issues = @($context.issues.ToArray())}
    }
    Get-OutlookFolders $session $context
    $publicFolders = @($context.folders.ToArray() | Select-Object store_id, store_name, folder_id, path, mail_folder)
    $base = @{
        ok = $true; action = $Operation; environment = $environment; stores = @($context.stores.ToArray())
        folders_discovered = $context.folders.Count; scope = 'all_attached_stores_and_mail_folders'
    }
    if ($Operation -eq 'probe') {
        $base.folders = $publicFolders
        $base.discovery_complete = ($context.issues.Count -eq 0)
        $base.issues = @($context.issues.ToArray())
        return $base
    }
    $maxCandidates = Get-NumberOption $Options 'max_candidates' 2000 1 100000
    $limit = Get-NumberOption $Options 'limit' 50 1 500
    $offset = Get-NumberOption $Options 'offset' 0 0 10000000
    $storeFilter = Get-TextOption $Options 'store_id'
    $folderFilter = Get-TextOption $Options 'folder_contains'
    $filter = Get-OutlookFilter $Options $context.after $context.before
    $seen = New-Object 'System.Collections.Generic.HashSet[string]'
    $matchedMails = New-Object 'System.Collections.Generic.List[object]'
    $scanned = 0
    $foldersSearched = 0
    $foldersSelected = 0
    $capped = $false
    foreach ($node in $context.folders.ToArray()) {
        if (-not $node.mail_folder) { continue }
        if ($storeFilter -and $node.store_id -ne $storeFilter) { continue }
        if (-not (Test-LiteralContains $node.path $folderFilter)) { continue }
        $foldersSelected++
        if ($capped -or -not (Test-OutlookBudget $context)) { continue }
        try {
            $items = Get-OutlookValue $node.handle 'Items'
            if ($filter) { $items = $items.Restrict($filter) }
            $items.Sort('[ReceivedTime]', $true)
            $item = $items.GetFirst()
            $foldersSearched++
            while ($null -ne $item) {
                if (-not (Test-OutlookBudget $context)) { break }
                if ($scanned -ge $maxCandidates) { $capped = $true; break }
                $scanned++
                try {
                    $entry = [string](Get-OutlookValue $item 'EntryID')
                    if (-not $entry) { throw 'Message has no stable EntryID' }
                    $key = $node.store_id + ':' + $entry
                    if ($seen.Add($key)) {
                        $message = Get-OutlookMail $item $node.store_id $node.path $Options $context $false
                        if ($null -ne $message) { [void]$matchedMails.Add($message) }
                    }
                } catch {
                    if ($context.read_state_failed) { throw }
                    Add-OutlookIssue $context 'message_unavailable' $node.path $_.Exception.Message
                }
                $item = $items.GetNext()
            }
        } catch {
            if ($context.read_state_failed) { throw }
            Add-OutlookIssue $context 'folder_search_failed' $node.path $_.Exception.Message
        }
    }
    if ($capped) { Add-OutlookIssue $context 'candidate_limit' '' 'Candidate limit reached; narrow the query or increase max_candidates.' }
    if ($foldersSelected -eq 0) { Add-OutlookIssue $context 'no_matching_folders' '' 'No accessible mail folders matched the requested scope.' }
    $ordered = @($matchedMails.ToArray() | Sort-Object @{Expression = 'received_utc'; Descending = $true}, store_id, entry_id)
    $page = @($ordered | Select-Object -Skip $offset -First $limit)
    $base.search_complete_in_outlook_data = ($context.issues.Count -eq 0)
    $base.folders_selected = $foldersSelected
    $base.folders_searched = $foldersSearched
    $base.candidates_checked = $scanned
    $base.matches_in_checked_candidates = $ordered.Count
    $base.messages = $page
    $base.offset = $offset
    $base.next_offset = $null
    if (($offset + $page.Count) -lt $ordered.Count) { $base.next_offset = $offset + $page.Count }
    $base.unread_restorations = $context.restored
    $base.issues = @($context.issues.ToArray())
    return $base
}

if ($MyInvocation.InvocationName -ne '.') {
    [Console]::OutputEncoding = New-Object System.Text.UTF8Encoding($false)
    try {
        $options = @{}
        if ($QueryBase64) {
            $decoded = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($QueryBase64)) | ConvertFrom-Json
            if ($null -eq $decoded -or $decoded -isnot [pscustomobject]) { throw 'Query must be a JSON object' }
            foreach ($property in $decoded.PSObject.Properties) { $options[$property.Name] = $property.Value }
        }
        if ($env:OS -ne 'Windows_NT') { throw 'This helper requires Windows PowerShell and an active classic Outlook session.' }
        try { $app = [Runtime.InteropServices.Marshal]::GetActiveObject('Outlook.Application') }
        catch { throw 'No accessible active classic Outlook session. Start classic Outlook in the same Windows user session, then retry.' }
        Invoke-OutlookRequest $app $Action $options | ConvertTo-Json -Depth 12 -Compress
        # Never call Outlook.Quit: the application belongs to the user.
    } catch {
        @{ok = $false; error = $_.Exception.Message; unread_state_verified = $false} | ConvertTo-Json -Compress
        exit 2
    }
}
