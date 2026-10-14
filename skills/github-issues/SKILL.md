---
name: github-issues
description: Use GitHub Issues as David's development tracker when preparing, reading, organizing, or resolving software specs and tickets. Applies across projects and machines.
---

# GitHub Issues

## Rule 2: GitHub is the development tracker

Create development tickets as GitHub issues in the relevant project's repository.
When a workflow publishes a spec to its tracker, publish a GitHub issue as well.
Local research, ADRs and detailed design documents can support an issue; they
do not replace it as the tracker for newly created work.

Identify the target repository from project configuration and the current Git
remote. Use the authenticated `gh` CLI or an available GitHub tool. Resolve the
repository from evidence before asking in chat when it remains ambiguous.

Before creating issues, check for existing issues for the same work. Include the
agreed behavior, acceptance criteria, parent spec and genuine blockers. Create
blockers first; use GitHub sub-issues and native blocking relationships where
available, with explicit issue links in the body as a fallback.

For CLI operations, pass the repository explicitly. Use a file with real
newlines via `--body-file` for multiline descriptions or comments. Read issue
bodies, comments and current status before resuming work; close work only when
its agreed completion criteria are satisfied.

This preference requests GitHub publication when the user asks to prepare
tickets. It does not request a bulk migration of historical local plans, create
a ticket for every small edit, or authorize unrelated GitHub actions. Existing
local tickets can retain their records during an already-running effort.

If GitHub access is unavailable, report the concrete blocker and ask in chat
when needed. Do not silently switch to a local issue tracker.
