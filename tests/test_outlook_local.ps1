# Behavioral tests with synthetic mail only; run using Windows PowerShell 5.1.
$ErrorActionPreference = 'Stop'
$source = Join-Path $PSScriptRoot '../skills/outlook-local/scripts/outlook-local.ps1'
$tokens = $null
$parseErrors = $null
[void][System.Management.Automation.Language.Parser]::ParseFile($source, [ref]$tokens, [ref]$parseErrors)
if ($parseErrors.Count -gt 0) { throw ($parseErrors | Out-String) }
. $source

Add-Type -TypeDefinition @'
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text.RegularExpressions;

public class FakeMail {
    public int Class = 43;
    public string EntryID, Subject, SenderName = "Example sender", SenderEmailAddress = "sender@example.invalid";
    public string SenderEmailType = "SMTP", HTMLBody = "<p>example</p>";
    public DateTime ReceivedTime;
    public DateTime LastModificationTime = new DateTime(2026, 10, 16, 10, 0, 0, DateTimeKind.Utc);
    public object UnRead;
    public bool Saved = true, MarkReadOnBody, ThrowOnBody, FailSave;
    public FakeAddress Sender;
    private FakeRecipients recipients = new FakeRecipients();
    public bool MarkReadOnRecipients;
    public FakeRecipients Recipients {
        get { if (MarkReadOnRecipients) UnRead = false; return recipients; }
    }
    public int Saves, BodyReads;
    public FakeFolder Parent;
    public string Text = "needle";
    public string Body {
        get {
            BodyReads++;
            if (MarkReadOnBody) UnRead = false;
            if (ThrowOnBody) throw new InvalidOperationException("Synthetic body failure");
            return Text;
        }
    }
    public void Save() {
        Saves++;
        if (FailSave) throw new InvalidOperationException("Synthetic save failure");
        Saved = true;
    }
}
public class FakeExchange {
    public string PrimarySmtpAddress = "sender@example.invalid";
}
public class FakeRecipientAccessor {
    public bool Fail;
    public string Smtp = "contact@example.invalid";
    public string GetProperty(string name) {
        if (Fail) throw new InvalidOperationException("Synthetic recipient lookup failure");
        return Smtp;
    }
}
public class FakeRecipient {
    public string Name = "Project Contact", Address = "contact@example.invalid";
    public int Type = 1;
    public FakeRecipientAccessor PropertyAccessor = new FakeRecipientAccessor();
}
public class FakeRecipients {
    public List<FakeRecipient> Values = new List<FakeRecipient>();
    public bool Fail;
    public int DelayMilliseconds;
    public int Count {
        get {
            if (DelayMilliseconds > 0) System.Threading.Thread.Sleep(DelayMilliseconds);
            if (Fail) throw new InvalidOperationException("Synthetic recipients unavailable");
            return Values.Count;
        }
    }
    public FakeRecipient Item(int index) { return Values[index - 1]; }
}
public class FakeAddress {
    public bool Fail, NoAddress;
    public FakeExchange GetExchangeUser() {
        if (Fail) throw new InvalidOperationException("Synthetic address lookup failure");
        if (NoAddress) return null;
        return new FakeExchange();
    }
    public FakeExchange GetExchangeDistributionList() { return null; }
}
public class FakeItems {
    public List<FakeMail> Messages = new List<FakeMail>();
    public string LastFilter;
    public bool FailFilter;
    private int cursor;
    public FakeItems Restrict(string filter) {
        LastFilter = filter;
        if (FailFilter) throw new InvalidOperationException("Synthetic filter failure");
        // Deliberately return broad candidates: client matching must reject false matches.
        return this;
    }
    public void Sort(string field, bool descending) {
        Messages = Messages.OrderByDescending(m => m.ReceivedTime).ToList();
    }
    public FakeMail GetFirst() { cursor = 0; return Messages.Count == 0 ? null : Messages[0]; }
    public FakeMail GetNext() { cursor++; return cursor >= Messages.Count ? null : Messages[cursor]; }
}
public class FakeFolders {
    public List<FakeFolder> Values = new List<FakeFolder>();
    public int Count { get { return Values.Count; } }
    public FakeFolder Item(int index) { return Values[index - 1]; }
}
public class FakeColumns {
    public void RemoveAll() { }
    public void Add(string name) { if (name != "EntryID") throw new Exception("Unexpected table column"); }
}
public class FakeRow {
    private string id;
    public FakeRow(string entry) { id = entry; }
    public object[] GetValues() { return new object[] { id }; }
}
public class FakeTable {
    private List<FakeMail> values;
    private int cursor;
    public FakeColumns Columns = new FakeColumns();
    public bool EndOfTable { get { return cursor >= values.Count; } }
    public FakeTable(List<FakeMail> messages) { values = messages; }
    public FakeRow GetNextRow() { return new FakeRow(values[cursor++].EntryID); }
}
public class FakeFolder {
    public string EntryID, StoreID, FolderPath;
    public int DefaultItemType = 0;
    public FakeFolders Folders = new FakeFolders();
    public FakeItems Items = new FakeItems();
    public bool FailTable;
    public int TableCalls;
    public FakeFolder(string id, string store, string path) { EntryID = id; StoreID = store; FolderPath = path; }
    public void Add(FakeMail mail) { mail.Parent = this; Items.Messages.Add(mail); }
    public FakeTable GetTable(string filter, int contents) {
        TableCalls++;
        Items.LastFilter = filter;
        if (FailTable || Items.FailFilter) throw new InvalidOperationException("Synthetic table filter failure");
        // A provider-side view uses stored text, without opening MailItem.Body.
        var parts = Regex.Matches(filter, "\\\"urn:schemas:httpmail:(subject|textdescription)\\\" LIKE '((?:[^']|'')*)'");
        var matches = Items.Messages.Where(mail => {
            if (parts.Count == 0) return true;
            var checks = parts.Cast<Match>().Select(part => {
                string text = part.Groups[1].Value == "subject" ? mail.Subject : mail.Text;
                string term = part.Groups[2].Value.Replace("''", "'").Trim('%');
                return text.IndexOf(term, StringComparison.OrdinalIgnoreCase) >= 0;
            });
            return filter.Contains(" OR ") ? checks.Any(value => value) : checks.All(value => value);
        }).ToList();
        return new FakeTable(matches);
    }
}
public class FakeStore {
    public string StoreID, DisplayName;
    public FakeFolder Root;
    public bool FailRoot;
    public FakeFolder GetRootFolder() {
        if (FailRoot) throw new InvalidOperationException("Synthetic inaccessible store");
        return Root;
    }
}
public class FakeStores {
    public List<FakeStore> Values = new List<FakeStore>();
    public int Count { get { return Values.Count; } }
    public FakeStore Item(int index) { return Values[index - 1]; }
}
public class FakeSession {
    public string CurrentProfileName = "Synthetic profile";
    public bool Offline;
    public FakeStores Stores = new FakeStores();
    public FakeMail GetItemFromID(string entry, string store) {
        foreach (var s in Stores.Values.Where(s => s.StoreID == store)) {
            var queue = new Queue<FakeFolder>(); queue.Enqueue(s.Root);
            while (queue.Count > 0) {
                var f = queue.Dequeue();
                var m = f.Items.Messages.FirstOrDefault(candidate => candidate.EntryID == entry);
                if (m != null) return m;
                foreach (var child in f.Folders.Values) queue.Enqueue(child);
            }
        }
        throw new InvalidOperationException("Synthetic missing message");
    }
}
public class FakeApp {
    public string Version = "synthetic";
    public FakeSession Session = new FakeSession();
}
'@

function Assert-True($Condition, [string]$Message) {
    if (-not $Condition) { throw $Message }
}

function New-Fixture {
    $app = New-Object FakeApp
    foreach ($storeId in @('synthetic-a', 'synthetic-b')) {
        $store = New-Object FakeStore
        $store.StoreID = $storeId
        $store.DisplayName = $storeId
        $store.Root = New-Object FakeFolder('root', $storeId, ('\\' + $storeId))
        $app.Session.Stores.Values.Add($store)
        foreach ($name in @('Inbox', 'Project', 'Deleted Items', 'Junk Email')) {
            $folder = New-Object FakeFolder($name, $storeId, ($store.Root.FolderPath + '\' + $name))
            $store.Root.Folders.Values.Add($folder)
            $mail = New-Object FakeMail
            $mail.EntryID = $name
            $mail.Subject = 'tracker ' + $name
            $mail.UnRead = $true
            $mail.ReceivedTime = [datetime]::Parse('2026-10-16T10:15:00Z').ToUniversalTime()
            $folder.Add($mail)
        }
        $project = $store.Root.Folders.Item(2)
        $nested = New-Object FakeFolder('nested', $storeId, ($project.FolderPath + '\Nested'))
        $project.Folders.Values.Add($nested)
        $mail = New-Object FakeMail
        $mail.EntryID = 'nested-mail'
        $mail.Subject = "O'Brien tracker"
        $mail.UnRead = $false
        $mail.ReceivedTime = [datetime]::Parse('2026-10-16T11:15:00Z').ToUniversalTime()
        $nested.Add($mail)
    }
    return $app
}

$script:passed = 0
function Invoke-Case([string]$Name, [scriptblock]$Body) {
    & $Body
    $script:passed++
    Write-Host ('PASS ' + $Name)
}

Invoke-Case 'all stores, nested folders, deleted and junk; no normal saves' {
    $app = New-Fixture
    $result = Invoke-OutlookRequest $app 'search' @{}
    Assert-True ($result.messages.Count -eq 10) 'Missing messages across stores/folders'
    Assert-True $result.search_complete_in_outlook_data 'Complete synthetic search marked incomplete'
    Assert-True (@($result.messages | Where-Object { $_.folder -like '*Deleted Items' }).Count -eq 2) 'Deleted items omitted'
    Assert-True (@($result.messages | Where-Object { $_.folder -like '*Junk Email' }).Count -eq 2) 'Junk omitted'
    Assert-True (@($result.messages | Where-Object { $_.entry_id -eq 'Inbox' }).Count -eq 2) 'IDs from separate stores collapsed'
    foreach ($store in $app.Session.Stores.Values) {
        Assert-True ($store.Root.Folders.Item(1).Items.Messages[0].Saves -eq 0) 'Ordinary search saved mail'
    }
    $unread = Invoke-OutlookRequest $app 'search' @{unread_only = $true}
    Assert-True ($unread.messages.Count -eq 8) 'Unread-only search included read messages'
}

Invoke-Case 'subject uses DASL and escaped literals; false candidates excluded' {
    $app = New-Fixture
    $result = Invoke-OutlookRequest $app 'search' @{subject = "O'Brien"}
    Assert-True ($result.messages.Count -eq 2) 'Literal subject matching failed'
    $filter = $app.Session.Stores.Item(1).Root.Folders.Item(1).Items.LastFilter
    Assert-True ($filter.Contains("O''Brien") -and $filter.StartsWith('@SQL=')) 'Subject was not safely DASL-filtered'
    $app.Session.Stores.Item(1).Root.Folders.Item(1).Items.Messages[0].Subject = 'literal 100%_value'
    $result = Invoke-OutlookRequest $app 'search' @{subject = '100%_'}
    Assert-True ($result.messages.Count -eq 1) 'User wildcard characters were not literal'
}

Invoke-Case 'UTC boundaries, sender and full-body matching' {
    $app = New-Fixture
    $result = Invoke-OutlookRequest $app 'search' @{
        sender = 'sender@example.invalid'; body = 'needle'
        received_after = '2026-10-16T12:00:00+02:00'; received_before = '2026-10-16T13:00:00+02:00'
    }
    Assert-True ($result.messages.Count -eq 8) 'Date or body filtering failed'
    Assert-True (@($result.messages | Where-Object { $_.entry_id -eq 'nested-mail' }).Count -eq 0) 'Exclusive upper boundary failed'
}

Invoke-Case 'unread preserved, body clipping and full Unicode/HTML' {
    $app = New-Fixture
    $mail = $app.Session.GetItemFromID('Inbox', 'synthetic-a')
    $mail.Text = 'a' + [char]::ConvertFromUtf32(0x1F600) + ' end'
    $options = @{entry_id = 'Inbox'; store_id = 'synthetic-a'; body_chars = 2; html = $true}
    $result = Invoke-OutlookRequest $app 'read' $options
    Assert-True ($result.message.body.text -eq 'a' -and $result.message.body.truncated) 'Surrogate pair was split'
    Assert-True ($mail.UnRead -and $mail.Saves -eq 0) 'An ordinary unread read wrote mail'
    $options.body_chars = 0
    $result = Invoke-OutlookRequest $app 'read' $options
    Assert-True ($result.message.body.text -eq $mail.Text -and -not $result.message.body.truncated) 'Full body did not roundtrip'
    Assert-True ($result.message.html.text -eq '<p>example</p>') 'HTML was not returned as source data'
}

Invoke-Case 'repair formerly unread mail only when body reading changes status' {
    $app = New-Fixture
    $mail = $app.Session.GetItemFromID('Inbox', 'synthetic-a')
    $mail.MarkReadOnBody = $true
    $result = Invoke-OutlookRequest $app 'read' @{entry_id = 'Inbox'; store_id = 'synthetic-a'}
    Assert-True ($mail.UnRead -and $mail.Saves -eq 1 -and $result.message.unread_restored) 'Unread repair failed'
    $mail.UnRead = $false
    $result = Invoke-OutlookRequest $app 'read' @{entry_id = 'Inbox'; store_id = 'synthetic-a'}
    Assert-True (-not $mail.UnRead -and $mail.Saves -eq 1) 'Already-read mail was marked unread or saved'
}

Invoke-Case 'body failure still restores unread status' {
    $app = New-Fixture
    $mail = $app.Session.GetItemFromID('Inbox', 'synthetic-a')
    $mail.MarkReadOnBody = $true
    $mail.ThrowOnBody = $true
    $failed = $false
    try { [void](Invoke-OutlookRequest $app 'read' @{entry_id = 'Inbox'; store_id = 'synthetic-a'}) } catch { $failed = $true }
    Assert-True ($failed -and $mail.UnRead -and $mail.Saves -eq 1) 'Failure path lost unread state'
}

Invoke-Case 'failed repair and unsaved items stop without claiming success' {
    foreach ($unsaved in @($false, $true)) {
        $app = New-Fixture
        $mail = $app.Session.GetItemFromID('Inbox', 'synthetic-a')
        $mail.MarkReadOnBody = $true
        $mail.FailSave = -not $unsaved
        $mail.Saved = -not $unsaved
        $failed = $false
        try { [void](Invoke-OutlookRequest $app 'read' @{entry_id = 'Inbox'; store_id = 'synthetic-a'}) }
        catch { $failed = $_.Exception.Message.Contains('UNREAD_STATE_UNVERIFIED') }
        Assert-True $failed 'Repair failure was not surfaced'
        if ($unsaved) { Assert-True ($mail.Saves -eq 0) 'Unsaved user edits were persisted' }
    }
}

Invoke-Case 'candidate limits, folder failures and pagination are explicit' {
    $app = New-Fixture
    $result = Invoke-OutlookRequest $app 'search' @{max_candidates = 1}
    Assert-True (-not $result.search_complete_in_outlook_data) 'Candidate limit claimed full coverage'
    Assert-True (@($result.issues | Where-Object { $_.code -eq 'candidate_limit' }).Count -eq 1) 'Missing limit reason'
    $first = Invoke-OutlookRequest $app 'search' @{limit = 1}
    $second = Invoke-OutlookRequest $app 'search' @{limit = 1; offset = $first.next_offset}
    Assert-True ($first.messages.Count -eq 1 -and $second.messages.Count -eq 1) 'Pagination failed'
    Assert-True ($first.messages[0].store_id -ne $second.messages[0].store_id) 'Store-aware stable ordering failed'
    $app.Session.Stores.Item(2).FailRoot = $true
    $result = Invoke-OutlookRequest $app 'search' @{}
    Assert-True (-not $result.search_complete_in_outlook_data -and $result.messages.Count -eq 5) 'Inaccessible store was hidden'
}

Invoke-Case 'bad filters and folder discovery limits cannot mean no mail exists' {
    $app = New-Fixture
    $app.Session.Stores.Item(1).Root.Folders.Item(1).Items.FailFilter = $true
    $result = Invoke-OutlookRequest $app 'search' @{subject = 'tracker'}
    Assert-True (-not $result.search_complete_in_outlook_data) 'Filter failure was hidden'
    $probe = Invoke-OutlookRequest $app 'probe' @{max_folders = 1}
    Assert-True (-not $probe.discovery_complete -and $probe.issues.Count -gt 0) 'Discovery limit was hidden'
}

Invoke-Case 'invalid IDs and timezone-free dates are rejected' {
    $app = New-Fixture
    $failed = $false
    try { [void](Invoke-OutlookRequest $app 'read' @{entry_id = 'Inbox'}) } catch { $failed = $true }
    Assert-True $failed 'Read accepted a missing store ID'
    $failed = $false
    try { [void](Invoke-OutlookRequest $app 'search' @{received_after = '2026-10-16'}) } catch { $failed = $true }
    Assert-True $failed 'Ambiguous date was accepted'
}

Invoke-Case 'Exchange SMTP matching and address lookup failures' {
    $app = New-Fixture
    $mail = $app.Session.GetItemFromID('Inbox', 'synthetic-a')
    $mail.SenderEmailType = 'EX'
    $mail.SenderEmailAddress = '/synthetic/legacy-address'
    $mail.Sender = New-Object FakeAddress
    $result = Invoke-OutlookRequest $app 'search' @{sender = 'sender@example.invalid'}
    Assert-True ($result.messages.Count -eq 10) 'Exchange SMTP address was not matched'
    $mail.Sender.Fail = $true
    $result = Invoke-OutlookRequest $app 'search' @{sender = 'sender@example.invalid'}
    Assert-True (-not $result.search_complete_in_outlook_data -and $result.messages.Count -eq 9) 'Address failure claimed full coverage'
    $mail.Sender.Fail = $false
    $mail.Sender.NoAddress = $true
    $result = Invoke-OutlookRequest $app 'search' @{sender = 'sender@example.invalid'}
    Assert-True (-not $result.search_complete_in_outlook_data -and $result.messages.Count -eq 9) 'Missing SMTP address claimed full coverage'
}

Invoke-Case 'nonmatching body reads still repair unread state; failed search repair stops' {
    $app = New-Fixture
    $mail = $app.Session.GetItemFromID('Inbox', 'synthetic-a')
    $mail.MarkReadOnBody = $true
    $result = Invoke-OutlookRequest $app 'search' @{body = 'absent phrase'; engine = 'scan'}
    Assert-True ($mail.UnRead -and $mail.Saves -eq 1 -and $result.messages.Count -eq 0) 'Nonmatching body read lost unread state'
    Assert-True ($result.unread_restorations -eq 1) 'Repair on excluded candidate was not reported'
    $mail.FailSave = $true
    $failed = $false
    try { [void](Invoke-OutlookRequest $app 'search' @{body = 'needle'}) }
    catch { $failed = $_.Exception.Message.Contains('UNREAD_STATE_UNVERIFIED') }
    Assert-True $failed 'Search continued after failed unread repair'
}

Invoke-Case 'unknown unread state prevents body access and saves' {
    $app = New-Fixture
    $mail = $app.Session.GetItemFromID('Inbox', 'synthetic-a')
    $mail.UnRead = $null
    $mail.ThrowOnBody = $true
    $failed = $false
    try { [void](Invoke-OutlookRequest $app 'read' @{entry_id = 'Inbox'; store_id = 'synthetic-a'}) }
    catch { $failed = $_.Exception.Message.Contains('unread status') }
    Assert-True ($failed -and $mail.Saves -eq 0) 'Unknown unread state was silently treated as read'
}

Invoke-Case 'participant search includes received, sent and copied correspondence' {
    $app = New-Fixture
    $incoming = $app.Session.GetItemFromID('Inbox', 'synthetic-a')
    $incoming.SenderEmailAddress = 'contact@example.invalid'
    $outgoing = $app.Session.GetItemFromID('Project', 'synthetic-a')
    $outgoing.Recipients.Values.Add((New-Object FakeRecipient))
    $copied = $app.Session.GetItemFromID('Junk Email', 'synthetic-b')
    $cc = New-Object FakeRecipient
    $cc.Type = 2
    $copied.Recipients.Values.Add($cc)
    $result = Invoke-OutlookRequest $app 'search' @{participant = 'contact@example.invalid'}
    Assert-True ($result.messages.Count -eq 3 -and $result.search_complete_in_outlook_data) 'Contact correspondence was missed'
    $result = Invoke-OutlookRequest $app 'search' @{participant = 'contact@example.invalid'; subject = 'tracker Inbox'}
    Assert-True ($result.messages.Count -eq 1) 'Participant did not combine with subject using AND'
    $read = Invoke-OutlookRequest $app 'read' @{entry_id = 'Project'; store_id = 'synthetic-a'}
    Assert-True ($read.message.recipients.Count -eq 1 -and $read.message.recipients[0].email -eq 'contact@example.invalid') 'Read lost recipient context'
    Assert-True ($outgoing.UnRead -and $outgoing.Saves -eq 0) 'Recipient lookup changed normal read state'
}

Invoke-Case 'Exchange recipient lookup and failures retain honest coverage' {
    $app = New-Fixture
    $mail = $app.Session.GetItemFromID('Project', 'synthetic-a')
    $recipient = New-Object FakeRecipient
    $recipient.Address = '/synthetic/exchange/contact'
    $mail.Recipients.Values.Add($recipient)
    $result = Invoke-OutlookRequest $app 'search' @{participant = 'contact@example.invalid'}
    Assert-True ($result.messages.Count -eq 1 -and $result.search_complete_in_outlook_data) 'Exchange recipient SMTP matching failed'
    $recipient.PropertyAccessor.Fail = $true
    $result = Invoke-OutlookRequest $app 'search' @{participant = 'Project Contact'}
    Assert-True ($result.messages.Count -eq 1 -and -not $result.search_complete_in_outlook_data) 'Display-name match or failure visibility was lost'
    $mail.Recipients.Fail = $true
    $result = Invoke-OutlookRequest $app 'search' @{participant = 'contact@example.invalid'}
    Assert-True (-not $result.search_complete_in_outlook_data) 'Unavailable recipients claimed full coverage'
}

Invoke-Case 'participant lookup preserves the unread repair guarantee' {
    $app = New-Fixture
    $mail = $app.Session.GetItemFromID('Project', 'synthetic-a')
    $mail.Recipients.Values.Add((New-Object FakeRecipient))
    $mail.MarkReadOnRecipients = $true
    $result = Invoke-OutlookRequest $app 'search' @{participant = 'contact@example.invalid'}
    Assert-True ($result.messages.Count -eq 1 -and $mail.UnRead -and $mail.Saves -eq 1) 'Recipient lookup lost unread state'
    Assert-True ($result.unread_restorations -eq 1 -and $result.messages[0].unread_restored) 'Recipient repair was not reported'
}

Invoke-Case 'native body filter prunes nonmatches without opening their bodies' {
    $app = New-Fixture
    $mail = $app.Session.GetItemFromID('Inbox', 'synthetic-a')
    $mail.Text = "long text with O'Brien near the end"
    $native = Invoke-OutlookRequest $app 'search' @{body = "O'Brien"}
    Assert-True ($native.messages.Count -eq 1 -and $native.candidates_checked -eq 1) 'Table did not prune irrelevant mail'
    Assert-True ($native.body_reads -eq 1 -and $native.engine.scan_folders -eq 0) 'Native search fetched unrelated bodies'
    $other = $app.Session.GetItemFromID('Project', 'synthetic-a')
    Assert-True ($other.BodyReads -eq 0) 'Nonmatching body was opened'
    $scan = Invoke-OutlookRequest $app 'search' @{body = "O'Brien"; engine = 'scan'}
    Assert-True ($scan.messages.Count -eq 1 -and $scan.body_reads -eq 10) 'Reference scanner did not examine the available bodies'
    Assert-True ($native.messages[0].entry_id -eq $scan.messages[0].entry_id) 'Native and reference results differ'
}

Invoke-Case 'bundled terms and contacts form a union, retaining sent and wildcard matches' {
    $app = New-Fixture
    $app.Session.GetItemFromID('Inbox', 'synthetic-a').Text = 'first project'
    $app.Session.GetItemFromID('nested-mail', 'synthetic-b').Text = 'second project'
    $sent = $app.Session.GetItemFromID('Project', 'synthetic-a')
    $sent.Recipients.Values.Add((New-Object FakeRecipient))
    $options = @{terms = @('first project', 'second project'); contacts = @('contact@example.invalid')}
    $result = Invoke-OutlookRequest $app 'search' $options
    Assert-True ($result.messages.Count -eq 3 -and $result.search_complete_in_outlook_data) 'Bundled query lost term or recipient matches'
    Assert-True ($result.body_reads -eq 9) 'Each candidate body should be read at most once and contacts need no search body'
    $result = Invoke-OutlookRequest $app 'search' @{terms = @('first project', 'second project')}
    Assert-True ($result.messages.Count -eq 2 -and $result.candidates_checked -eq 2) 'Term-only OR query was not pruned'
    $sent.Text = 'literal 100%_value'
    $result = Invoke-OutlookRequest $app 'search' @{terms = @('100%_', 'absent')}
    Assert-True ($result.messages.Count -eq 1) 'Wildcard characters changed literal substring semantics'
    $result = Invoke-OutlookRequest $app 'search' @{terms = @('first project', 'second project'); subject = 'Inbox'}
    Assert-True ($result.messages.Count -eq 1) 'Existing subject constraint did not AND with the union'
}

Invoke-Case 'provider rejection falls back explicitly without dropping results' {
    $app = New-Fixture
    $app.Session.Stores.Item(1).Root.Folders.Item(1).FailTable = $true
    $result = Invoke-OutlookRequest $app 'search' @{body = 'needle'}
    Assert-True ($result.messages.Count -eq 10 -and $result.search_complete_in_outlook_data) 'Successful fallback lost coverage'
    Assert-True ($result.engine.scan_folders -eq 1 -and $result.engine.fallbacks.Count -eq 1) 'Fallback route was not visible'
}

Invoke-Case 'session resumes candidate traversal and pages results without rescanning' {
    $app = New-Fixture
    $runtime = New-OutlookRuntime
    $result = Invoke-OutlookRequest $app 'search' @{body = 'needle'; max_candidates = 3; limit = 2} $runtime
    Assert-True ($result.continuation -and $result.messages.Count -eq 0 -and -not $result.search_complete_in_outlook_data) 'Partial session search needs a continuation, not a premature page'
    $received = New-Object 'System.Collections.Generic.List[object]'
    $calls = 0
    do {
        $result = Invoke-OutlookRequest $app 'search' @{continuation = $result.continuation; max_candidates = 3; limit = 2} $runtime
        foreach ($message in $result.messages) { $received.Add($message) }
        $calls++
        Assert-True ($calls -lt 10) 'Continuation failed to make progress'
    } while ($result.continuation)
    Assert-True ($received.Count -eq 10 -and $result.candidates_checked_total -eq 10) 'Resume repeated or skipped candidates'
    Assert-True ($result.search_complete_in_outlook_data -and $result.issues.Count -eq 0) 'A previous chunk limit contaminated completion'
    Assert-True ($runtime.jobs.Count -eq 0) 'Finished query retained its continuation'
    foreach ($store in $app.Session.Stores.Values) {
        Assert-True ($store.Root.Folders.Item(1).TableCalls -eq 1) 'Paging restarted a folder query'
        Assert-True ($store.Root.Folders.Item(1).Items.Messages[0].BodyReads -eq 1) 'Resume reread an inspected body'
    }
}

Invoke-Case 'session caches versioned bodies and preserves live unread state' {
    $app = New-Fixture
    $runtime = New-OutlookRuntime
    [void](Invoke-OutlookRequest $app 'probe' @{} $runtime)
    $search = Invoke-OutlookRequest $app 'search' @{body = 'needle'} $runtime
    Assert-True ($search.folder_discovery_reused -and $search.body_reads -eq 10) 'Session did not reuse folder discovery'
    $options = @{entry_id = 'Inbox'; store_id = 'synthetic-a'; body_chars = 0}
    $mail = $app.Session.GetItemFromID('Inbox', 'synthetic-a')
    $mail.UnRead = $false
    $read = Invoke-OutlookRequest $app 'read' $options $runtime
    Assert-True ($read.body_reads -eq 0 -and $read.body_cache_hits -eq 1) 'Read reopened the cached body'
    Assert-True (-not $read.message.unread_before -and -not $mail.UnRead -and $mail.Saves -eq 0) 'Cache replaced live unread state'
    $mail.Text = 'updated body'; $mail.LastModificationTime = $mail.LastModificationTime.AddSeconds(1)
    $read = Invoke-OutlookRequest $app 'read' $options $runtime
    Assert-True ($read.message.body.text -eq 'updated body' -and $read.body_reads -eq 1) 'Modified body was served from stale cache'
}

Invoke-Case 'continuations reject changed filters and preserve genuine failures' {
    $app = New-Fixture
    $runtime = New-OutlookRuntime
    $app.Session.GetItemFromID('Inbox', 'synthetic-a').ThrowOnBody = $true
    $first = Invoke-OutlookRequest $app 'search' @{body = 'needle'; max_candidates = 1} $runtime
    $failed = $false
    try { [void](Invoke-OutlookRequest $app 'search' @{continuation = $first.continuation; body = 'different'} $runtime) } catch { $failed = $true }
    Assert-True $failed 'Continuation accepted different search semantics'
    $result = Invoke-OutlookRequest $app 'search' @{continuation = $first.continuation} $runtime
    Assert-True (-not $result.search_complete_in_outlook_data -and $result.messages.Count -eq 9) 'Resuming hid a genuine read failure'
    Assert-True (@($result.issues | Where-Object { $_.code -eq 'message_unavailable' }).Count -eq 1) 'Read failure was lost or duplicated'
}

Invoke-Case 'profile changes invalidate continuations and cached text' {
    $app = New-Fixture
    $runtime = New-OutlookRuntime
    $first = Invoke-OutlookRequest $app 'search' @{body = 'needle'; max_candidates = 1} $runtime
    $app.Session.CurrentProfileName = 'Another synthetic profile'
    $failed = $false
    try { [void](Invoke-OutlookRequest $app 'search' @{continuation = $first.continuation} $runtime) } catch { $failed = $true }
    Assert-True ($failed -and $runtime.bodies.Count -eq 0) 'A profile change reused foreign cached data'
}

Invoke-Case 'compact session refs identify the same message across searches and reads' {
    $app = New-Fixture
    $runtime = New-OutlookRuntime
    $native = Invoke-OutlookRequest $app 'search' @{body = 'needle'} $runtime
    $scan = Invoke-OutlookRequest $app 'search' @{body = 'needle'; engine = 'scan'} $runtime
    Assert-True (-not $native.ContainsKey('stores') -and $native.messages[0].PSObject.Properties.Name -notcontains 'store_id') 'Session repeated raw Outlook identifiers'
    Assert-True ($native.messages[0].ref -eq $scan.messages[0].ref) 'A message ref changed between search routes'
    $read = Invoke-OutlookRequest $app 'read' @{ref = $native.messages[0].ref; body_chars = 0} $runtime
    Assert-True ($read.message.ref -eq $native.messages[0].ref -and $read.message.body.text -eq 'needle') 'Compact ref read the wrong message'
    $other = New-OutlookRuntime
    $failed = $false
    try { [void](Invoke-OutlookRequest $app 'read' @{ref = $native.messages[0].ref} $other) } catch { $failed = $true }
    Assert-True $failed 'A ref was accepted outside its originating session'
}

Invoke-Case 'JSON session protocol reuses discovery and ends on close or unread failure' {
    $app = New-Fixture
    $requests = @(
        '{"action":"probe"}'
        '{"action":"search","options":{"terms":["needle"]}}'
        '{"action":"refresh"}'
        '{"action":"probe"}'
        '{"action":"close"}'
        '{"action":"probe"}'
    )
    $reader = New-Object IO.StringReader([string]::Join("`n", $requests))
    $writer = New-Object IO.StringWriter
    Invoke-OutlookSession $app $reader $writer
    $responses = @($writer.ToString().Trim().Split("`n") | ForEach-Object { $_ | ConvertFrom-Json })
    Assert-True ($responses.Count -eq 6 -and $responses[0].ready) 'Session framing or close failed'
    Assert-True $responses[2].folder_discovery_reused 'Session requests did not share state'
    Assert-True (-not $responses[4].folder_discovery_reused) 'Refresh did not discard folder state'
    $mail = $app.Session.GetItemFromID('Inbox', 'synthetic-a')
    $mail.MarkReadOnBody = $true; $mail.FailSave = $true
    $reader = New-Object IO.StringReader("{`"action`":`"read`",`"options`":{`"entry_id`":`"Inbox`",`"store_id`":`"synthetic-a`"}}`n{`"action`":`"probe`"}")
    $writer = New-Object IO.StringWriter
    Invoke-OutlookSession $app $reader $writer
    $responses = @($writer.ToString().Trim().Split("`n") | ForEach-Object { $_ | ConvertFrom-Json })
    Assert-True ($responses.Count -eq 2 -and -not $responses[1].ok -and -not $responses[1].unread_state_verified) 'Session continued after an unread repair failure'
}

Invoke-Case 'cooperative expiry finishes the current recipient list before resuming' {
    $app = New-Fixture
    $runtime = New-OutlookRuntime
    [void](Invoke-OutlookRequest $app 'probe' @{} $runtime)
    $mail = $app.Session.GetItemFromID('Inbox', 'synthetic-a')
    $first = New-Object FakeRecipient
    $first.Address = 'unrelated@example.invalid'
    $last = New-Object FakeRecipient
    $last.Address = 'final-contact@example.invalid'
    $mail.Recipients.Values.Add($first); $mail.Recipients.Values.Add($last)
    $mail.Recipients.DelayMilliseconds = 1100
    $result = Invoke-OutlookRequest $app 'search' @{contacts = @('final-contact@example.invalid'); budget_seconds = 1} $runtime
    Assert-True ($result.continuation -and -not $result.search_complete_in_outlook_data) 'Expiry did not preserve the search cursor'
    $result = Invoke-OutlookRequest $app 'search' @{continuation = $result.continuation} $runtime
    Assert-True ($result.search_complete_in_outlook_data -and $result.messages.Count -eq 1 -and $result.candidates_checked_total -eq 10) 'An unfinished recipient list silently lost a contact match'
}

Write-Host ("All $script:passed Outlook cases passed using synthetic data.")
