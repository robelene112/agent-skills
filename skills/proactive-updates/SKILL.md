---
name: proactive-updates
description: Proactively notice and verify useful updates to tools, container images, dependencies, and OS packages during software or environment work. Applies across David's machines, including when maintenance was not explicitly requested.
---

# Proactive Updates

## Rule 4: watch for useful maintenance

Treat maintenance awareness as part of normal work across environments. When
the task involves software or an environment, look for worthwhile updates to
the components involved: Docker images, agent tooling such as Codex, project
dependencies, runtimes and operating-system packages.

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
The request to watch for updates establishes proactive checking and reporting,
not blanket authorization to upgrade systems or restart services.
