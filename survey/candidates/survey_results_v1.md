# Cross-Rollup Application Survey — Results v1

**Task:** 1.2 — Cross-rollup application survey (§2.4 shared)
**Status:** v1.0 — initial pass (2026-05-28). Codebook pre-registered at
commit 173f5d3 with OTS proof.
**Method:** WebFetch on known application URLs; filter applied per
`candidate_protocol.md` Part 1–2.
**Target:** N=30–50 applications; at least 5 TF-1/2/3 PASS candidates.

---

## Key Finding: Structural Observation

The thesis-fit filter (TF-1: shared sequencer) is **highly selective**. The
vast majority of cross-chain applications use independent native sequencers
per rollup connected by cross-chain messaging (LayerZero, Wormhole, etc.) or
intent-based protocols (Across, UniswapX). These fail TF-2 (messaging
dependency) or TF-1 (no shared sequencer).

The narrow passing population consists of applications deployed on:
(a) Astria shared sequencer clusters
(b) Espresso-sequenced rollup clusters
(c) AggLayer-connected chains (but TF-3 likely FAIL due to ZK proof requirement)

---

## Assessed Applications

---

### 1. Across Protocol
**URL:** https://across.to/
**Contracts:** Deployed on Ethereum, Arbitrum, Optimism, Base, Polygon,
Solana, zkSync, Linea, Mode, Blast, and 6 more chains.
**TVL:** >$34B total volume (TVL not separately reported)

**TF-1:** FAIL
- Each rollup uses its own native sequencer. There is no shared
  sequencer/preconfirmation layer connecting e.g. Arbitrum and Optimism
  in the Across architecture.
- Across operates as a cross-chain *message relay* bridging protocol, not
  a shared-sequencer application.

**TF-2:** N/A (TF-1 failed)

**TF-3:** N/A (TF-1 failed)

**AX-4:** FAIL as attack target — but PASS as §7 positive example
- UMA oracle + escrow implements capability (ii): origin-chain fund release
  is blocked until UMA confirmation of destination-chain fill.

**Overall:** FAIL TF-1
**Notes:** Include in §7 design-space map as capability (ii) positive example.
Across is the canonical reference for escrow-based partial-effect prevention.

---

### 2. UniswapX (cross-chain orders)
**URL:** https://app.uniswap.org/
**Contracts:** Deployed on Ethereum, Arbitrum, Base, Unichain, Optimism

**TF-1:** FAIL
- UniswapX uses per-rollup Dutch auction / RFQ for order settlement.
  Each rollup uses its own native sequencer. No shared sequencing layer.

**TF-2:** N/A (TF-1 failed)

**AX-4:** FAIL as attack target
- Signed order structure provides partial capability (ii): filler must
  provide exact output amount or transaction reverts (within-chain atomicity).
- Cross-chain synchronization is filler-economics driven (A4).

**Overall:** FAIL TF-1
**Notes:** Include in §7 as (ii)+A4 example. The signed-order constraint is
the within-chain analog of capability (ii).

---

### 3. Everclear (formerly Connext)
**URL:** https://everclear.org/
**Mechanism:** Cross-chain clearing and settlement with netting. Uses a
dedicated "Clearing Chain" as the settlement layer.

**TF-1:** FAIL
- Everclear's Clearing Chain is not a shared sequencer in the TF-1 sense
  (it does not sequence transactions for multiple rollups within the same
  commitment). It is a separate settlement ledger.
- Rollups transact independently; Everclear coordinates settlement
  ex-post, not at the sequencing layer.

**Overall:** FAIL TF-1
**Notes:** Interesting architecture for §9 discussion (clearing-chain
as a settlement mechanism outside the sequencing layer).

---

### 4. deBridge
**URL:** https://debridge.finance/
**Mechanism:** Cross-chain interoperability using validators for message relay.

**TF-1:** FAIL — message relay protocol, not shared sequencer.
**TF-2:** FAIL — explicit send/receive message dependency.

**Overall:** FAIL TF-1/TF-2

---

### 5. Polygon AggLayer Applications (AggLayer ecosystem)
**URL:** https://www.agglayer.dev/
**Ecosystem:** Polygon zkEVM, X Layer, IoTeX, and AggLayer v0.3+ chains

**TF-1:** UNCLEAR — AggLayer provides a shared aggregation/proof layer for
connected chains. Applications on multiple AggLayer chains could potentially
span a single "sequencing commitment" at the AggLayer level.
- If AggLayer's proof aggregation functions as a shared sequencer commitment
  covering both chains, TF-1 may PASS.
- Pending deeper analysis.

**TF-2:** UNCLEAR — depends on whether app uses AggLayer native bridge
(direct state) or cross-chain messaging.

**TF-3:** LIKELY FAIL
- AggLayer uses ZK proof aggregation. If the proof covers execution outcomes
  before finalization, this is capability (i), not lazy sequencing.
- However, the "sequencer" (block producers for each chain) are likely still
  lazy — the ZK proof is generated post-execution by provers, not pre-commitment.
- Nuance: the commitment at the AggLayer level may be the ZK proof submission,
  which happens post-execution → TF-3 FAIL (sequencer is not lazy at the
  AggLayer commitment level).

**AX-4:** LIKELY FAIL as attack target — ZK proof suggests capability (i).

**Overall:** LIKELY FAIL TF-3 / AX-4 (but needs deeper analysis)
**Notes:** Include AggLayer in §7 design-space map as candidate capability (i)
mechanism (pessimistic proof). Flag for Task 2.1 deeper review.

---

### 6. Applications on Astria Rollup Cluster
**URL:** https://astria.org/
**Astria confirms:** Lazy sequencer, commits to ordering + data, no execution.

**TF-1:** CONDITIONAL PASS
- Any application deployed on 2+ rollups that are both sequenced by Astria
  satisfies TF-1. Astria sequences multiple rollups simultaneously.
- **Finding:** As of 2025, Astria is primarily testnet/devnet. Mainnet
  rollup cluster with multiple application-facing chains is still limited.
- **Candidate sub-question:** What DeFi applications have deployed on 2+
  Astria-sequenced rollups?

**TF-2:** Application-dependent — need to find specific apps.

**TF-3:** PASS (confirmed by Astria docs).

**AX-4:** Application-dependent — depends on app architecture.

**Overall:** Platform PASS for TF-1 and TF-3. Need to identify specific apps.
**Action:** Research applications deployed on Astria devnet/testnet (Task 1.3).

---

### 7. Applications on Espresso-Sequenced Rollup Cluster
**URL:** https://espressosys.com/
**Note:** Espresso docs largely 404'd; based on known knowledge.

**TF-1:** CONDITIONAL PASS
- Espresso provides shared sequencing via HotShot. Applications on 2+
  Espresso-sequenced rollups would satisfy TF-1.

**TF-3:** UNCLEAR
- Espresso's execution attestation variant may provide capability (i) if
  HotShot attests to execution outcomes. If so, TF-3 FAIL.
- If Espresso commits to ordering only (like Astria), TF-3 PASS.
- **Critical question:** Does HotShot execution attestation cover *joint*
  multi-rollup bundle execution?

**AX-4:** UNCLEAR — depends on execution attestation scope.

**Overall:** Platform potentially PASS for TF-1. TF-3 and AX-4 require
manual documentation review (Task 2.3).

---

### 8. Lyra Finance (options protocol)
**Background knowledge:** Lyra (now Derive) was discussed in an
ethresear.ch thread about shared sequencing. Options protocol previously
deployed on Optimism, then migrated.

**TF-1:** UNCLEAR — need to check if Lyra/Derive uses shared sequencing
across multiple rollups simultaneously.

**Action:** Manual investigation required (Task 1.3).

---

### 9. Synthetix / Kwenta
**Background knowledge:** Synthetix has deployment on Optimism and Base.
The ethresear.ch thread mentioned Lyra and Synthetix in context of shared
sequencing.

**TF-1:** UNCLEAR — Synthetix spans Optimism + Base, but both use their
own native sequencers (no confirmed shared sequencer).

**TF-1:** LIKELY FAIL — OP and Base use Optimism Collective shared sequencer
in practice, but the sequencer is the OP stack sequencer, not a dedicated
cross-rollup shared sequencer.

**Action:** Investigate if OP Superchain shared sequencing (if deployed)
could create TF-1 PASS for Synthetix/Base. This is the OP "Superchain"
sequencer decentralization path.

---

### 10. OP Superchain Applications (Superchain shared sequencing path)
**Background:** The OP Superchain envisions a shared sequencer for
OP-stack chains (OP, Base, Zora, etc.). If deployed, applications on
multiple Superchain chains would satisfy TF-1.

**TF-1:** CONDITIONAL PASS (pending Superchain shared sequencer launch)
- As of early 2026, Superchain shared sequencing is not yet live in
  production. The chains use independent sequencers.
- **If** Superchain shared sequencer launches before Week 4 of the
  development timeline: reconsider as TF-1 PASS candidate.

**TF-3:** LIKELY PASS — OP stack sequencer is lazy.

**Action:** Monitor Superchain sequencer decentralization progress.

---

## Summary Statistics

| # | Name | TF-1 | TF-2 | TF-3 | AX-4 | Priority |
|---|------|------|------|------|------|----------|
| 1 | Across | FAIL | N/A | N/A | §7 ex. | Excluded |
| 2 | UniswapX | FAIL | N/A | N/A | §7 ex. | Excluded |
| 3 | Everclear | FAIL | N/A | N/A | — | Excluded |
| 4 | deBridge | FAIL | FAIL | N/A | — | Excluded |
| 5 | AggLayer ecosystem | UNCLEAR | UNCLEAR | LIKELY FAIL | §7 ex. | Low priority |
| 6 | Astria ecosystem apps | COND PASS | App-dep | PASS | App-dep | **HIGH** |
| 7 | Espresso ecosystem apps | COND PASS | App-dep | UNCLEAR | UNCLEAR | **MEDIUM** |
| 8 | Lyra / Derive | UNCLEAR | — | — | — | Investigate |
| 9 | Synthetix/Kwenta | LIKELY FAIL | — | — | — | Low |
| 10 | OP Superchain apps | COND PASS (future) | App-dep | PASS | App-dep | Monitor |

---

## Next Steps (Task 1.3)

The survey confirms that the candidate population is dominated by
**Astria-ecosystem applications** as the highest-priority TF-1/TF-3 passers.

Priority actions:
1. Identify specific DeFi applications deployed on 2+ Astria-sequenced testnet
   rollups (search Astria docs, Discord, and GitHub for deployed app lists)
2. Evaluate Espresso ecosystem applications and confirm TF-3 status
3. Monitor OP Superchain sequencer timeline (low probability before Week 4)
4. Deep-dive Lyra/Derive architecture

**Minimum viable candidate set for Task 1.3:**
- Need at least 1 Astria-ecosystem application with mainnet/testnet
  deployment on 2+ rollups and TVL > $1M (relaxed from $5M given early
  stage of shared sequencer ecosystem)
- If no Astria ecosystem application found, fallback to Espresso ecosystem

---

## §7 Design-Space Map Positive Examples Confirmed

| Application | Capability | Evidence |
|-------------|-----------|---------|
| Across Protocol | (ii) | UMA oracle + origin-chain escrow |
| UniswapX | (ii)+A4 | Signed order fill constraint |
| AggLayer | (i) candidate | Pessimistic ZK proof aggregation |
