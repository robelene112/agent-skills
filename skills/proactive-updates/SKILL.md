---
name: proactive-updates
description: Synchronize the shared skills source at session startup and proactively check relevant Git repositories, tools, container images, dependencies, and OS packages during software or environment work. Applies across David's machines.
---

# Proactive Updates

## Rule 4: watch for useful maintenance

Treat maintenance awareness as part of normal work across environments. When
the task involves software or an environment, look for worthwhile updates to
the components involved: Git repositories, Docker images, agent tooling such as
Codex, project dependencies, runtimes and operating-system packages. At session
startup, synchronize the shared skills source as described below.

## Synchronize Git repositories

At the start of a session, locate the shared skills source checkout through the
installed skill links or machine configuration, when present. Check it before
beginning work, and read any updated instructions before continuing. Also check
each task-related repository before starting work there. Reuse checks within the
session; keep this targeted to the shared skills source and repositories in use.

For this shared source, use `python3 <source-checkout>/setup.py` when available,
after checking for concurrent work. It fetches a qualifying fast-forward and
reconciles the installed skill links and managed global instructions, including
new or removed upstream skills. It remembers the machine profile and preserves
local configuration outside its managed block. A conflict stops the operation;
report it rather than bypassing it with `--offline`. Read updated instructions
before continuing. The script replaces a plain Git pull for this source only.

Fetch from the repository's configured upstream remote and inspect the branch,
working tree and ahead/behind state. Automatically run `git pull --ff-only`
when the current branch has the expected upstream, is behind it, has no local
commits, and the checkout is clean, including untracked files. Confirm that no
other agent or job is working in that checkout. Respect intentional revision
pins and detached checkouts. These qualifying pulls require no further approval.

If the checkout has local changes or commits, divergent history, an unexpected
upstream or concurrent work, report the blocker and leave the checkout intact.
Do not automatically stash, reset, rebase, merge or switch branches to make an
update possible. Report a failed fetch or pull without claiming the repository
is up to date.

For checkouts read directly by a running application, including bind mounts and
hot reload, follow the project's update or deployment procedure before pulling.
A fast-forward only checks Git history; it does not establish runtime safety or
authorize a deployment.

## Check with evidence

Identify the machine, actual installed or running version, installation method,
release channel and project pins. Use the platform's package manager, registry
or official release source for targeted availability checks. An adjacent source
checkout does not establish what is running.

Do inexpensive checks when first working with a relevant component in a
session, and follow concrete update signals encountered during the task.
Reuse recent findings and existing maintenance reports. Expand the investigation
when a finding warrants it or the user requests an audit.

Verify a candidate against official current sources before saying an update is
available. Distinguish stable releases from prereleases and check compatibility
with the actual environment. State when package metadata is stale or availability
could not be verified.

For containers, compare the relevant tag or release and digest: the same tag can
point to a newer image, while a pinned digest intentionally fixes a version.
For tools such as Codex, identify the installation method and matching release
channel before proposing an update command. For OS packages, use the current
platform's package manager rather than assuming every machine uses the same one.

## Turn findings into useful work

Prioritize security fixes, support status, reliability and improvements relevant
to the current task. Report meaningful findings briefly: component, current and
candidate version, concrete benefit, expected impact and recommended next action.
Avoid repeating a known or deliberately deferred finding without new evidence.

Apply updates that fall within the user's request or existing authorization,
using the project's supported checks and update procedure. Existing authorized
automatic updaters can continue their work. For a finding outside that scope,
present the concrete proposal; ask in ordinary chat when a decision is needed.
The Git synchronization policy above authorizes qualifying fast-forward pulls.
Other proactive checks do not establish blanket authorization to upgrade systems
or restart services.
