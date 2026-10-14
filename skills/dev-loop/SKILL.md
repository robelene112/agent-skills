---
name: dev-loop
description: Route feature work, refactors, and bug fixes through the project's development workflow and Matt Pocock skills. Use to start or resume development; handle precise small edits directly.
---

# Development Loop

Choose the next useful action from the user's requested outcome and the
project's current evidence. This is a personal entry point into an existing
workflow; the project's rules and selected phase supply its details.

## Start or resume

Read applicable `AGENTS.md` files and their maintained workflow entry points.
Identify the writable checkout, inspect relevant code and the worktree, and
find the spec, tickets or handoff for the requested work. Verify recorded status
against current code. Ask which work to resume only when the evidence leaves
several plausible choices.

Use existing document locations, terminology, runtime commands and acceptance
conventions. Keep machine paths, deployment instructions and project-specific
commit rules in the project. An Odoo-specific entry point remains local to Odoo.

## Choose the phase

Use the project's selected skill version. If it has no selected version, the
pinned [Matt Pocock skills](../../vendor/matt-pocock/skills/) provide these routes:

| Requested work | Route |
| --- | --- |
| Resolve open product or design decisions | `grill-with-docs`; use `wayfinder` for an effort that needs several planning sessions |
| Capture an agreed feature | `to-spec`, followed by `to-tickets` when the work needs separate implementation sessions |
| Build a precise change or ready ticket | `implement`, with relevant `tdd` and `code-review` disciplines |
| Coordinate an agreed spec across parallel builders | `implement-spec`, when the user or project workflow selects parallel implementation |
| Investigate a difficult failure | `diagnosing-bugs` |
| Improve the agent's working environment | `retro` |

Read the selected skill's actual `SKILL.md` and the dependencies it calls before
following it. Use the host's Skill tool when available; otherwise read those
files directly. Start user-invoked phases when requested, and recommend the next
phase when a decision is still needed. Research repository facts yourself.

A precise small fix can proceed directly to implementation and verification.
Reuse decisions already settled in the session. A request to implement agreed
work authorizes its implementation and checks; continue to the requested scope's
completion. `Next inc` requests the next ready unit in the existing plan.

## Parallel work

When parallel implementation is selected, give each builder a bounded outcome,
acceptance criteria and pointers to the shared spec and interfaces. Use isolated
worktrees for independent edits and one coordinator for blockers, integration
and the combined result. Respect project-specific concurrency constraints.
Choose concurrency from actual dependencies and shared-file ownership.

Distinguish parallel implementation from parallel investigation or review; a
project can allow one while keeping ticket implementation sequential.

## Complete the requested work

Run appropriate checks yourself using project tooling. Review the actual changes,
including uncommitted and new files where relevant. Record status from evidence
and report the outcome, verification, remaining limitations and next useful action.
Follow existing session authorization for commits, publication and operations.

For changes to a user-facing flow, read [product outcomes](references/product-outcomes.md).
Keep verified work, product acceptance and deployment status distinct, following
the project's conventions rather than inventing a new completion ritual.
