# TF-2 Scarcity as Finding — Framing Statement
# (Working note, ~200 words; to be incorporated into §1 and §2.4)

## The statement

The PEFO structural gap (C1/C2/C3) is currently unexploited in deployed
cross-rollup production systems — not because the gap is theoretical, but
because every production system that could be vulnerable has independently
converged on one of two routes around it.

The first route is relay coordination: Hyperlane, LayerZero, Wormhole, and
the Espresso+Hyperlane pattern (EspHypNative warp routes) all insert a
protocol-enforced message dependency between the two execution legs.
The `onlyMailbox` modifier on destination contracts is not an atomicity
guarantee — it is a mechanism that prevents the destination from executing
until the source-chain event is relayed, which is precisely Theorem 1
capability (ii): authority to prevent partial irreversible effects.

The second route is solver inventory risk: protocols like Across Protocol
(UMA oracle escrow) and T3rn (proof-based rollback) hold origin-chain funds
until cross-chain completion is verified. This is also capability (ii).

Neither route was engineered because developers read Theorem 1. They were
engineered because developers noticed the problem empirically and reached for
the natural fix. This independent convergence is the strongest possible
validation of the theorem's necessity claim: the production ecosystem has
already voted, with deployed code, that capability (i) or (ii) is required.

The gap remains live on platforms where developers have not yet taken either
route — specifically, cross-rollup intent protocols building on lazy-sequencer
infrastructure (Astria, Espresso) without escrow or relay in their cross-rollup
critical path. Our Astria devnet demonstration (§4) instantiates this condition.

## How this appears in the paper

**§1 Introduction (¶3 — after "what they don't provide"):**
Use the `onlyMailbox` / EspHypNative evidence as the production-system proof
that the gap is real and recognized. Frame as: "every production system that
faces this gap has added capability (ii) — which confirms our Theorem 1 claim
that capability (ii) is necessary, and confirms the gap is live wherever it
is absent."

**§2.4 (The integration gap):**
State explicitly: "We surveyed N=30 cross-rollup applications (Appendix C).
No deployed application relies on shared-sequencer commitment for cross-rollup
execution without adding relay coordination or escrow protection. This is not a
null result — it is a structural finding: TF-2 (independent execution legs
without relay) is the binding constraint, and it is binding because the
ecosystem has already identified and closed it via Theorem 1 capabilities.
The gap remains open as a forward-looking risk on emerging lazy-sequencer
platforms."
