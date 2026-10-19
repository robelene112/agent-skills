# Local Outlook in Windows/WSL

This environment-specific skill uses an existing classic Outlook session on the
Windows host. The public repository holds generic instructions, helpers and
synthetic tests. The host, Windows user, profile, stores and mail identifiers are
discovered at runtime. Do not put actual mail or account configuration here.

On 2026-10-19 the user confirmed the installed helper's probe, a date-bounded
unread search, and a full-body read of an existing unread message. The message
remained unread without a repair, and no issues were reported. See
[usage and evidence](../../skills/outlook-local/references/usage.md).

## Activate on the laptop

Run the shared setup/update script inside WSL. It recognizes WSL and installs
the Outlook skill alongside the shared personal and Matt Pocock skills:

```bash
curl -fsSL https://raw.githubusercontent.com/robelene112/agent-skills/main/setup.py | python3 -
```

With classic Outlook open, test the local connection separately:

```bash
python3 ~/.agents/skills/outlook-local/scripts/outlook-local.py probe
```

The installer preserves existing configuration and stops on skill conflicts.
It also configures Claude Code when `~/.claude/` already exists or `--claude`
is supplied. Start a new agent session to load the global instructions. The
setup adds a Windows/WSL startup instruction that loads the Outlook skill at
the start of each agent session. Setup itself does not start Outlook or read mail.

## Proactive use during sessions

During active agent sessions, proactively read new mail and surface relevant
actions, deadlines or urgency. Before project work, gather virtually all relevant
mail about the project and contact persons, including read and sent messages and
older correspondence. Use the [context workflow](../../skills/outlook-local/references/proactive-context.md)
for search coverage, reuse and the local check cursor. Recipients as well as
senders can be searched with `--participant`, so sent mail is included.

This permission applies to reading and the existing unread repair only. There is
no periodic work outside an active agent session. The general recent-mail cursor
does not impose a recent-date cutoff on project context.

Keep this Windows/WSL capability off the VPS skill installation. The VPS can
maintain its source, but cannot use the local Windows Outlook session through
this helper. There is no remote bridge, scheduled export or daemon.

Defaults are all attached mailboxes and accessible mail folders, including
Deleted Items and Junk. Read/search only, with the user's authorized exception
to restore a message that was unread before the helper read it. Do not assume
an online profile is a fully synchronized historical mailbox.
