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

## Approved scenarios

1. **Research to create logos.** David asks for scientific research into what
   makes an effective logo and for logo proposals based on it. Use the research
   to create candidates for him to choose from. Keep the selected logo and
   necessary source assets. Research notes and downloads are temporary; do not
   leave the literature review or a research report in the project directory.

2. **Choose and implement a technical solution.** David asks to compare suitable
   libraries and implement a feature. Keep the code, relevant tests and
   configuration. Do not create a comparison report or save the comparison
   results as a separate document. Record the library choice and its essential
   reason only when that matters for this project's future work, using existing
   documentation. Documenting every library selection is not required.

3. **Investigate and fix a bug.** David asks why an import creates duplicate
   records and asks for a fix. Keep the fix and relevant regression test. Clean
   up one-off investigation scripts and temporary test files after use. If the
   investigation reveals an important project limitation, record it concisely
   in the existing documentation so the next agent can avoid the same problem.

4. **Discover missing project knowledge.** While working, an agent discovers
   the verified command needed to run tests or start the project, but it is
   undocumented. Add the command and necessary execution context to the existing
   development instructions so future agents do not repeat the investigation.
   This is useful maintained project knowledge.

5. **A report is the requested deliverable.** David explicitly asks for a PDF
   report of the research that he can share. Produce the requested PDF in the
   agreed location and preserve it as the deliverable. Follow the requested
   format; clean up temporary downloads and intermediate working files.

6. **Advice only.** David asks for suggestions to make the documentation more
   organized. Investigate enough to offer considered suggestions in the chat.
   Do not create a report in the project directory, write an unsolicited long
   report in the chat, or edit, move or publish project files. Make the proposed
   changes when David requests implementation.
