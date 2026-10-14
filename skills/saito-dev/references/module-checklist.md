# Saito Module Review Checklist

Use the parts relevant to the change.

## Lifecycle and integration

- Module name and request discriminators are stable and unambiguous.
- Module registration and configuration include the intended browser/full-node contexts.
- Initialization, web routes, services, peer requests, and transaction callbacks follow current local examples.
- Callback filters avoid unnecessary processing.

## Transaction boundary

- Payload compatibility is explicit; use a schema version when the supported evolution requires it.
- Required fields, lengths, numeric ranges, and enumerations are validated.
- Signer identity comes from the signed transaction.
- Authorization is checked on receipt, not inferred from UI state.
- Duplicate and reordered delivery are safe.
- Replay rules, timestamps, nonces, and expiration are defined where needed.
- Invalid transactions fail closed without taking down the module.

## Data and privacy

- The on-chain/public payload contains no secrets or unnecessary personal data.
- Display aliases are distinct from cryptographic identity.
- Local indexes can be rebuilt or their backup requirements are documented.
- Retention, pruning, archive dependency, and schema migration are explicit.

## User experience

- Wallet-unavailable, signing-rejected, propagation-pending, and confirmation states are visible.
- Optimistic state reconciles with authoritative state.
- Explorer links use the transaction or block identifiers supported by the deployment.
- Older clients receive a compatible response or a clear upgrade path.

## Competitive applications

- The signed payload commits to the ruleset/version and relevant evidence.
- Server verification does not accept score or outcome claims on signature alone.
- Deterministic replays include enough information to reproduce the result.
- Leaderboard uniqueness and rename behavior are defined by public key, not display text.
