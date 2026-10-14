# Product outcomes

Use this reference when designing or changing a user-facing flow.

Treat reported friction as evidence about the product outcome, even when an
individual subsystem behaves as designed. Investigate the technical cause
yourself and help the user choose the behavior and tradeoffs that matter.

Preserve the user's work before optional integrations or background activity.
Make routine setup, recovery and progress understandable without requiring
infrastructure knowledge. Handle recoverable failures internally where the
existing authorization and product contract allow it. Ask the user to intervene
when their decision or an external action is actually required.

Keep diagnostics useful to their audience. A product message should explain
what the user can do; operational detail belongs in diagnostics. Record a
deliberately accepted burden in the spec so implementation and review can
evaluate the same decision.
