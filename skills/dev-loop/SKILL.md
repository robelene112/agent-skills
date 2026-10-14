---
name: dev-loop
description: Carry an agreed development outcome through Matt Pocock's spec, tickets, implementation, review, and retrospective without repeated phase approvals. Use to start or resume this workflow; handle precise small edits directly.
---

# Development Loop

Complete the agreed outcome. The user's decisions belong in the grill session;
after that, coordinate Matt Pocock's skills without asking the user to start or
approve each phase. A request for only a grill, spec, review or other single
phase keeps that narrower scope.

## Start or resume

Read the project's maintained workflow, inspect the checkout and reuse existing
decisions, specs and tickets. Resume from the first incomplete phase, verifying
recorded status against current code. Follow the project's runtime, tracker,
concurrency and publication conventions. Resolve missing workflow setup during
the grill rather than discovering it between later phases. Record the starting
commit before implementation so review has a fixed comparison point.

## Run the workflow

Use the project's selected skill versions, or the pinned
[Matt Pocock skills](../../vendor/matt-pocock/skills/) otherwise. Read each skill
and its called dependencies when that phase starts, using the host's Skill tool
or the files directly.

1. `grill-with-docs`: settle open product decisions with the user and record the
   agreed scope. Research facts yourself. Reuse an already completed grill.
2. `to-spec`: synthesize the decisions and choose test seams from existing code.
3. `to-tickets`: create verifiable slices and their blocking relationships.
   Decide granularity and check the graph yourself.
4. `implement-spec`: coordinate the entire graph when parallel builders are
   available, permitted and useful. Independent ready tickets can run together;
   overlapping edits or dependencies require sequencing. Otherwise use
   `implement` to finish all agreed work sequentially, without a per-ticket pause.
5. Complete the implementation skill's `code-review`, fix relevant findings and
   rerun affected checks. Supply the recorded starting commit and spec to review;
   include outstanding worktree changes. Avoid repeating an already completed
   review without a new reason.
6. `retro`: report concrete improvements supported by this session. Its proposals
   do not automatically expand implementation into unrelated configuration work.

The user delegates test-seam selection, ticket granularity and routine technical
choices. This replaces the intermediate confirmation prompts in `to-spec` and
`to-tickets`; it also requests the downstream phases as part of this workflow.
Keep the upstream skill files unchanged. Ask again only for a material decision
outside the agreed scope or a blocker that requires the user. Never treat
silence as an answer to such a decision.

For a precise small change, skip unnecessary specs and tickets and proceed to
implementation and verification. Report the completed outcome, evidence and
remaining limitations; follow existing authorization for commits and operations.
For changes to a user-facing flow, read
[product outcomes](references/product-outcomes.md).
