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

public class FakeMail {
    public int Class = 43;
    public string EntryID, Subject, SenderName = "Example sender", SenderEmailAddress = "sender@example.invalid";
    public string SenderEmailType = "SMTP", HTMLBody = "<p>example</p>";
    public DateTime ReceivedTime;
    public object UnRead;
    public bool Saved = true, MarkReadOnBody, ThrowOnBody, FailSave;
    public FakeAddress Sender;
    public int Saves;
    public FakeFolder Parent;
    public string Text = "needle";
    public string Body {
        get {
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
public class FakeFolder {
    public string EntryID, StoreID, FolderPath;
    public int DefaultItemType = 0;
    public FakeFolders Folders = new FakeFolders();
    public FakeItems Items = new FakeItems();
    public FakeFolder(string id, string store, string path) { EntryID = id; StoreID = store; FolderPath = path; }
    public void Add(FakeMail mail) { mail.Parent = this; Items.Messages.Add(mail); }
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
    $result = Invoke-OutlookRequest $app 'search' @{body = 'absent phrase'}
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

Write-Host ("All $script:passed Outlook cases passed using synthetic data.")
