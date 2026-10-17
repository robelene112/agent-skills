---
name: workspace-hygiene
description: Prevent unnecessary files and unsolicited research reports across David's tasks, domains, and machines. Keep working material in the session or temporary storage and project repositories focused on requested deliverables and maintained project knowledge.
---

# Workspace Hygiene

Create a file when it serves the requested outcome or a concrete project need.
Research performed to inform your own work does not automatically need a saved
report or a lengthy explanation to David. Use the findings to do the task; share
only the conclusions, choices or blockers he needs.

Treat a request for advice or suggestions as a discussion. That alone does not
authorize editing files or publishing changes; wait for an implementation
request before making the proposed changes.

For example, when research into what makes an effective logo is requested to
guide logo creation, use the research to produce logo candidates for David to
choose from. The candidates and chosen logo are the deliverables. The literature
review is working material, not an automatic report or permanent project record.

## Working material stays temporary

Keep exploratory notes and intermediate findings in the session by default.
When files are needed for a tool, experiment or download, use a task-specific
directory in the platform's temporary storage outside the project checkout.
Follow environment storage rules for sizeable artifacts. Reuse an established
external cache when appropriate.

Do not create project-local scratch folders, research reports, plans, summaries
or handoffs solely to organize your own work. Adding them to `.gitignore` does
not make them necessary or resolve the clutter.

## Keep useful project files intentional

Create source files, tests, configuration and assets required by the task without
asking for permission for each file. Add permanent documentation when David
requests it, an explicitly requested workflow or maintained project instructions
require it, or it preserves project knowledge useful to other agents continuing
the project. Keep concrete project facts, constraints, decisions and essential
reasons in the relevant maintained reference. General background research and
"might be useful someday" are insufficient reasons to retain a research report.
Follow the existing structure and update existing documentation where possible.
Create a new reference only when the knowledge has a clear project use and no
appropriate maintained location exists. Preserve the necessary conclusion and
an essential source link when useful, rather than the whole research trail.

Requested workflow outputs such as specs and ADRs remain valid deliverables.
A generic skill template suggesting extra reports or notes is not by itself a
request to create them. Apply this personal rule to such optional outputs.

## Finish with only the intended artifacts

Before finishing, compare added files with the initial workspace state and the
requested outcome. In Git repositories, inspect `git status --short` and the diff.
Each added file should be a requested deliverable, needed implementation file,
required workflow output or concise project reference as described above.
Remove your own temporary material once it is no longer needed, and retain the
actual deliverables in their proper locations. Preserve existing user work and
files owned by other tasks or agents. This rule does not request a bulk cleanup
of existing files.
