# Local Outlook in Windows/WSL

This environment-specific skill uses an existing classic Outlook session on the
Windows host. The public repository holds generic instructions, helpers and
synthetic tests. The host, Windows user, profile, stores and mail identifiers are
discovered at runtime. Do not put actual mail or account configuration here.

The user reported a working Windows/WSL COM route and verified the host on
2026-10-19. The actual new helper still needs a laptop acceptance run; see
[usage and evidence](../../skills/outlook-local/references/usage.md).

## Activate on the laptop

Use the public `agent-skills` checkout in the laptop's WSL home. Assuming it is
at `~/agent-skills`, link the skill into the agent's personal skills directory:

```bash
mkdir -p ~/.agents/skills
ln -s ~/agent-skills/skills/outlook-local ~/.agents/skills/outlook-local
python3 ~/.agents/skills/outlook-local/scripts/outlook-local.py probe
```

If the destination already exists, inspect it before changing anything. For
Claude Code, the same source can be linked under `~/.claude/skills/`. Start a new
agent session for skill discovery after installation. This skill does not need
to be loaded for every task; its description selects Outlook mail requests.

Keep this Windows/WSL capability off the VPS skill installation. The VPS can
maintain its source, but cannot use the local Windows Outlook session through
this helper. There is no remote bridge, scheduled export or daemon.

Defaults are all attached mailboxes and accessible mail folders, including
Deleted Items and Junk. Read/search only, with the user's authorized exception
to restore a message that was unread before the helper read it. Do not assume
an online profile is a fully synchronized historical mailbox.
