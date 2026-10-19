param(
    [ValidateSet('probe', 'search', 'read', 'session')][string]$Action = 'probe',
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

function Get-TermsOption($Options, [string]$Name) {
    if (-not $Options.ContainsKey($Name)) { return }
    if ($Options[$Name] -isnot [array] -or $Options[$Name].Count -gt 100) { throw "$Name must be an array of at most 100 strings" }
    foreach ($term in $Options[$Name]) {
        if ($term -isnot [string] -or -not $term.Trim()) { throw "$Name must contain nonempty strings" }
        $term
    }
}

function New-OutlookRuntime {
    return @{
        folders = $null; stores = $null; discovered_at = $null; identity = ''
        jobs = @{}; bodies = @{}; body_bytes = 0; refs = @{}
    }
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

function Get-OutlookFilter($Options, $After, $Before, [bool]$Table = $false) {
    $parts = New-Object 'System.Collections.Generic.List[string]'
    $subject = Get-TextOption $Options 'subject'
    # Wildcards in user text are literal: use client matching for those queries.
    if ($subject -and $subject -notmatch '[%_\[\]]') {
        [void]$parts.Add(('"urn:schemas:httpmail:subject" LIKE ''%{0}%''' -f $subject.Replace("'", "''")))
    }
    if ($Table) {
        $body = Get-TextOption $Options 'body'
        if ($body -and $body -notmatch '[%_\[\]]') {
            [void]$parts.Add(('"urn:schemas:httpmail:textdescription" LIKE ''%{0}%''' -f $body.Replace("'", "''")))
        }
        $terms = @(Get-TermsOption $Options 'terms')
        $contacts = @(Get-TermsOption $Options 'contacts')
        # A contact may match a resolved recipient SMTP address unavailable to
        # a table filter. Keep that union broad rather than dropping sent mail.
        if ($terms.Count -gt 0 -and $contacts.Count -eq 0 -and @($terms | Where-Object { $_ -match '[%_\[\]]' }).Count -eq 0) {
            $union = @($terms | ForEach-Object {
                $literal = $_.Replace("'", "''")
                '("urn:schemas:httpmail:subject" LIKE ''%{0}%'' OR "urn:schemas:httpmail:textdescription" LIKE ''%{0}%'')' -f $literal
            })
            [void]$parts.Add(('(' + [string]::Join(' OR ', $union) + ')'))
        }
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
        # Finish the current item's recipients. Stopping halfway would make a
        # resumable scan skip an unevaluated contact match as already seen.
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

function Get-OutlookText($Item, [string]$StoreId, [string]$Property, $Context) {
    $runtime = $Context.runtime
    $version = $null
    $key = ''
    if ($null -ne $runtime) {
        try {
            $modified = Get-OutlookValue $Item 'LastModificationTime'
            if ($modified -is [datetime]) {
                $version = $modified.ToUniversalTime().Ticks
                $key = $StoreId + ':' + [string](Get-OutlookValue $Item 'EntryID') + ':' + $Property
                if ($runtime.bodies.ContainsKey($key) -and $runtime.bodies[$key].version -eq $version) {
                    $Context.cache_hits++
                    return $runtime.bodies[$key].text
                }
            }
        } catch { $version = $null } # No reliable version means no cached text.
    }
    $Context.body_reads++
    $text = [string](Get-OutlookValue $Item $Property)
    if ($null -ne $version -and $text.Length -le 1048576) {
        # Bounded process memory only; nothing is written to a mailbox mirror.
        $bytes = $text.Length * 2
        if ($runtime.body_bytes + $bytes -gt 33554432) { $runtime.bodies.Clear(); $runtime.body_bytes = 0 }
        if ($runtime.bodies.ContainsKey($key)) { $runtime.body_bytes -= $runtime.bodies[$key].text.Length * 2 }
        $runtime.bodies[$key] = @{version = $version; text = $text}
        $runtime.body_bytes += $bytes
    }
    return $text
}

function Format-OutlookMessage($Message, $Runtime) {
    if ($null -eq $Runtime) { return $Message }
    $identity = $Message.store_id + ':' + $Message.entry_id
    $sha = [Security.Cryptography.SHA256]::Create()
    try { $digest = [BitConverter]::ToString($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($identity))).Replace('-', '').ToLowerInvariant() }
    finally { $sha.Dispose() }
    $ref = 'm-' + $digest.Substring(0, 24)
    if ($Runtime.refs.ContainsKey($ref) -and $Runtime.refs[$ref].identity -ne $identity) { throw 'Message reference collision' }
    $Runtime.refs[$ref] = @{identity = $identity; store_id = $Message.store_id; entry_id = $Message.entry_id}
    $compact = $Message | Select-Object * -ExcludeProperty entry_id, store_id
    $compact | Add-Member NoteProperty ref $ref
    return $compact
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
        $terms = @(Get-TermsOption $Options 'terms')
        $contacts = @(Get-TermsOption $Options 'contacts')
        $recipients = @()
        if ($IncludeBody -or ($isMatch -and ($participant -or $contacts.Count -gt 0))) {
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
        $unionMatch = ($terms.Count + $contacts.Count -eq 0)
        foreach ($term in $terms) {
            if (Test-LiteralContains $subject $term) { $unionMatch = $true; break }
        }
        foreach ($contact in $contacts) {
            if ((Test-LiteralContains $senderName $contact) -or (Test-LiteralContains $senderEmail $contact)) { $unionMatch = $true; break }
            foreach ($recipient in $recipients) {
                if ((Test-LiteralContains $recipient.name $contact) -or (Test-LiteralContains $recipient.email $contact)) { $unionMatch = $true; break }
            }
            if ($unionMatch) { break }
        }
        if ($isMatch -and ($IncludeBody -or $bodyTerm -or (-not $unionMatch -and $terms.Count -gt 0))) {
            $body = Get-OutlookText $Item $StoreId 'Body' $Context
            if (-not (Test-LiteralContains $body $bodyTerm)) { $isMatch = $false }
            foreach ($term in $terms) {
                if (Test-LiteralContains $body $term) { $unionMatch = $true; break }
            }
        }
        $isMatch = $isMatch -and $unionMatch
        if ($isMatch) {
            $result = [pscustomobject]@{
                entry_id = [string](Get-OutlookValue $Item 'EntryID'); store_id = $StoreId; folder = $Path
                subject = $subject; sender_name = $senderName; sender_email = $senderEmail
                received_utc = $received.ToString('o'); unread_before = $beforeUnread
                unread_after = $null; unread_restored = $false
            }
            if ($IncludeBody -or $participant -or $contacts.Count -gt 0) { $result | Add-Member NoteProperty recipients $recipients }
            if ($IncludeBody) {
                $limit = Get-NumberOption $Options 'body_chars' 8000 0 1000000
                $result | Add-Member NoteProperty body (Get-ClippedText $body $limit)
                if ($Options.ContainsKey('html') -and $Options.html) {
                    $result | Add-Member NoteProperty html (Get-ClippedText (Get-OutlookText $Item $StoreId 'HTMLBody' $Context) $limit)
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

function Open-OutlookIterator($Node, $Options, $Context, $Job) {
    if ($Job.engine -ne 'scan') {
        try {
            $table = $Node.handle.GetTable((Get-OutlookFilter $Options $Context.after $Context.before $true), 0)
            $columns = Get-OutlookValue $table 'Columns'
            $columns.RemoveAll()
            [void]$columns.Add('EntryID')
            $Job.table_folders++
            return @{kind = 'table'; handle = $table}
        } catch {
            # Unsupported provider/filter: a successful full scan is a valid fallback.
            [void]$Job.fallbacks.Add([pscustomobject]@{folder = $Node.path; reason = $_.Exception.Message})
        }
    }
    $items = Get-OutlookValue $Node.handle 'Items'
    $filter = Get-OutlookFilter $Options $Context.after $Context.before
    if ($filter) { $items = $items.Restrict($filter) }
    $items.Sort('[ReceivedTime]', $true)
    $Job.scan_folders++
    return @{kind = 'scan'; handle = $items; current = $items.GetFirst()}
}

function Invoke-OutlookRequest($Application, [string]$Operation, [hashtable]$Options, $Runtime = $null) {
    $allowed = @('max_folders', 'budget_seconds', 'store_id', 'folder_contains')
    if ($Operation -eq 'search') { $allowed += @('subject', 'sender', 'participant', 'body', 'terms', 'contacts', 'engine', 'continuation', 'received_after', 'received_before', 'max_candidates', 'limit', 'offset', 'unread_only') }
    if ($Operation -eq 'read') { $allowed += @('entry_id', 'ref', 'body_chars', 'html') }
    if ($Operation -notin @('probe', 'search', 'read')) { throw 'Unknown operation' }
    foreach ($key in $Options.Keys) { if ($key -notin $allowed) { throw "Unknown option: $key" } }
    if ($Options.ContainsKey('html') -and $Options.html -isnot [bool]) { throw 'html must be boolean' }
    if ($Options.ContainsKey('unread_only') -and $Options.unread_only -isnot [bool]) { throw 'unread_only must be boolean' }
    [void]@(Get-TermsOption $Options 'terms')
    [void]@(Get-TermsOption $Options 'contacts')
    $context = @{
        issues = (New-Object 'System.Collections.Generic.List[object]')
        folders = (New-Object 'System.Collections.Generic.List[object]')
        stores = (New-Object 'System.Collections.Generic.List[object]')
        clock = [Diagnostics.Stopwatch]::StartNew(); timed_out = $false; restored = 0; read_state_failed = $false
        seconds = (Get-NumberOption $Options 'budget_seconds' 30 1 120)
        max_folders = (Get-NumberOption $Options 'max_folders' 2000 1 20000)
        after = (Get-UtcBoundary $Options 'received_after'); before = (Get-UtcBoundary $Options 'received_before')
        runtime = $Runtime; body_reads = 0; cache_hits = 0
    }
    $session = Get-OutlookValue $Application 'Session'
    $environment = [ordered]@{
        host = $env:COMPUTERNAME; profile = [string](Get-OutlookValue $session 'CurrentProfileName'); outlook_version = [string](Get-OutlookValue $Application 'Version')
        offline = [bool](Get-OutlookValue $session 'Offline'); local_timezone = [TimeZoneInfo]::Local.Id
        server_completeness = 'not_verified'
    }
    # A profile/store change invalidates cached folder handles, bodies and jobs.
    if ($null -ne $Runtime) {
        $ids = @()
        $stores = Get-OutlookValue $session 'Stores'
        $count = [int](Get-OutlookValue $stores 'Count')
        for ($i = 1; $i -le $count; $i++) { $ids += [string](Get-OutlookValue ($stores.Item($i)) 'StoreID') }
        $identity = $environment.host + ':' + $environment.profile + ':' + [string]::Join('|', $ids)
        if ($Runtime.identity -and $Runtime.identity -ne $identity) {
            $Runtime.Clear()
            foreach ($pair in (New-OutlookRuntime).GetEnumerator()) { $Runtime[$pair.Key] = $pair.Value }
        }
        $Runtime.identity = $identity
    }
    if ($Operation -eq 'read') {
        $ref = Get-TextOption $Options 'ref'
        if ($ref) {
            if ($null -eq $Runtime -or -not $Runtime.refs.ContainsKey($ref)) { throw 'Unknown ref; read it in the session that returned it.' }
            if ($Options.ContainsKey('entry_id') -or $Options.ContainsKey('store_id')) { throw 'Use ref or the two Outlook IDs, not both.' }
            $Options = $Options.Clone()
            $Options.entry_id = $Runtime.refs[$ref].entry_id; $Options.store_id = $Runtime.refs[$ref].store_id
        }
        $entry = Get-TextOption $Options 'entry_id'
        $store = Get-TextOption $Options 'store_id'
        if (-not $entry -or -not $store) { throw 'read requires entry_id and store_id' }
        $item = $session.GetItemFromID($entry, $store)
        $parent = Get-OutlookValue $item 'Parent'
        $message = Get-OutlookMail $item $store ([string](Get-OutlookValue $parent 'FolderPath')) $Options $context $true
        if ($null -eq $message) { throw 'The requested item is not a MailItem' }
        return @{
            ok = $true; action = $Operation; environment = $environment; message = (Format-OutlookMessage $message $Runtime); issues = @($context.issues.ToArray())
            timings_ms = @{total = [math]::Round($context.clock.Elapsed.TotalMilliseconds, 1)}
            body_reads = $context.body_reads; body_cache_hits = $context.cache_hits
        }
    }
    $token = Get-TextOption $Options 'continuation'
    $job = $null
    if ($token) {
        if ($null -eq $Runtime -or -not $Runtime.jobs.ContainsKey($token)) { throw 'Unknown continuation; resume it in the same active helper session.' }
        foreach ($key in $Options.Keys) {
            if ($key -notin @('continuation', 'budget_seconds', 'max_candidates', 'limit')) { throw 'A continuation cannot change search filters or scope.' }
        }
        $job = $Runtime.jobs[$token]
        $context.after = Get-UtcBoundary $job.options 'received_after'
        $context.before = Get-UtcBoundary $job.options 'received_before'
    }
    if ($null -ne $context.after -and $null -ne $context.before -and $context.after -ge $context.before) {
        throw 'received_after must precede received_before'
    }
    $discoveryStart = $context.clock.Elapsed.TotalMilliseconds
    $discoveryReused = $false
    if ($null -ne $Runtime -and $null -ne $Runtime.folders) {
        $context.folders = $Runtime.folders
        $context.stores = $Runtime.stores
        $discoveryReused = $true
    } else {
        Get-OutlookFolders $session $context
        if ($null -ne $Runtime -and $context.issues.Count -eq 0) {
            $Runtime.folders = $context.folders; $Runtime.stores = $context.stores
            $Runtime.discovered_at = [datetime]::UtcNow.ToString('o')
        }
    }
    $discoveryMs = $context.clock.Elapsed.TotalMilliseconds - $discoveryStart
    if ($Operation -eq 'search' -and $null -ne $Runtime -and $null -eq $job -and $context.issues.Count -gt 0) {
        throw 'Folder discovery is incomplete. Retry probe with an adequate budget and resolve its issues before starting a resumable search.'
    }
    $base = @{
        ok = $true; action = $Operation; environment = $environment; stores = @($context.stores.ToArray())
        folders_discovered = $context.folders.Count; scope = 'all_attached_stores_and_mail_folders'
        folder_discovery_reused = $discoveryReused
    }
    if ($Operation -eq 'probe') {
        $base.folders = @($context.folders.ToArray() | Select-Object store_id, store_name, folder_id, path, mail_folder)
        $base.discovery_complete = ($context.issues.Count -eq 0)
        $base.issues = @($context.issues.ToArray())
        $base.timings_ms = @{folder_discovery = [math]::Round($discoveryMs, 1); total = [math]::Round($context.clock.Elapsed.TotalMilliseconds, 1)}
        return $base
    }
    $maxCandidates = Get-NumberOption $Options 'max_candidates' 2000 1 100000
    $limit = Get-NumberOption $Options 'limit' 50 1 500
    if ($null -eq $job) {
        $engine = Get-TextOption $Options 'engine' 'table'
        if ($engine -notin @('table', 'scan')) { throw 'engine must be table or scan' }
        $offset = Get-NumberOption $Options 'offset' 0 0 10000000
        if ($null -ne $Runtime -and $offset -ne 0) { throw 'Use continuation instead of offset in a helper session.' }
        if ($null -ne $Runtime -and $Runtime.jobs.Count -ge 8) { throw 'Finish outstanding continuations or refresh before starting more searches.' }
        $storeFilter = Get-TextOption $Options 'store_id'
        $folderFilter = Get-TextOption $Options 'folder_contains'
        $nodes = @($context.folders.ToArray() | Where-Object {
            $_.mail_folder -and (-not $storeFilter -or $_.store_id -eq $storeFilter) -and (Test-LiteralContains $_.path $folderFilter)
        })
        if ($nodes.Count -eq 0) { Add-OutlookIssue $context 'no_matching_folders' '' 'No accessible mail folders matched the requested scope.' }
        $job = @{
            options = $Options.Clone(); engine = $engine; nodes = $nodes; folder_index = 0; iterator = $null
            seen = (New-Object 'System.Collections.Generic.HashSet[string]')
            matches = (New-Object 'System.Collections.Generic.List[object]'); ordered = $null
            issues = @(); fallbacks = (New-Object 'System.Collections.Generic.List[object]')
            checked = 0; folders_searched = 0; offset = $offset; table_folders = 0; scan_folders = 0
        }
        if ($null -ne $Runtime) { $token = [guid]::NewGuid().ToString('N'); $Runtime.jobs[$token] = $job }
    }
    foreach ($issue in $job.issues) { [void]$context.issues.Add($issue) }
    $searchStart = $context.clock.Elapsed.TotalMilliseconds
    $scanned = 0
    while ($job.folder_index -lt $job.nodes.Count) {
        if (-not (Test-OutlookBudget $context)) { break }
        if ($scanned -ge $maxCandidates) {
            Add-OutlookIssue $context 'candidate_limit' '' 'Candidate budget reached; continue in this session or narrow a one-shot query.'
            break
        }
        $node = $job.nodes[$job.folder_index]
        try {
            if ($null -eq $job.iterator) {
                $job.iterator = Open-OutlookIterator $node $job.options $context $job
                $job.folders_searched++
            }
            $iterator = $job.iterator
            $item = $null
            $entry = ''
            if ($iterator.kind -eq 'table') {
                if ([bool](Get-OutlookValue $iterator.handle 'EndOfTable')) {
                    $job.iterator = $null; $job.folder_index++; continue
                }
                $row = $iterator.handle.GetNextRow()
                $values = @($row.GetValues())
                $entry = [string]$values[0]
            } else {
                $item = $iterator.current
                if ($null -eq $item) { $job.iterator = $null; $job.folder_index++; continue }
                $entry = [string](Get-OutlookValue $item 'EntryID')
            }
            $scanned++; $job.checked++
            try {
                if (-not $entry) { throw 'Message has no stable EntryID' }
                if ($job.seen.Add($node.store_id + ':' + $entry)) {
                    if ($null -eq $item) { $item = $session.GetItemFromID($entry, $node.store_id) }
                    $message = Get-OutlookMail $item $node.store_id $node.path $job.options $context $false
                    if ($null -ne $message) { [void]$job.matches.Add($message) }
                }
            } catch {
                if ($context.read_state_failed) { throw }
                Add-OutlookIssue $context 'message_unavailable' $node.path $_.Exception.Message
            }
            if ($iterator.kind -eq 'scan') { $iterator.current = $iterator.handle.GetNext() }
        } catch {
            if ($context.read_state_failed) { throw }
            Add-OutlookIssue $context 'folder_search_failed' $node.path $_.Exception.Message
            $job.iterator = $null; $job.folder_index++
        }
    }
    $finished = $job.folder_index -ge $job.nodes.Count
    $job.issues = @($context.issues.ToArray() | Where-Object { $_.code -notin @('candidate_limit', 'time_budget') })
    $base.messages = @()
    $base.next_offset = $null
    $base.continuation = $null
    if ($finished -or $null -eq $Runtime) {
        if ($null -eq $job.ordered) { $job.ordered = @($job.matches.ToArray() | Sort-Object @{Expression = 'received_utc'; Descending = $true}, store_id, entry_id) }
        $base.offset = $job.offset
        $base.messages = @($job.ordered | Select-Object -Skip $job.offset -First $limit | ForEach-Object { Format-OutlookMessage $_ $Runtime })
        $job.offset += $base.messages.Count
        if ($job.offset -lt $job.ordered.Count) { $base.next_offset = $job.offset }
    }
    if ($null -ne $Runtime) {
        if (-not $finished -or $null -ne $base.next_offset) { $base.continuation = $token }
        else { $Runtime.jobs.Remove($token) }
    }
    $base.search_complete_in_outlook_data = ($finished -and $context.issues.Count -eq 0)
    $base.folders_selected = $job.nodes.Count
    $base.folders_searched = $job.folders_searched
    $base.candidates_checked = $scanned
    $base.candidates_checked_total = $job.checked
    $base.matches_in_checked_candidates = $job.matches.Count
    $base.unread_restorations = $context.restored
    $base.issues = @($context.issues.ToArray())
    $base.engine = @{table_folders = $job.table_folders; scan_folders = $job.scan_folders; fallbacks = @($job.fallbacks.ToArray()); semantics = 'literal_substring'}
    $base.body_reads = $context.body_reads; $base.body_cache_hits = $context.cache_hits
    if ($null -ne $Runtime) { $base.Remove('stores') }
    $base.timings_ms = @{
        folder_discovery = [math]::Round($discoveryMs, 1)
        search = [math]::Round(($context.clock.Elapsed.TotalMilliseconds - $searchStart), 1)
        total = [math]::Round($context.clock.Elapsed.TotalMilliseconds, 1)
    }
    return $base
}

function Invoke-OutlookSession($Application, $InputReader = [Console]::In, $OutputWriter = [Console]::Out) {
    $runtime = New-OutlookRuntime
    $OutputWriter.WriteLine((@{ok = $true; action = 'session'; ready = $true} | ConvertTo-Json -Compress))
    $OutputWriter.Flush()
    while ($null -ne ($line = $InputReader.ReadLine())) {
        try {
            $request = $line | ConvertFrom-Json
            if ($request.action -eq 'close') {
                $OutputWriter.WriteLine((@{ok = $true; action = 'close'} | ConvertTo-Json -Compress))
                $OutputWriter.Flush()
                break
            }
            if ($request.action -eq 'refresh') {
                $runtime = New-OutlookRuntime
                $result = @{ok = $true; action = 'refresh'}
            } else {
                $options = @{}
                if ($null -ne $request.options) {
                    if ($request.options -isnot [pscustomobject]) { throw 'options must be a JSON object' }
                    foreach ($property in $request.options.PSObject.Properties) { $options[$property.Name] = $property.Value }
                }
                $result = Invoke-OutlookRequest $Application ([string]$request.action) $options $runtime
            }
            $OutputWriter.WriteLine(($result | ConvertTo-Json -Depth 12 -Compress))
            $OutputWriter.Flush()
        } catch {
            $OutputWriter.WriteLine((@{ok = $false; error = $_.Exception.Message; unread_state_verified = $false} | ConvertTo-Json -Compress))
            $OutputWriter.Flush()
            # An unknown read state must not be followed by more mail work.
            break
        }
    }
}

if ($MyInvocation.InvocationName -ne '.') {
    [Console]::OutputEncoding = [Text.Encoding]::UTF8
    [Console]::InputEncoding = [Text.Encoding]::UTF8
    try {
        if ($env:OS -ne 'Windows_NT') { throw 'This helper requires Windows PowerShell and an active classic Outlook session.' }
        try { $app = [Runtime.InteropServices.Marshal]::GetActiveObject('Outlook.Application') }
        catch { throw 'No accessible active classic Outlook session. Start classic Outlook in the same Windows user session, then retry.' }
        if ($Action -eq 'session') {
            Invoke-OutlookSession $app
        } else {
            $options = @{}
            if ($QueryBase64) {
                $decoded = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($QueryBase64)) | ConvertFrom-Json
                if ($decoded -isnot [pscustomobject]) { throw 'Query must be a JSON object' }
                foreach ($property in $decoded.PSObject.Properties) { $options[$property.Name] = $property.Value }
            }
            Invoke-OutlookRequest $app $Action $options | ConvertTo-Json -Depth 12 -Compress
        }
        # Never call Outlook.Quit: the application belongs to the user.
    } catch {
        @{ok = $false; error = $_.Exception.Message; unread_state_verified = $false} | ConvertTo-Json -Compress
        exit 2
    }
}
