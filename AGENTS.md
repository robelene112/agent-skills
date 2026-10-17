# Personal agent skills

Own skills live in `skills/`. The pinned Matt Pocock snapshot lives in
`vendor/matt-pocock/skills/`; its revision and hashes are in
`vendor/matt-pocock/source.json`. Preserve upstream files and their license.
Put personal choices in own skills and project choices in the project's rules.

Read `skills/global-communication/SKILL.md` and
`skills/workspace-hygiene/SKILL.md` for every task. For software or
environment work, read `skills/proactive-updates/SKILL.md`. For software
development, read `skills/development-preferences/SKILL.md`; for development
tracking, read `skills/github-issues/SKILL.md`. The global startup template is
in `instructions/global/AGENTS.md`; machine facts belong under `environments/`.

Read `docs/REVIEW.md` before revising `saito-dev` or `odoo-20`. Keep descriptions
specific, load conditional detail through references, and preserve an existing
invocation policy unless the user requests a change. Validate revised skills
and verify upstream hashes after updates.

The repository is a reviewable source checkout. Installing skills, changing
existing project workflows, and publishing a remote are separate tasks.
Local import snapshots under `.local/` are excluded from Git.
