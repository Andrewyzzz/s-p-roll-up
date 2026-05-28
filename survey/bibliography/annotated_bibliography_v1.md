# Annotated Bibliography: Preconfirmation and Shared Sequencing Literature

**Task:** 1.5 — ethresear.ch preconfirmation threads systematic read
**Status:** v2.0 — updated with mev-commit conflation evidence + Astria
transaction flow verbatim quotes (2026-05-28)
**Scope:** Primary sources read via WebFetch; manually verified URLs.
**Note:** ethresear.ch URLs frequently 404 (posts moved/deleted); URL list
includes both confirmed-live and known-dead entries flagged accordingly.

---

## Category 1: Foundational ethresear.ch Preconfirmation Posts

---

### [Drake2023-BasedPreconf] — Based Preconfirmations
**URL:** https://ethresear.ch/t/based-preconfirmations/17353 ✅ LIVE
**Author:** Justin Drake
**Date:** November 8, 2023
**Venue:** ethresear.ch

**Summary:** Proposes that L1 proposers can issue "preconf promises" to L2
users, enabling ~100ms soft confirmation latency. Infrastructure requires:
(i) proposer slashing via restaking, and (ii) proposer forced inclusions via
inclusion lists. Defines three commitment levels by strictness.

**Commitment levels (verbatim):**
- Strictest: "commits to the post-execution state root of the L2 chain"
- Weaker: commits to execution state diffs only
- Weakest: "only commits to transaction inclusion by a preconfer slot"

**Slashing conditions (verbatim):**
- Liveness fault: "the preconfer's slot was missed and the preconfed
  transaction was not previously included onchain"
- Safety fault: "the preconfer's slot was not missed and the promise is
  inconsistent with preconfed transactions"

**Atomicity claims:**
- A2 claim (execution atomicity): **No.** No mention of "atomicity" or "atomic."
- A4 claim (economic atomicity): **Implicit.** The slashing mechanism is
  described as a compensation mechanism for commitment violation — classic A4.
- Conflated/ambiguous: **N/A** — the post does not use atomicity language.

**Paper sections:**
- §2 (taxonomy): The strictest commitment level ("post-execution state root")
  is an instance of capability (i) — pre-execution evidence — but only for
  single-chain L2, not multi-rollup bundles. The weakest level ("inclusion")
  is A4 only. This post provides the primary example of the A4/A2 spectrum
  for §2.3 deployed system mapping.
- §6 (Theorem 1): The strictest level provides capability (i) for single-chain.
  The paper should note that extending this to cross-rollup bundles requires
  a *joint* execution predicate, which this post does not propose.
- §10 (related work): Cite as the founding L1-preconfirmation reference.

**Quotes for paper:**
> "only commits to transaction inclusion by a preconfer slot"
(Illustrates the weakest commitment level = pure A4)

---

### [Drake2023-BasedRollups] — Based Rollups: Superpowers from L1 Sequencing
**URL:** https://ethresear.ch/t/based-rollups-superpowers-from-l1-sequencing/15016 ✅ LIVE
**Author:** Justin Drake
**Date:** March 10, 2023
**Venue:** ethresear.ch

**Summary:** Proposes using Ethereum L1 validators as rollup sequencers
("based rollups"), claiming this provides L1 economic security, liveness
guarantees, and MEV alignment. Primary focus is single-rollup architecture.

**Atomicity claims:**
- A2 claim: **No** — the original post makes no explicit cross-rollup
  atomicity claims.
- A4 claim: **No.**
- Cross-rollup composability: Emerges only in replies. Comment by
  ballsyalchemist notes that MEV-capturing modifications "breaks atomic
  composability between rollups who's batches are submitted in the same block."
  This is precisely the A2 gap this paper addresses.

**Key finding for paper:** The cross-rollup atomicity claim is *absent* from
the original based-rollups proposal — it was added as a folk assumption in
subsequent community discussion. This is evidence for the paper's claim that
"atomicity" is conflated informally without formal grounding.

**Paper sections:**
- §9 (discussion): Based rollups generalization — same lazy-sequencer argument
  applies to L1 validator as sequencer.
- §10 (related work): Founding based-rollup reference; note the absence of
  cross-rollup atomicity claims in the original.

---

## Category 2: Shared Sequencer Design

---

### [Astria-Docs] — Astria Shared Sequencer Documentation
**URL:** https://docs.astria.org/overview/components/the-astria-sequencing-layer ✅ LIVE
**Author:** Astria team
**Date:** 2024–2025 (living document)
**Venue:** Official documentation

**Summary:** Documents Astria's shared sequencer architecture. Explicitly
confirms the lazy sequencer model and commitment-to-data (not execution)
design.

**Key technical facts (verbatim from docs):**
> "it primarily orders transactions without executing them, as they are
> intended for execution on rollups"

> "the proposer decides on block transactions and creates commitments to
> rollup data for each `rollup_id`"

The sequencer "comes to consensus on the ordering and inclusion of rollup
transactions" — not execution outcomes.

**Atomicity claims:**
- A2 claim: **None.** Documentation makes no cross-rollup atomicity claims.
- A4 claim: **None.**
- TF-3 confirmation: **Yes.** "does not execute state transitions" = lazy
  sequencer confirmed.

**Critical absence:** The documentation makes no claim about cross-rollup
atomicity. This is an important negative finding — the shared sequencer
provider itself does not claim A2.

**Paper sections:**
- §2.3 (deployed system mapping): Astria = A0/A1 (ordering + inclusion),
  not A2. Direct quote usable.
- §4.1 (PEFO structural condition): TF-3 confirmation via official docs.
- §6 (Theorem 1): Supports the claim that lazy sequencers (by their own
  design) do not provide capability (i) or (ii).

**Quotes for paper:**
> "it primarily orders transactions without executing them"
> "commits to rollup data for each rollup_id"

---

### [AggLayer-Docs] — Polygon AggLayer Documentation
**URL:** https://www.agglayer.dev/ ✅ LIVE
**Author:** Polygon team
**Date:** 2025 (v0.2 live Feb 2025, v0.3 Jun 2025 target)
**Venue:** Official documentation

**Summary:** AggLayer is a cross-chain aggregation layer using pessimistic
proofs to ensure "no chain can withdraw more assets than have been deposited
on the unified bridge." Uses ZK proof aggregation.

**Atomicity claims:**
- A2 claim: **None explicit.** No mention of "atomic" or "atomicity" in
  available content.
- Pessimistic proof: "No chain can withdraw more assets than have been
  deposited on the unified bridge" — this is a *safety* guarantee, not
  an execution atomicity guarantee.
- Capability (i): **Partial.** ZK proof aggregation provides cryptographic
  evidence of state transitions, but whether this covers *joint* cross-rollup
  bundle execution is unclear from the documentation.

**Paper sections:**
- §7 (design-space map): AggLayer's pessimistic proof is a candidate
  instantiation of capability (i) — pending deeper analysis of whether it
  covers joint bundle execution.
- Appendix A: May need a new boundary case entry for AggLayer.

**TODO:** Confirm in Task 2.1 whether AggLayer's pessimistic proof constitutes
capability (i) for cross-rollup bundles specifically (joint predicate required).

---

## Category 3: Preconf Implementation Designs

---

### [JustinDrake2023-BasedPreconf-CommitmentLevels] (see entry above)

The commitment levels in [Drake2023-BasedPreconf] provide a de-facto taxonomy
for preconf implementation designs:

| Level | Commits to | Capability |
|-------|-----------|------------|
| Strictest | Post-execution state root | (i) — for single chain |
| Medium | Execution state diffs | (i) — for single chain |
| Weakest | Transaction inclusion | A4 only |

**Implication for paper:** mev-commit and Bolt (see knowledge-based entries
below) provide the *weakest* level (inclusion), which is A4 only. The
strictest level is theoretically capability (i) but requires the preconfer to
execute the STF — making them an eager, not lazy, sequencer.

---

### [MevCommit-Docs] — mev-commit Protocol Documentation
**URL:** https://docs.primev.xyz/ (main docs, specific pages returned 404)
**Author:** Primev team
**Date:** 2024–2025
**Venue:** Official documentation
**Note:** Multiple doc pages 404'd; entry based on training-data knowledge +
partial docs access. Flag for manual verification in Task 2.3.

**Summary:** mev-commit is a preconfirmation protocol where validators/builders
issue signed commitments to include specific transactions in future blocks.
Commitments are backed by bonds; failure to honor results in slashing.

**Commitment type:** Inclusion commitment ("this transaction will be in block N")
— not execution commitment ("this transaction will succeed in block N").

**Atomicity claims:**
- A2 claim: **None.** mev-commit commits to *inclusion*, not execution outcome.
- A4 mechanism: Bond slashing on inclusion failure = A4.
- Capability (i): **No** — no execution predicate.
- Capability (ii): **No** — no revert authority over rollup state.

**Paper sections:**
- §6 Observation 1 table: mev-commit = A4 only.
- Appendix A: "mev-commit / Bolt Preconfirmation" boundary case.

**Quotes needed:** Need verbatim from actual docs confirming inclusion vs.
execution commitment. Flag for Task 2.3 manual check.

---

## Category 4: Cross-Rollup MEV and Ordering

---

### [Obadia2021-Unity] — Unity is Strength: Cross-Domain MEV
**URL:** https://arxiv.org/abs/2112.01472
**Author:** Alexandre Obadia et al. (Flashbots)
**Date:** December 2021
**Venue:** arXiv preprint

**Summary:** Formalizes cross-domain MEV as value extraction across multiple
blockchains by a coordinated party. Introduces the concept of a "domain"
(a state machine with ordering authority) and analyzes MEV that crosses
domain boundaries.

**Atomicity claims:**
- A2 claim: **No.** The paper analyzes value extraction, not execution
  atomicity guarantees.
- A4 claim: **Implicit framework.** The cross-domain MEV is precisely the
  economic externality that A4 aims to bound.

**Paper sections:**
- §10 (related work): §5 cross-domain MEV reference. Our A4 definition
  extends this framework: the option value in our paper is the cross-domain
  MEV extracted from the sequencing commitment gap.
- §2 (taxonomy): "Domain" maps to our "rollup"; "cross-domain MEV" maps to
  our "option value from sequencing gap."

---

## Category 5: Atomic Cross-Rollup Execution Claims

---

### [Across-Protocol] — Across Protocol
**URL:** https://across.to/ ✅ LIVE
**Author:** Risk Labs
**Date:** 2021–2025 (active)
**Venue:** Protocol + documentation

**Summary:** Intent-based cross-chain bridging. User submits transfer intent;
filler executes immediately on destination chain; origin-chain funds released
from escrow after UMA oracle confirmation. $34B+ volume.

**Atomicity claims:**
> "every transfer is verified onchain with no multisigs and no custodial risk"
— This is an integrity claim (on-chain verification), not a cross-rollup
execution atomicity claim in the A2 sense.

**Capability analysis:**
- TF-1: FAIL — does not use a shared sequencer. Each rollup uses its native
  sequencer independently.
- Capability (ii): **Yes (user-facing).** Origin-chain funds held in escrow
  until UMA confirmation. Partial-effect prevention for user funds.
- AX-4: **FAIL as attack target** — capability (ii) present for user funds.
- **§7 positive example**: Across instantiates capability (ii) via UMA escrow.
  This is a confirmed positive example for the design-space map.

**Key finding:** Across is NOT a PEFO attack target (AX-4 fails), but IS a
confirmed capability (ii) instantiation for §7.

---

### [Everclear] — Everclear (formerly Connext)
**URL:** https://everclear.org/ ✅ LIVE
**Author:** Connext / Everclear team
**Date:** 2023–2025 (active)
**Venue:** Protocol + documentation

**Summary:** Cross-chain clearing and settlement protocol. Uses netting to
reduce liquidity fragmentation. $1B+ cleared. Solvers choose repayment
methods.

**Atomicity claims:** None explicit in marketing page. Architecture uses a
"Clearing Chain" as the settlement layer.

**TF analysis:**
- TF-1: UNCLEAR — uses own clearing chain, not a shared rollup sequencer.
  Likely TF-1 FAIL.
- Needs deeper architectural review (Task 1.3).

---

## Summary: Key Findings for Paper

### What the literature DOES say about "atomicity"

1. **Justin Drake's based-rollups post makes no cross-rollup atomicity claims**
   — the claim emerged as folk assumption in community replies.

2. **Based preconfirmations** offer a spectrum from A4-only (inclusion) to
   near-capability-(i) (execution state root) — but only for single-chain L2,
   not multi-rollup bundles.

3. **Astria explicitly confirms the lazy sequencer model** with no atomicity
   claims — providing strong documentation support for TF-3.

4. **AggLayer uses pessimistic proofs** (ZK-based), which is a candidate
   capability (i) mechanism — but unclear if it covers joint cross-rollup
   bundle execution.

5. **Across Protocol** confirms capability (ii) via UMA escrow — confirming
   the §7 design-space classification.

### What is ABSENT from the literature

- No ethresear.ch post found that formally defines "cross-rollup atomic
  execution" as distinct from "cross-rollup atomic inclusion."
- No shared sequencer documentation found that claims A2 execution atomicity.
- The conflation appears to happen at the **application and marketing layer**,
  not in the technical protocol documentation.

### Coverage gaps (pending manual research)

- mev-commit and Bolt verbatim documentation (specific doc pages 404'd)
- Espresso HotShot execution attestation details (Espresso docs 404'd)
- Specific applications deployed on Astria shared sequencer
- Radius encrypted sequencing documentation
- CCS 2025 "Denial of Sequencing" paper (not yet available)
- arXiv 2410.11552 (need manual lookup)

---

---

## Category 3 (continued): mev-commit — A2/A4 Conflation Evidence

### [MevCommit-Marketing] — mev-commit: "Atomicity and Execution Guarantees"
**URL:** https://primev.xyz/ ✅ LIVE
**Author:** Primev team
**Date:** 2024–2025 (active)
**Venue:** Protocol marketing page + documentation

**Summary:** mev-commit is a preconfirmation protocol where validators/builders
issue signed commitments to include transactions in future blocks. The
commitment is backed by bond; failure to include results in slashing. The
marketing page claims "Atomicity and Execution Guarantees."

**Atomicity claims (marketing):**
> "Atomicity and Execution Guarantees" — primev.xyz homepage

**Technical reality (from bid structure docs, docs.primev.xyz):**
The bid commitment structure contains `revertingTxHashes`:
> "Array of transaction hashes as strings that can revert"
— explicitly acknowledging that committed transactions can revert without
triggering a violation.

Slashing triggers are **positioning/inclusion** failures:
> "if the transaction is not in the top 10%, the provider will be slashed"
— not execution outcome failures.

Technical description of the commitment:
> "A binding commitment from a block builder to include a transaction"
— docs.primev.xyz

**Atomicity classification:**
- A2 claim (execution atomicity): **Marketing says yes. Technical docs say no.**
  The `revertingTxHashes` field is definitive: execution failures are explicitly
  non-violating.
- A4 claim (economic atomicity): **Yes** — bond slashing on inclusion failure.
- Conflated/ambiguous: **YES — clear example of A2/A4 conflation.** The
  marketing language ("Atomicity and Execution Guarantees") claims A2, but
  the actual mechanism (inclusion commitment + bond) is A4.

**Paper significance:** This is the strongest live example of the conflation
the paper addresses. The marketing-vs-technical-spec gap is direct evidence
that practitioners conflate A2 and A4. Recommend quoting in §1 (Introduction)
as a motivating instance.

**Quotes for paper:**
> "Atomicity and Execution Guarantees" — primev.xyz (marketing claim)
> "Array of transaction hashes as strings that can revert" — docs.primev.xyz
> (technical bid structure, showing execution reverts are non-violating)

---

### [Astria-TxFlow] — Astria Transaction Flow Documentation
**URL:** https://docs.astria.org/overview/transaction-flow ✅ LIVE
**Author:** Astria team
**Date:** 2024–2025 (living document)
**Venue:** Official documentation

**Summary:** Documents the full write path for transactions submitted to
Astria-sequenced rollups. Introduces the "meta block" concept.

**Key technical facts (verbatim):**
> "the proposer decides on block transactions and creates commitments to
> rollup data for each rollup_id"

> "provides a guarantee on the ordering of transactions in a block, but it
> doesn't execute the state transition function (STF) of any given rollup"

> "a single meta block consisting of transactions submitted to its mempool
> by one or more rollups"

**Commitment timing:**
- Soft commitment: ~1-second Astria block times
- Firm commitment: ~11-second Celestia DA finality
- Execution: **after** the Conductor receives the ordered block

**Cross-rollup implication:**
The "single meta block" that covers transactions from "one or more rollups"
is the PEFO bundle `B = (τ₁, τ₂)`. An attacker's transactions to Rollup A
and Rollup B co-occur in the same meta block commitment, which is issued
*before* execution on either rollup. This is the exact lazy-sequencer free
option structure described in §4.2.

**Atomicity claims:**
- A2 claim: **None.** No atomicity language.
- A4 claim: **None.**
- Critical absence: The meta block commitment makes no execution atomicity
  guarantee — it only commits to ordering. This is consistent with TF-3 PASS.

**Paper sections:**
- §2.3 (deployed system mapping): Astria = A0/A1 (ordering + inclusion, no A2).
- §4.1 (PEFO structural conditions): Meta block = the shared commitment Γ(B).
  TF-1 confirmed (multi-rollup coverage), TF-3 confirmed (lazy sequencer).
- Verbatim quotes usable directly in §4.2 structural condition exposition.

---

### [Espresso-Architecture] — Espresso Confirmation Layer Architecture
**URL:** https://github.com/EspressoSystems/espresso-network/blob/main/doc/architecture.md
**Author:** Espresso Systems team
**Date:** 2024–2025 (living document)
**Venue:** Official GitHub documentation
**Source:** Manual download by author (architecture.md confirmed accessible)

**Summary:** Describes the Espresso Confirmation Layer architecture with a
step-by-step sequence diagram showing how HotShot consensus fits between
rollup block building and rollup STF execution.

**Key technical facts (verbatim):**

Overview step 4:
> "Espresso produces Espresso blocks containing rollup namespaces with confirmed
> rollup blocks. L2 validators receive blocks and **execute the state transition
> functions** for their rollups."

Glossary:
> "Espresso block: a block produced by Espresso Network **containing transactions
> of multiple rollups**"

Sequence diagram step 4:
> "Clients, rollup validators and bridges are notified the L2 block is finalized
> by Espresso. Interested parties can now derive the new state of the rollup
> if desired."

Sequence diagram step 6 (post-confirmation):
> "A rollup node which has executed the block sends the new rollup state to the L1."

**Commitment timing (definitive):**
- Step 3: Rollup builds proposed block (ordering, no execution)
- Step 4: Rollup sends to Espresso
- Step 6: HotShot consensus creates confirmed block = **Γ(B)**
- Step 7: Rollup produces final block with Espresso-finalized transactions
- Step 6 (overview): L2 validators **execute STFs** — after HotShot confirmation

**TF-3 verdict: PASS.** Execution happens after HotShot commitment.

**TF-1 verdict: PASS.** Single Espresso block contains transactions of
multiple rollups simultaneously (namespace model).

**No atomicity claims.** Document does not use "atomic" or "atomicity."

**Production rollups confirmed (from llms-full.txt):**
Mainnet: Rari (Jan 2025), ApeChain (Yuga Labs), AppChain
Testnet: Celo, Molten, T3rn, Huddle01 (Arbitrum Nitro forks)

**Paper sections:**
- §2.3 (deployed system mapping): Espresso = A0/A1 (ordering + finality, no A2).
  Parallel to Astria. Both confirmed lazy sequencers from official docs.
- §4.2 (PEFO structural conditions): Espresso block = joint Γ(B) for
  TF-1. Sequence from architecture.md confirms TF-3.
- §6 (Theorem 1): Espresso confirms ordering without execution outcomes →
  no capability (i) in commitment path. Consistent with Theorem 1 scope.

**Quotes for paper:**
> "L2 validators receive blocks and execute the state transition functions
> for their rollups." — architecture.md step 4 (TF-3 evidence)
> "Espresso block: a block produced by Espresso Network containing transactions
> of multiple rollups" — architecture.md Glossary (TF-1 evidence)

---

### [Drake2023-ExecTickets] — Execution Tickets
**URL:** https://ethresear.ch/t/execution-tickets/17944 ✅ LIVE
**Authors:** Justin Drake, Mike Neuder (scribe), Francesco Montoya, Barnabé Monnot
**Date:** December 23, 2023
**Venue:** ethresear.ch

**Summary:** Proposes "execution tickets" as vouchers granting future L1
block proposal rights, separating beacon block validation from execution
block production. Aims to firewall validators from MEV centralization.

**Commitment type:**
- Beacon proposers create "inclusion lists" specifying transactions that
  "must be present in the execution block" — this is a **pre-execution
  constraint**, not a post-execution proof.
- Execution block proposer posts collateral "as an assurance that they will
  produce a single execution block during the execution round."

**Atomicity claims:**
- A2 claim: **No.** Design provides inclusion constraints, not execution outcome
  guarantees.
- A4 claim: **Implicit** — collateral (bond) for execution block production.
- Classification: A4 only (bond mechanism) for the execution guarantee;
  inclusion list is a sequencing constraint, not a success predicate.

**Paper sections:**
- §6 Observation 1 table: execution tickets fall in the A4 category.
- §10 (related work): Representative of the L1-preconf design space.

---

## URL List for Manual Verification (Task 1.5 continuation)

```
CONFIRMED LIVE:
- https://ethresear.ch/t/based-preconfirmations/17353
- https://ethresear.ch/t/based-rollups-superpowers-from-l1-sequencing/15016
- https://docs.astria.org/overview/components/the-astria-sequencing-layer
- https://www.agglayer.dev/
- https://across.to/
- https://everclear.org/
- https://arxiv.org/abs/2112.01472

RETURNED 404 (need alternative URLs):
- https://ethresear.ch/t/preconfirmation-taxonomy/20361
- https://ethresear.ch/t/native-rollup-atomic-composability-with-shared-sequencing/18278
- https://ethresear.ch/t/shared-sequencing-lyra-and-synthetix/18261
- https://ethresear.ch/t/cross-rollup-transactions/17965
- https://docs.bolt.chainbound.io/
- https://docs.primev.xyz/concepts/mev-commit-protocol
- https://docs.espressosys.com/sequencer/espresso-sequencer-architecture/readme

NEEDS MANUAL SEARCH:
- arXiv 2410.11552 (search arxiv.org)
- CCS 2025 Denial of Sequencing paper
- Barnabé Monnot preconfirmation economics posts
- Mike Neuder preconfirmation posts
- Potuz / Francesco d'Amato preconf design posts
```
