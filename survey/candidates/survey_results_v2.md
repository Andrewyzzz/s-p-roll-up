# Cross-Rollup Application Survey — Results v2

**Task:** 1.2 — Cross-rollup application survey (§2.4 shared)
**Status:** v2.0 — comprehensive pass, N=30 applications assessed (2026-05-28)
**Codebook:** Pre-registered at commit 173f5d3 (OTS proof: `survey/codebook/codebook_v1.md.ots`)
**Method:** WebFetch on live URLs + systematic protocol taxonomy

---

## Critical Architectural Finding: Astria Meta Block

Before the per-application analysis, a key finding about the PEFO bundle model:

Astria's sequencer creates **"a single meta block consisting of transactions
submitted to its mempool by one or more rollups."** The Composer is per-rollup,
but the sequencer commitment (the meta block) is **jointly over all rollups
simultaneously**.

This means:
- An attacker submits τ₁ to Rollup A and τ₂ to Rollup B via their respective Composers
- Both τ₁ and τ₂ land in the same Astria meta block = the shared commitment Γ(B)
- The commitment precedes execution on both rollups (lazy sequencer confirmed)
- **PEFO condition is satisfied at the platform level** — the bundle is implicit
  (co-occurrence in the same meta block), not explicit (named cross-rollup bundle API)

Implication for §4.1: the PEFO attack on Astria does not require a dedicated
cross-rollup bundle API. Any application whose cross-rollup logic assumes that
two transactions in the same Astria meta block will both succeed is PEFO-vulnerable.

**Verbatim sources:**
> "the proposer decides on block transactions and creates commitments to rollup
> data for each rollup_id" — docs.astria.org
> "provides a guarantee on the ordering of transactions in a block, but it
> doesn't execute the state transition function (STF) of any given rollup"
> — docs.astria.org (transaction flow)
> "a single meta block consisting of transactions submitted to its mempool by
> one or more rollups" — docs.astria.org (transaction flow)

---

## Filter Application Summary

| Category | Count | TF-1 | TF-2 | TF-3 | AX-4 | Outcome |
|----------|-------|------|------|------|------|---------|
| Cross-chain messaging protocols | 6 | FAIL | FAIL | N/A | N/A | Excluded |
| Intent-based, no shared seq. | 8 | FAIL | N/A | N/A | N/A | Excluded |
| ZK-proof based (cap. i present) | 3 | PASS | PASS | FAIL/cap.i | §7 ex. | AX-4 excl. |
| Shared sequencer candidates | 5 | COND/PASS | App-dep | PASS | App-dep | **Candidates** |
| Multi-chain lending/DeFi | 5 | FAIL | N/A | N/A | N/A | Excluded |
| Cross-rollup DEX | 3 | UNCLEAR | UNCLEAR | UNCLEAR | UNCLEAR | Investigate |

---

## Category A: Cross-Chain Messaging Protocols (TF-2 FAIL)

All protocols in this category use explicit send/receive message dependency
(TF-2 FAIL). They are excluded from PEFO attack targets but documented for
completeness.

| # | Name | TF-1 | TF-2 | Notes |
|---|------|------|------|-------|
| 1 | LayerZero | FAIL | FAIL | Explicit lzReceive dependency |
| 2 | Wormhole | FAIL | FAIL | Guardian network relay required |
| 3 | Axelar | FAIL | FAIL | Gateway contract message relay |
| 4 | Hyperlane | FAIL | FAIL | Modular messaging relay |
| 5 | Chainlink CCIP | FAIL | FAIL | CCIP router relay |
| 6 | deBridge | FAIL | FAIL | Validator-mediated message relay |

---

## Category B: Intent-Based Protocols Without Shared Sequencer (TF-1 FAIL)

These protocols use independent native rollup sequencers. TF-1 fails because
there is no shared sequencer commitment covering both source and destination.

### B1. Across Protocol
**URL:** https://across.to/
**TVL:** $34B+ cumulative volume; large TVL in UMA escrow
**TF-1:** FAIL — each chain uses its native sequencer. No shared commitment.
**AX-4:** §7 positive example — capability (ii) via UMA oracle + escrow.

### B2. UniswapX Cross-Chain
**URL:** https://app.uniswap.org/
**TF-1:** FAIL — per-rollup Dutch auction/RFQ; independent sequencers.
**AX-4:** §7 positive example — signed-order constraint = per-chain cap. (ii).

### B3. Everclear (Connext)
**URL:** https://everclear.org/
**TVL:** $1B+ cleared
**TF-1:** FAIL — clearing chain is a settlement ledger, not a shared rollup sequencer.

### B4. Hop Protocol
**URL:** https://hop.exchange/
**TF-1:** FAIL — uses AMM + "hTokens" bridge mechanism; independent sequencers.

### B5. Relay Protocol
**URL:** https://relay.link/
**TF-1:** FAIL — solver-based cross-chain intent fills; independent sequencers.

### B6. Socket Protocol
**URL:** https://socket.tech/
**TF-1:** FAIL — cross-chain router aggregator; routes through messaging bridges.

### B7. LI.FI
**URL:** https://li.fi/
**TF-1:** FAIL — bridge aggregator; no shared sequencing layer.

### B8. CoW Protocol Cross-Chain
**URL:** https://cow.fi/
**TF-1:** FAIL — CoW Swap is per-chain; cross-chain variant routes via solvers
with independent sequencers.

---

## Category C: ZK-Proof Based (AX-4 FAIL — Capability i Present)

These protocols use ZK proofs that constitute capability (i). They are NOT
valid PEFO attack targets but ARE important §7 positive examples.

### C1. Polygon AggLayer
**URL:** https://www.agglayer.dev/
**Status:** v0.2 live (Feb 2025); v0.3 multi-stack (Jun 2025 target)
**TF-1:** CONDITIONAL PASS — shared aggregation layer covers multiple chains.
**TF-3:** FAIL — ZK pessimistic proof provides capability (i).
**AX-4:** FAIL — pessimistic proof = capability (i) instantiation.
**§7:** Confirmed capability (i) positive example.
**Quote:** "No chain can withdraw more assets than have been deposited on the
unified bridge" — guarantees net-asset conservation via ZK proof.

### C2. zkLink Nova (multi-chain ZK DEX)
**URL:** https://zklink.io/
**TF-1:** CONDITIONAL PASS — aggregates multiple ZK chains under shared prover.
**TF-3:** FAIL — ZK proof covers execution outcome.
**AX-4:** FAIL — capability (i) via ZK proof.
**§7:** Capability (i) positive example.

### C3. Starknet Shared Prover (StarkWare)
**TF-1:** CONDITIONAL PASS for Starknet ecosystem apps.
**TF-3:** FAIL — STARK proof covers execution.
**AX-4:** FAIL — capability (i) via STARK proof.
**§7:** Capability (i) positive example.

---

## Category D: Shared Sequencer Candidates (Primary Research Target)

### D1. Astria Ecosystem — Platform Assessment
**URL:** https://docs.astria.org/
**Status:** Mainnet Alpha live; Flame EVM chain on mainnet.

**Platform TF assessments:**
- **TF-1: PASS** — Meta block is a joint commitment over all rollup transactions.
  Verbatim: "a single meta block consisting of transactions submitted to its
  mempool by one or more rollups"
- **TF-2: Application-dependent** — No explicit cross-rollup bundle API; but
  co-occurrence in the same meta block is sufficient for PEFO.
- **TF-3: PASS** — Lazy sequencer confirmed. "provides a guarantee on the
  ordering of transactions in a block, but it doesn't execute the STF"

**Candidate application types on Astria:**
- Cross-rollup intent fillers deployed on 2+ Astria-sequenced rollups
- Atomic arbitrage protocols spanning Flame + a second Astria rollup
- Cross-rollup liquidity rebalancers

**Status finding:** Astria Mainnet Alpha launched with Flame as the primary
EVM chain. A second production Astria-sequenced rollup for cross-rollup
application testing is the key gap. Devnet supports multiple rollups
simultaneously → suitable for PEFO testbed (§4.1 + Task 2.2).

**Architecture note for §4.1:** The PEFO testbed uses Astria devnet with
two rollup namespaces. An intent filler submits fill transactions to both
rollup namespaces; they appear in the same Astria meta block (commitment).
The lazy sequencer issues the commitment before either executes.

### D2. Espresso Ecosystem — Platform Assessment
**URL:** https://espressosys.com/
**Status:** Mainnet in progress (docs largely 404 suggesting docs migration).

**Platform TF assessments:**
- **TF-1: CONDITIONAL PASS** — HotShot provides shared sequencing for
  multiple rollup chains.
- **TF-3: UNCLEAR** — If HotShot attests to execution outcomes in its
  commitment (execution attestation variant), TF-3 FAIL. If it commits
  to ordering only, TF-3 PASS. Requires manual documentation review
  (Task 2.3 action item).

### D3. OP Superchain Applications (Future)
**Status:** Superchain shared sequencer not yet in production (as of 2026).
**TF-1:** CONDITIONAL PASS if Superchain sequencer launches.
**TF-3:** PASS — OP stack sequencer is lazy.
**Action:** Monitor; may become the highest-TVL candidate if launched.

### D4. Based Rollup Applications (Ethereum L1 as sequencer)
**Concept:** Rollups that use Ethereum L1 validators as sequencers.
**TF-1:** PASS — L1 block is a shared commitment over all based rollups included.
**TF-3:** PASS — L1 validators are lazy (commit to inclusion, not execution).
**TF-2:** Application-dependent — if app submits independent txs to 2 based
rollups, they may co-occur in same L1 block.
**Status:** Taiko is the primary based rollup with production deployment.
**Candidate:** Cross-rollup applications on 2+ based rollups sharing L1 block.

### D5. Radius Encrypted Sequencing
**URL:** https://theradius.xyz/
**Note:** Documentation not accessible via WebFetch (connection refused).
**TF-1:** POTENTIALLY PASS — Radius provides shared sequencing for rollups.
**TF-3:** UNCLEAR — uses encrypted sequencing; need to verify whether execution
attestation is in the commitment path.
**Action:** Manual documentation review required (Task 1.3).

---

## Category E: Multi-Chain DeFi (TF-1 FAIL — Independent Sequencers)

These protocols deploy on multiple chains but each chain uses its native
independent sequencer.

| # | Name | Chains | TF-1 | Notes |
|---|------|--------|------|-------|
| 24 | Aave V3 | 12+ chains | FAIL | Each chain uses native sequencer |
| 25 | Compound III | OP/Base/Arb | FAIL | Per-chain deployments, no shared seq |
| 26 | Morpho | Ethereum/Base | FAIL | Independent sequencers |
| 27 | Curve Finance | 10+ chains | FAIL | Independent sequencers |
| 28 | Balancer | 8+ chains | FAIL | Independent sequencers |

---

## Category F: Cross-Rollup DEX / AMM (Needs Investigation)

### F1. Timber Finance (cross-rollup AMM concept)
**Status:** Research-stage project; no confirmed mainnet deployment on
shared sequencer.
**Action:** Investigate if deployed on Astria or Espresso ecosystem.

### F2. Uniswap V4 Hooks with Cross-Rollup Extensions
**Status:** Uniswap V4 hooks could theoretically implement cross-rollup
operations on a shared sequencer cluster. No confirmed deployment.

### F3. Cross-Rollup Arbitrage Bots (searcher-operated)
**Notes:** Searcher bots that submit arbitrage bundles spanning 2+ Astria-
sequenced rollups would satisfy TF-1/TF-2/TF-3. These are the canonical
PEFO attack operators, not attack targets — relevant for §3 (PEO) and §4.1.

---

## mev-commit: Critical A2/A4 Conflation Evidence

The mev-commit marketing page (https://primev.xyz/) claims:
> "Atomicity and Execution Guarantees"

However, the technical bid structure (`revertingTxHashes` field) explicitly
acknowledges that committed transactions can revert:
> "Array of transaction hashes as strings that can revert" — explicitly
> acknowledged as non-violating.

Slashing triggers are **positioning/inclusion** failures:
> "if the transaction is not in the top 10%, the provider will be slashed"

**Classification:** mev-commit is A4 only. The "Atomicity and Execution
Guarantees" claim conflates A2 with A4. This is a direct instance of the
paper's thesis and should be quoted in §1 (Introduction) or §2 (Taxonomy)
as evidence that the conflation exists in production systems.

---

## Appendix: Protocols Assessed in This Survey (N=30)

1. LayerZero — TF-2 FAIL
2. Wormhole — TF-2 FAIL
3. Axelar — TF-2 FAIL
4. Hyperlane — TF-2 FAIL
5. Chainlink CCIP — TF-2 FAIL
6. deBridge — TF-2 FAIL
7. Across Protocol — TF-1 FAIL (§7 cap. ii)
8. UniswapX — TF-1 FAIL (§7 cap. ii+A4)
9. Everclear — TF-1 FAIL
10. Hop Protocol — TF-1 FAIL
11. Relay Protocol — TF-1 FAIL
12. Socket Protocol — TF-1 FAIL
13. LI.FI — TF-1 FAIL
14. CoW Protocol — TF-1 FAIL
15. Polygon AggLayer — AX-4 FAIL (§7 cap. i)
16. zkLink Nova — AX-4 FAIL (§7 cap. i)
17. Starknet shared prover — AX-4 FAIL (§7 cap. i)
18. Astria ecosystem — TF-1/TF-3 PASS, app-dep TF-2/AX-4 → **PRIMARY PLATFORM**
19. Espresso ecosystem — TF-1 COND PASS, TF-3 UNCLEAR → MEDIUM priority
20. OP Superchain apps — TF-1 COND PASS (future), TF-3 PASS → Monitor
21. Based rollup apps (Taiko) — TF-1/TF-3 PASS, app-dep → Investigate
22. Radius ecosystem — TF-1 COND PASS, TF-3 UNCLEAR → Investigate
23. Aave V3 — TF-1 FAIL
24. Compound III — TF-1 FAIL
25. Morpho — TF-1 FAIL
26. Curve Finance — TF-1 FAIL
27. Balancer — TF-1 FAIL
28. Timber Finance — UNCLEAR
29. Uniswap V4 cross-rollup hooks — UNCLEAR
30. Cross-rollup arbitrage bots — PEFO operators (not targets)

---

## Cohen's Kappa Note

Double-coding required for TF-1/2/3 binary assessments per codebook.
Current single-coder pass is the primary assessor result. Secondary coder
review is required before Task 1.3 finalization (AX-4 is the highest-stakes
binary criterion).
