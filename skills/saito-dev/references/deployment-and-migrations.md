# Deployment and migrations

Read this for Saito deployment, schema/accounting changes, live-node diagnosis
or recovery. The project's operations guide identifies the actual publisher,
commands, data paths and verification gates.

## Work from observed state

Establish the writable source, deployed checkout, service user and working
directory, bind address, data paths and prepared release/recovery scripts. Check
current state before acting on dated handoffs. A public hostname can refer to a
local service; resolve topology from evidence.

Preserve unrelated source changes and obligations accepted by the current
system. Reconcile source/deployed drift before replacing files. Keep canonical
scripts in tracked project tooling; temporary execution copies should have a
retained source and a verifiable version.

## Rehearse data changes

Use the observed schema and representative current data as migration input,
including installations missing newer tables or columns. Rehearse on a private,
consistent copy and verify identities, counts, typed values and migration
re-entry. Rehearse early when schema or accounting compatibility gates delivery.

Use bounded or streaming comparisons for large signed-payload tables and keep
integer precision. A small fixture cannot establish representative data
compatibility. Diagnose copy or tooling failures without experimenting on the
live database. Capture compact counts and digests while retaining private
records in their appropriate protected locations.

## Check the publisher's failure paths

Review the actual changed publisher rather than rebuilding an unrelated release
system. Where relevant, establish:

- Artifact permissions allow the installing account to read the release.
- Preflight failure preserves a healthy service; expected status-check exits
  do not accidentally enter a global failure trap.
- Release identifiers and retry paths coexist with retained rollback artifacts.
- Readiness bounds account for node startup and bundle warm-up.
- Code rollback remains compatible with the current schema, issuer and outstanding
  obligations. Database recovery is a separate decision requiring reconciliation.
- Backup expiry has an enabled, verified execution mechanism when retention is
  part of the release contract.

Separate process-active, HTTP-ready, wallet-ready and chain-synchronization
observations. Follow the project's bounded readiness checks before browser
verification. Capture stage/status evidence after a failure and diagnose it
before retrying. A subsequent pass leaves an unexplained failure unexplained.

Use existing session authorization. Identify the concrete missing authorization
when an operation genuinely falls outside the request, rather than asking the
user to approve work already agreed.
