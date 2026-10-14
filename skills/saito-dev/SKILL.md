---
name: saito-dev
description: Develop, review, or diagnose Saito modules and integrations involving signed transactions, wallet identity, callbacks, and persistence. Use with a Saito codebase; verify its APIs against the checked-out version.
---

# Saito Development

Use the checked-out Saito version and the project's maintained entry points as
the authority for APIs and operations. Identify the runtime and trace comparable
modules before proposing code. Keep deployment paths, hostnames, version pins
and release history in the project.

## Establish the boundary

Identify module registration, lifecycle callbacks, build and test tooling, and
whether the change runs in a browser, a server/full node, or a native integration.
Trace the complete path affected by the request: wallet creation/signing,
transport, receipt, validation, persistence and presentation where applicable.
Use the checkout's runtime guards and keep browser dependencies out of server
paths. Native signing and serialization must match the supported protocol.

Separate responsibilities explicitly: the wallet signs intent; receiving code
authorizes and validates it; storage indexes or retains it; the UI displays and
reconciles the result. A signed claim establishes its signer, not its truth.

## Transactions and identity

Use stable module/request discriminators and a payload compatibility strategy.
Validate types, bounds and authorization at the receiving boundary. Establish
how that entry point verifies authenticity before deriving identity from the
transaction signer; a client-supplied key or display alias is not identity proof.

Trace the checkout's confirmation and peer-request semantics. Define duplicate,
reordered and replay behavior where it affects the feature. Use stable transaction
identifiers for deduplication when appropriate. Review what becomes public and
keep private keys, wallet secrets and unnecessary personal data out of payloads,
logs and generated artifacts.

For competitive or value-bearing claims, establish deterministic evidence or
another verification rule independent of the signature. Exercise invalid inputs
and inconsistent claimed outcomes as well as successful submissions.

## Persistence and verification

Distinguish consensus data, archive recovery, query indexes and private state.
Establish retention, pruning, rebuild and backup expectations for data the change
depends on. Verify the actual storage adapter and connection ownership before
changing persistence. Use current schemas rather than assuming a fresh install.

Test the changed boundaries, including signing/serialization compatibility,
duplicate delivery and the relevant runtime branches. For saved browser state,
exercise actual wallet initialization or reload when mocks cannot establish it.
Use the relevant parts of [the module checklist](references/module-checklist.md)
for a review; it is not a requirement to audit every unchanged subsystem.

For deployment, migrations, live-node diagnosis or recovery, read
[deployment and migrations](references/deployment-and-migrations.md) and the
project's operations guide. Apply existing authorization to those operations.
For feature planning or coordination, use the project's development workflow;
this skill supplies Saito context rather than a second implementation process.
