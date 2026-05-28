# Candidate Protocol: Thesis-Fit Filter and Selection Procedure

**Version:** 1.0
**Status:** FINAL — pre-registration pending (Task 1.6: OTS stamp + git push)
**Purpose:** Operationalize the candidate selection criteria for the [DEPLOYED_APP]
instantiation of Attack 2 (PEFO). No candidate review begins before this document
is stamped.

**Linked paper sections:** §4.1 (PEFO structural conditions), §4.4.1 (target
selection rationale), §6.1 (Theorem 1 necessary capabilities)

---

## Part 1: Mandatory Thesis-Fit Filter

All three conditions (TF-1, TF-2, TF-3) must be **simultaneously satisfied**.
One failure = immediate disqualification regardless of auxiliary score.

The three mandatory conditions correspond directly to the three PEFO structural
conditions in §4.2.

---

### TF-1 — Multi-rollup shared sequencer/preconfirmation

> The application has active deployments on **two or more rollups that share a
> common sequencer or preconfirmation layer**. User-submitted intents or bundles
> reference state on both rollups within a single sequencing commitment.

**Why required:**
The free option arises from the gap between *commitment time* and *execution time*.
This gap only exists if the sequencer issues commitments that span rollup boundaries
before execution outcomes are known. An application deployed on a single rollup
or using independent sequencers per rollup does not give rise to this gap.

**Maps to PEFO Condition 1:** "The application spans ≥2 rollups whose state
transition functions are sequenced by a shared lazy layer."

**Evidence required:**
- [ ] Named shared sequencer or preconf layer (e.g., Astria, Espresso, Radius,
      mev-commit, Bolt, or a named based-sequencing arrangement)
- [ ] Documentation or contract evidence that the same commitment covers
      transactions on both rollups (e.g., shared block header, shared batch
      inclusion proof, or preconf receipt referencing both rollup IDs)
- [ ] Deployment addresses on ≥2 distinct rollup chains (not testnets only)

**Fail examples:**
- App on OP + App on Base but each rollup uses its own native sequencer with no
  shared commitment layer → TF-1 FAIL (no shared commitment)
- App on a single L3 with intra-app cross-contract calls → TF-1 FAIL (single STF)

**Pass examples:**
- Intent filler app on Rollup A + Rollup B, both part of an Astria cluster →
  TF-1 PASS

---

### TF-2 — Independent execution legs (not cross-chain messaging)

> The application's cross-rollup operation involves **independent executions** on
> each rollup: the bundle leg on Rollup A proceeds (or reverts) without waiting
> for an explicit protocol-level dependency on Rollup B's execution outcome.
> The two legs are *not* connected by a cross-chain messaging protocol that creates
> a sequential dependency.

**Why required:**
PEFO requires that one leg can succeed while the other fails — the "partial
execution" in Partial-Execution Free Option. Cross-chain messaging protocols
(LayerZero, Wormhole, Hyperlane) introduce explicit send/receive dependency:
Leg B cannot execute until a message from Leg A is explicitly relayed. This
dependency makes the attack structurally different (it becomes a messaging delay
exploit, not a sequencing commitment exploit). The PEFO gap is specific to the
case where both legs are presented as a bundle to the sequencer but executed
independently.

**Maps to PEFO Condition 2:** "Bundle legs execute independently at the STF
level — no protocol-enforced outcome dependency between legs."

**Evidence required:**
- [ ] Inspect application's cross-rollup flow: the operation on Rollup A and the
      operation on Rollup B are submitted as a bundle (or paired intents) to the
      sequencer — not as a send-message transaction followed by a receive callback
- [ ] No LayerZero `lzReceive`, Wormhole `receiveWormholeMessages`, or equivalent
      cross-chain message handler in the critical path of the cross-rollup operation
- [ ] Each leg is a direct state-modifying call to a contract on its respective
      rollup (e.g., token transfer, swap, liquidity provision)

**Nuance — hybrid architectures:**
Some applications use messaging for settlement but submit intents as a bundle.
Classify by the *commitment path*: if the sequencer's commitment covers both
legs directly (not mediated by a message relay), TF-2 is satisfied even if
post-hoc settlement uses a message bridge.

**Fail examples:**
- Cross-chain swap using LayerZero: chain A burns token, sends message to chain B,
  chain B mints. The "bundle" is actually a single transaction + async relay →
  TF-2 FAIL
- HTLC where Leg B is a hashlock-release transaction: execution is explicitly
  dependent on Leg A's preimage reveal → TF-2 FAIL (also see AX-4 below)

**Pass examples:**
- Cross-rollup intent filler: filler submits fill transactions on both rollups in
  a single Astria bundle; each fill executes independently against local state →
  TF-2 PASS

---

### TF-3 — Lazy sequencer (does not execute STFs)

> The shared sequencer or preconfirmation layer **issues commitments without
> executing the state transition functions** of either rollup. It commits to
> ordering (and possibly inclusion) but does not verify or enforce execution
> outcomes before issuing the commitment.

**Why required:**
If the sequencer *did* execute STFs before committing (i.e., it is an "eager"
sequencer), it could detect a would-be partial execution and refuse to commit.
The free option requires that the sequencer's commitment is issued *before*
execution outcomes are determined, so the attacker can selectively exercise it.

**Maps to PEFO Condition 3:** "The sequencer issues a commitment Γ without
knowing the execution outcome of either STF."

**Evidence required:**
- [ ] Sequencer/preconf design documentation or codebase: commitment is issued at
      inclusion/ordering stage, not after execution
- [ ] Absence of on-chain execution attestation in the sequencer's commitment
      structure (a ZK proof of execution outcome in the commitment would
      negate TF-3 — see AX-4 conflict check)
- [ ] Confirmation that execution happens on the rollup node *after* the
      sequencer's commitment is published

**Boundary case — execution attestation vs. ordering commitment:**
Some preconf designs provide an "execution ticket" (attestation that a specific
tx will be executed). If the execution ticket is issued *before* the sequencer
knows the execution outcome (i.e., it is a promise, not a proof), TF-3 is still
satisfied. The ticket does not resolve the free option; it merely adds a slashing
mechanism (which is an A4, not A2, mechanism per Theorem 1).

**Fail examples:**
- Espresso HotShot with on-chain ZK execution proof in commitment → TF-3
  borderline (check whether proof covers both rollups atomically — if yes, see
  AX-4)
- A single shared execution environment (shared EVM) where "cross-rollup" is
  intra-contract → TF-3 FAIL (execution is not split)

**Pass examples:**
- Astria shared sequencer: commits to ordered batch, rollup full nodes execute
  independently → TF-3 PASS
- mev-commit / Bolt preconf: issues signed preconfirmation of inclusion before
  execution → TF-3 PASS (commitment precedes execution)

---

## Part 2: Auxiliary Filter

Auxiliary criteria are not individually disqualifying but are aggregated into a
priority score. A candidate that fails ≥3 auxiliary criteria should be deprioritized
in favor of a candidate that fails ≤1.

| ID | Criterion | Preferred | Weight |
|----|-----------|-----------|--------|
| AX-1 | TVL or locked value | $5M–$100M (mainnet) | High |
| AX-2 | Smart contracts verified on Etherscan / block explorer | Yes | High |
| AX-3 | Active mainnet deployment during 2024–2026 | Yes | High |
| AX-4 | Architecture does NOT already instantiate Theorem 1 capability (i) or (ii) | Confirmed absence | Critical |
| AX-5 | Testnet available and accessible | Yes | Medium |
| AX-6 | Vendor has public security contact or bug bounty | Yes | Medium |
| AX-7 | No active litigation or regulatory action | Confirmed | Low |

### AX-4 Detail — Theorem 1 Mitigation Absence Check

This is the most critical auxiliary criterion. If the application already implements
either Theorem 1 capability, PEFO is architecturally closed and the application is
not a valid attack target.

**Capability (i) — Pre-execution success-predicate evidence:**
The sequencer or preconf layer requires cryptographic proof that both execution
legs will succeed before issuing its commitment. This closes the option at the
commitment stage.

*Instantiations to check for:*
- ZK proof of execution outcome included in commitment
- Simulation-enforced commitment (sequencer runs STF locally before committing)
- EigenDA or DA layer with execution attestation (not just data availability)

**Capability (ii) — Authority to prevent partial irreversible effects:**
The application's contract design ensures that if one leg fails, the other leg's
effects are also reverted. This closes the option at the execution stage.

*Instantiations to check for:*
- HTLC / hashlock structure (both legs revert if preimage not revealed)
- Escrow with atomic release (funds held in escrow until both sides confirm)
- Optimistic rollback: application-level saga with compensation transaction

*Explicit AX-4 pass criterion:*
Confirm that neither (i) nor (ii) is present in the critical path of the
cross-rollup operation. If either is present for the specific operation targeted
by PEFO, the candidate FAILS AX-4 and is excluded from the attack target list.
The candidate may still be included in the §7 design-space map as a positive
example of Theorem 1 instantiation.

---

## Part 3: Decision Procedure

```
Step 1: TF-1 check
  └─ FAIL → disqualify immediately (do not proceed to TF-2/TF-3)
  └─ PASS → continue

Step 2: TF-2 check
  └─ FAIL → disqualify immediately
  └─ PASS → continue

Step 3: TF-3 check
  └─ FAIL → disqualify immediately
  └─ PASS → candidate enters auxiliary scoring

Step 4: AX-4 check (Theorem 1 mitigation absence)
  └─ FAIL → disqualify as attack target
             RECORD as Theorem 1 positive example for §7 design-space map
  └─ PASS → continue

Step 5: AX-1/2/3/5/6/7 scoring
  └─ Score = number of auxiliary criteria satisfied (max 6)
  └─ Score ≥ 4 → HIGH priority candidate
  └─ Score 2–3 → MEDIUM priority candidate
  └─ Score ≤ 1 → LOW priority candidate (deprioritize)

Step 6: Rank candidates
  └─ Select Primary = highest-scoring HIGH priority candidate
  └─ Select Backup = second-highest (may be MEDIUM)
  └─ If < 2 candidates reach HIGH/MEDIUM → re-examine population
     (either expand survey N or relax AX-1 TVL threshold to $1M)
```

---

## Part 4: Evidence Documentation Template

For each candidate that passes TF-1/2/3, complete this template before
proceeding to architecture analysis (Task 2.1).

```markdown
### Candidate: [NAME]

**Date assessed:** YYYY-MM-DD
**Assessor:** [Author]

#### TF-1: Multi-rollup shared sequencer
- Rollups: [list]
- Shared layer: [name + URL]
- Commitment evidence: [source]
- Pass/Fail:

#### TF-2: Independent execution legs
- Cross-rollup flow description:
- Messaging protocol present?: [Yes/No — if Yes, is it in the commitment path?]
- Independent legs confirmed by: [contract function / docs reference]
- Pass/Fail:

#### TF-3: Lazy sequencer
- Sequencer design: [citation]
- Execution attestation in commitment?: [Yes/No]
- Pass/Fail:

#### AX-4: Theorem 1 mitigation absence
- Capability (i) check: [present / absent / uncertain]
  - Evidence:
- Capability (ii) check: [present / absent / uncertain]
  - Evidence:
- AX-4 result: [PASS as attack target / FAIL → §7 positive example]

#### Auxiliary Score
| Criterion | Result | Notes |
|-----------|--------|-------|
| AX-1 TVL  |        |       |
| AX-2 Contracts verified |  |  |
| AX-3 Active 2024–2026 |    |  |
| AX-5 Testnet available |   |  |
| AX-6 Security contact |    |  |
| AX-7 No litigation |       |  |
| **Total** |        |       |

**Priority:** HIGH / MEDIUM / LOW

**Preliminary architecture notes:**
(Where do PEFO conditions 1/2/3 instantiate in the contract code?)
```

---

## Part 5: Anti-Gaming Clauses

The following candidate selection behaviors are explicitly prohibited to prevent
confirmation bias:

1. **No retroactive filter relaxation.** If a promising candidate fails TF-1/2/3,
   the filter criteria may not be weakened post-hoc to include it. The filter is
   fixed at pre-registration time (Task 1.6 OTS stamp).

2. **No cherry-picking within AX-4.** AX-4 must be assessed against the specific
   operation targeted by PEFO, not a different operation on the same application.
   An application that implements (ii) for the targeted operation fails AX-4 even
   if other operations on the same application are unprotected.

3. **Positive-finding reporting.** Candidates that fail AX-4 (already implement
   Theorem 1 mitigation) must be recorded and reported in §7 design-space map.
   Suppressing these cases would misrepresent the design-space coverage.

4. **Ghost-vendor documentation.** If the selected Primary candidate's vendor
   is non-responsive (Case 2), this is a valid outcome and must be reported as
   such in §8. It does not constitute a reason to retroactively change the
   candidate selection.

---

## Part 6: Candidate Tracking Table

*(To be populated during Task 1.2 survey + Task 1.3 viability assessment)*

| # | Name | TF-1 | TF-2 | TF-3 | AX-4 | Score | Priority | Notes |
|---|------|------|------|------|------|-------|----------|-------|
| 1 | [TBD] | ? | ? | ? | ? | ? | ? | |
| 2 | [TBD] | ? | ? | ? | ? | ? | ? | |
| 3 | | | | | | | | |
| 4 | | | | | | | | |
| 5 | | | | | | | | |

**Selected Primary:** [TO BE FILLED — Task 1.3]
**Selected Backup:** [TO BE FILLED — Task 1.3]

---

## Part 7: Architecture Summaries

*(To be populated during Task 2.1 for Primary, Task 4.3 for Backup if needed)*

### [Primary Candidate Name]

- **Contract addresses:**
- **Shared sequencer/preconf layer:**
- **PEFO condition instantiation:**
  - Condition 1 (shared STF boundary): [contract / function]
  - Condition 2 (independent execution): [contract / function]
  - Condition 3 (lazy sequencer): [commitment structure reference]
- **3–4 mainnet-distinguishing architectural facts (for §4.4.3):**
  1.
  2.
  3.
  4.
- **Vendor contact channels:**
  - security@ email:
  - Founder/CTO DM:
  - Discord/forum:
- **Testnet URL:**
- **Testnet faucet:**

### [Backup Candidate Name]

*(To be filled if Primary fails Task 4.1 Week 8 checkpoint)*

- **Contract addresses:**
- **Shared sequencer/preconf layer:**
- **PEFO condition instantiation:**
  - Condition 1:
  - Condition 2:
  - Condition 3:
- **Vendor contact channels:**
- **Testnet URL:**
