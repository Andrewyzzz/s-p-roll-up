# Candidate Viability Assessment v1

**Task:** 1.3 — Candidate viability assessment
**Status:** v1.0 — initial assessment (2026-05-28)
**Input:** survey_results_v2.md + live documentation research
**Output:** Ranked candidates, selected Primary + Backup

---

## Critical New Evidence: Second A2/A4 Conflation Instance

During candidate research, the Astria main repository README was found to claim:

> "Atomic cross-rollup composability"
> — github.com/astriaorg/astria README

Yet technical documentation (confirmed live) states:

> "provides a guarantee on the ordering of transactions in a block, but it
> doesn't execute the state transition function (STF) of any given rollup"
> — docs.astria.org

This is the second production A2/A4 conflation instance alongside mev-commit's
"Atomicity and Execution Guarantees." Both motivate §1 Introduction. Both also
confirm that the conflation exists at the **infrastructure provider** level,
not just at the application layer.

Paper impact: §1 Introduction should cite both Astria README and mev-commit
marketing page as motivating instances of the conflation.

---

## Part 1: Two-Track Candidate Structure

The paper's §4 has two distinct demonstration targets:

**Track A — §4.1 PEFO Structural Demonstration (Astria devnet testbed):**
Uses a research-constructed cross-rollup intent filler on Astria devnet.
This is NOT a third-party application — it is the research team's own
testbed application demonstrating PEFO conditions in a framework-deployed
setting. **This track is independent of third-party candidate selection.**

**Track B — §4.4 [DEPLOYED_APP] Coordinated Disclosure:**
Requires a real third-party deployed application on a shared sequencer
testnet/mainnet. This is the candidate selection target for Task 1.3.

---

## Part 2: Track B Candidate Assessment

### Primary Candidate Evaluation Criteria

For §4.4, the candidate needs:
1. TF-1/2/3 PASS (from survey)
2. Testnet accessible with a faucet
3. Contracts verified (or source available)
4. Vendor has a security contact
5. TVL or usage sufficient to demonstrate mainnet applicability (§4.4.3)

### Candidate B1: Application on Astria + Second Astria-Sequenced Rollup

**Architecture:** An application deployed on Astria's Flame chain AND a
second Astria-sequenced rollup, where the application makes cross-rollup
assumptions that both operations in the same meta block succeed together.

**Filter assessment:**
- TF-1: PASS (Flame + second rollup both in Astria meta block)
- TF-2: PASS (independent execution legs, no message relay)
- TF-3: PASS (Astria lazy sequencer confirmed)
- AX-4: Application-dependent — must not have HTLC/escrow on the cross-rollup leg

**Ecosystem status:**
- Astria Mainnet Alpha: Flame (EVM chain) confirmed live
- Second Astria-sequenced production rollup: **not yet publicly identified**
  in documentation (as of 2026-05-28 research pass)
- Astria testnet (Dawn): Multiple rollup namespaces supported per charts repo
  (`just deploy rollup <name> <id>`)

**Vendor contact:**
- Security contact: security@astria.org (standard; to be confirmed)
- GitHub: github.com/astriaorg
- Discord: discord.gg/astria

**Viability:** HIGH for the devnet testbed (§4.1), MEDIUM for §4.4 until
a second production rollup with a deployed cross-rollup application is
identified.

**Action required (Task 2.1 / pre-Week 4):**
- Contact Astria team: "Which applications are deployed on both Flame and
  a second Astria-sequenced chain? Is there a testnet with two rollup
  namespaces and a deployed DeFi application?"
- Check Astria Discord for community applications in progress

---

### Candidate B2: Application on Espresso-Sequenced Rollup Pair

**Architecture:** An application deployed on two Espresso-sequenced rollups,
assuming cross-rollup consistency.

**Filter assessment:**
- TF-1: CONDITIONAL PASS (Espresso HotShot sequences multiple rollups)
- TF-2: Application-dependent
- TF-3: UNCLEAR — depends on whether HotShot attests to execution outcomes
  in its commitment. This is the critical open question for Espresso.
- AX-4: Application-dependent

**Key open question for TF-3:** Does Espresso's HotShot provide a *joint*
execution attestation for multi-rollup bundles? If yes → TF-3 FAIL (it's
capability (i)). If no → TF-3 PASS.

**Vendor contact:**
- GitHub: github.com/EspressoSystems
- Discord: discord.gg/espresso-systems
- Security: security@espressosys.com

**Viability:** MEDIUM — gated on TF-3 confirmation.

**Action required (Task 2.3):**
- Read Espresso HotShot source code for execution attestation scope
- Specifically: does `sequencer_client::SequencerBlock` include an execution
  outcome predicate for multiple rollup namespaces jointly?

---

### Candidate B3: Based Rollup Application (Taiko + Second Based Rollup)

**Architecture:** An application on Taiko (based rollup using Ethereum L1
validators as sequencer) + a second based rollup sharing the same L1 block.

**Filter assessment:**
- TF-1: PASS — both rollups' transactions appear in the same L1 block,
  which is the shared commitment
- TF-2: Application-dependent — must use independent on-rollup execution
  rather than cross-rollup messaging
- TF-3: PASS — L1 validators are lazy (commit to inclusion in the block,
  do not execute rollup STFs before committing)
- AX-4: Application-dependent

**Key distinction from Astria:** In the based rollup case, the "shared
sequencer" is the L1 block itself. Two based rollup transactions in the
same L1 block form the PEFO bundle. The attacker observes execution of
τ₁ on Rollup A (Taiko) and intervenes before τ₂ on Rollup B.

**Ecosystem status:**
- Taiko: Production mainnet ($127M+ TVL as of 2025)
- Second based rollup alongside Taiko: Limited options in production
- Testnet: Taiko Hekla testnet

**Vendor contact:**
- Taiko: security@taiko.xyz, Discord discord.gg/taikoxyz
- GitHub: github.com/taikoxyz

**Viability:** MEDIUM — requires finding a second production based rollup
with an application that makes cross-rollup assumptions.

---

### Candidate B4: Radius Encrypted Sequencing Application

**Architecture:** Application on a Radius-sequenced rollup pair.

**Filter assessment:**
- TF-1: CONDITIONAL PASS
- TF-3: UNCLEAR — Radius uses encrypted sequencing; the commitment may
  include decryption/execution proof. Requires documentation review.

**Documentation status:** Radius docs were inaccessible during survey
(connection refused on theradius.xyz subdomain). Manual review required.

**Viability:** LOW — documentation inaccessible; hard to assess.

---

## Part 3: Selection Decision

### Primary Candidate: Astria Intent Filler (Devnet Testbed + Testnet Target)

**Rationale:**
1. Platform TF-1/TF-3 confirmed with verbatim documentation
2. Dev infrastructure available (astriaorg/charts, `astria-go` CLI)
3. Astria team has history of engaging with researchers (public GitHub, Discord)
4. The §4.1 devnet testbed and the §4.4 application target can share the same
   platform — reducing engineering overhead
5. Astria's own README conflation claim ("Atomic cross-rollup composability")
   provides a natural motivating hook for the disclosure

**§4.1 testbed plan:**
- Deploy two rollup namespaces on Astria devnet using `astriaorg/charts`
- Implement a minimal cross-rollup intent filler contract on each namespace
- Demonstrate PEFO: filler submits fill txs to both namespaces in same meta
  block; attacker observes τ₁ success, causes τ₂ failure
- Fully within research control; no third-party vendor dependency

**§4.4 target:**
- Identify an application deployed (or imminently deploying) on Flame +
  second Astria rollup, OR construct a minimal reference implementation
  that mirrors a real cross-rollup DeFi pattern on Astria testnet
- This path requires Task 2.1 architecture analysis + Week 6 vendor outreach

### Backup Candidate: Espresso Ecosystem Application

If Astria §4.4 path fails (no suitable deployed application found), switch to:
- Espresso-sequenced rollup pair application
- Requires resolving TF-3 question (HotShot execution attestation scope)
- Action trigger: Week 8 abort checkpoint (Task 4.1)

---

## Part 4: Additional Conflation Evidence Inventory

For §1 Introduction and §2 Taxonomy motivating examples:

| Source | Claim | Technical reality | Paper use |
|--------|-------|-------------------|-----------|
| primev.xyz | "Atomicity and Execution Guarantees" | bid has `revertingTxHashes`; slashing is for positioning, not execution outcome | §1 motivating example A |
| github.com/astriaorg/astria README | "Atomic cross-rollup composability" | lazy sequencer, no STF execution, no joint execution predicate | §1 motivating example B |
| [To confirm] Espresso marketing | [search for "atomic" claims] | TBD — docs largely 404 | §1 potential example C |

---

## Part 5: Action Items for Tasks 2.1 / 2.3

**Before Week 4 architecture analysis:**

1. `[ ]` Contact Astria Discord / GitHub Issues: identify any cross-rollup
   application deployed on Flame + second rollup (or building toward this)
2. `[ ]` Clone `astriaorg/charts` and verify `just deploy rollup` creates
   distinct namespace rollups in same sequencer cluster
3. `[ ]` Read Espresso HotShot source: check whether `SequencerBlock` contains
   execution outcome predicate covering multiple rollup namespaces
4. `[ ]` Check Taiko ecosystem for cross-rollup applications with a second
   based rollup
5. `[ ]` Confirm Astria security contact (security@astria.org)

**Vendor responsiveness assessment:**
- Astria: public GitHub, active Discord, academic-friendly (open source first)
  → responsiveness estimated HIGH
- Espresso: similar profile → estimated MEDIUM-HIGH
- Taiko: large team, active bug bounty → estimated MEDIUM

---

## Part 6: Candidate Tracking Table (Final)

| # | Candidate | TF-1 | TF-2 | TF-3 | AX-4 | Testnet | Vendor | Priority |
|---|-----------|------|------|------|------|---------|--------|----------|
| 1 | Astria devnet intent filler (§4.1) | PASS | PASS | PASS | N/A (research app) | Yes | Astria team | **§4.1 PRIMARY** |
| 2 | Astria Flame + second rollup app (§4.4) | COND PASS | App-dep | PASS | App-dep | Yes (testnet) | Astria team | **§4.4 PRIMARY** |
| 3 | Espresso ecosystem app | COND PASS | App-dep | UNCLEAR | App-dep | Yes (testnet) | Espresso team | §4.4 BACKUP |
| 4 | Based rollup (Taiko + partner) | PASS | App-dep | PASS | App-dep | Yes (Hekla) | Taiko team | §4.4 ALT BACKUP |
| 5 | Radius ecosystem | UNCLEAR | UNCLEAR | UNCLEAR | UNCLEAR | Unknown | Radius team | LOW |

**Selected §4.1:** Astria devnet intent filler (research-constructed)
**Selected §4.4 Primary:** Astria Flame + second rollup application
**Selected §4.4 Backup:** Espresso ecosystem application
