# v8.A-final 最终大纲

**文档定位：** 本文档是 v8.A-pragmatic 整合漏洞 1/2/3/5 修订后的最终版本，作为 11
个月开发周期的执行基线。所有进一步修订仅在 evidence-driven trigger 下进行（Week 4–5
architectural analysis、Week 6–8 vendor signals、Week 10–11 disclosure response）。

**核心声明：** 本文档之后不再 iterate outline。设计层面的探索到此结束。

**Locked:** 2026-05-28

---

## 标题

**主标题：**

> **Atomic Inclusion Is Not Atomic Execution: Free Options in Rollup Sequencing
> Commitments**

**短标题（running header）：** *Free Options in Rollup Sequencing Commitments*

---

## Abstract

> Rollup sequencing commitments — issued by shared sequencers and preconfirmation
> layers — are commonly described as providing "atomicity." We show this term
> conflates two distinct properties: **atomic execution** (all bundle legs succeed
> or none do) and **economic atomicity** (no party extracts option value from the
> sequencing gap). Compensation-based mechanisms — bonds, slashing, insurance —
> close the latter but provably cannot close the former. Any *deterministic*
> protocol providing atomic execution over independent state transition functions
> must provide at least one of two operational capabilities: pre-execution
> success-predicate evidence, or authority to prevent partial irreversible effects.
> Probabilistic and cryptoeconomic guarantees, including restaking and relay
> attestation, do not provide either; they are A4 mechanisms, not A2 mechanisms.
> We demonstrate the resulting *free options* through two attack families —
> **Preconfirmation Exercise Option** (PEO) on a production preconfirmation
> reference implementation, and **Partial-Execution Free Option** (PEFO) including
> a coordinated-disclosure demonstration on [DEPLOYED_APP]'s testnet — and bound
> option value through a 12-month counterfactual replay over Optimism, Base,
> Arbitrum, and Polygon zkEVM, calibrated to empirically estimated power-law tail
> behavior.

---

## Thesis

> "Atomicity" in rollup sequencing literature conflates execution outcome with
> economic externality; compensation and probabilistic mechanisms address the
> latter and provably cannot address the former, leaving a structural gap that
> admits free-option attacks demonstrable on deployed substrates and a production
> cross-rollup application's architecture.

---

## 四条 Contribution

1. **A five-layer atomicity taxonomy and the A2/A4 separation.** A0 (common
   ordering) → A4 (economic atomicity, operationalized as counterfactual payoff
   bound). "Atomicity" as commonly used conflates A2 (execution outcome) and A4
   (economic externality), with distinct closure mechanisms. Deterministic
   mechanisms close A2 under restricted operational conditions; compensation and
   probabilistic mechanisms close A4 but provably cannot close A2. This separation
   is distinguished from atomic-commit / sagas / cross-chain-swap literature (§10).

2. **Two attack families demonstrating non-vacuity of the structural gap.** PEO on
   a production preconfirmation reference implementation with concrete bond-violation
   economics; PEFO demonstrated as (a) structural condition over A0/A1 substrates,
   (b) testbed exploit on Astria devnet, and (c) coordinated-disclosure
   demonstration on [DEPLOYED_APP]'s testnet with detailed mainnet-applicability
   analysis based on public contracts.

3. **Scoped lower bounds.**
   - **Theorem 1** (A2 necessary capability): Any deterministic protocol guaranteeing
     A2 over independent STFs must provide pre-execution evidence OR partial-effect
     prevention. Probabilistic/cryptoeconomic guarantees provide neither and are A4
     mechanisms.
   - **Theorem 2** (A4 calibrated bound): Under empirically estimated power-law tail
     of crypto-market option value, finite bond B admits violation rate bounded
     below by $\rho_{\min}(\hat{\alpha}, B_{\max}, w) \geq$ [X%] over 12-month
     aggregate window.

4. **Measurement study with three evidence types.** Real-stack timing (α);
   fault-injected PoC (α); 12-month counterfactual replay over OP/Base/Arbitrum/
   Polygon zkEVM (β) with tail-index estimation, reactive-market sensitivity
   analysis, and explicit negative-case reporting.

---

## 大纲（11 节，目标 12.7 页 IEEE 双栏）

### Section 1 — Introduction（1.4 页）

1. What sequencing commitments are
2. What they don't provide
3. The conflation thesis (A2 ≠ A4)
4. Differentiation from arXiv 2410.11552 + Sagas/Herlihy/Gray-Lamport
5. Contributions + roadmap + PEO + [DEPLOYED_APP] teaser

### Section 2 — Atomicity Taxonomy and System Model（2.0 页）

**2.1 The five layers** (A0–A4 table)

**2.2 The A2–A4 separation** (preview of Theorems 1 + 2)

**2.3 Deployed system mapping** (Astria/Espresso/Radius/Preconf vendors × A0–A4)

**2.4 The integration gap** (counterfactual framing, application survey reference)

**2.5 System and threat model**
- Lazy sequencer (main attack target)
- Preconfirmation
- **Determinism scope**: Theorem 1 applies to deterministic protocols
- **Irreversibility definition (v8 new)**: "first protocol-internal point of no undo"
- Adversary classes
- Out of scope
- Evidence types: α/β/γ/δ

### Section 3 — Attack 1: PEO（1.8 页，权重 25%）

**3.1 Setup**
**3.2 The option structure** ($\Delta\Pi$ formula)
**3.3 Regimes where option is positive**
**3.4 Concrete worked example** (reference preconfer impl)
**3.5 Measurement summary** (→ §5)
**3.6 Why this is a system security problem**

### Section 4 — Attack 2: PEFO（2.1 页，权重 30%）

**4.1 Concrete instance: cross-rollup intent filler**

**4.2 Structural condition** (3 conditions)

**4.3 PEFO as Theorem 1 negation** (含 Across/UniswapX/HTLC mapping)

**4.4 Demonstration on deployed-app architecture: [DEPLOYED_APP]**
- **4.4.1** Target selection and architecture analysis (vendor-independent)
- **4.4.2** Testnet exploit (PoC-dependent)
- **4.4.3** Mainnet applicability analysis (author-driven, vendor-framing-adjusted)
- **4.4.4** Coordinated disclosure and vendor response (vendor-dependent, 6 case prepared)

**4.5 What this section claims and does not claim** (pre-emptive calibration)

### Section 5 — Measurement Study（2.0 页，权重 15%）

**5.1 Real-stack timing (α)**

**5.2 Fault-injected PoC (α)**

**5.3 Mainnet counterfactual replay (β)**
- **5.3.1** Tail-index estimation (Hill + ML + threshold sensitivity)
- **5.3.2** Reactive-market sensitivity (θ-fraction price impact)

**5.4 Empirical verification of A4 operational definition**

**5.5 What we don't claim**

### Section 6 — Lower Bounds（1.5 页，权重 12%）

**6.1 Theorem 1 — Necessary Capability for Deterministic A2**
- Merged from v7 Theorem 1 + 2
- Weakened from dichotomy to necessary-condition
- Explicit determinism scope statement (排除 probabilistic/cryptoeconomic)
- Proof in main text (~0.4 页, contrapositive)

**6.2 Observation 1 — Capability classification**
- (i) Pre-execution evidence
- (ii) Partial-effect prevention
- (hybrid i+ii): Shutter-style threshold encryption
- A4 only (not A2): bonds, restaking, MEV-Boost attestation
- Boundary cases reference Appendix A

**6.3 Theorem 2 — Calibrated Bond Insufficiency**
- Power-law tail with empirical $\hat{\alpha}$
- $\rho_{\min}(\hat{\alpha}, B_{\max}, w, \lambda, L)$
- Proof in main text (~0.3 页)

**6.4 Corollary — Empirical violation rate**

### Section 7 — Theorem 1 as a Design-Space Map（0.9 页，权重 8%）

Framework-validation table:
- Across (ii) + UniswapX (ii)+A4 + HTLC (ii) + Espresso execution-attest (i) +
  Astria escrow (ii) + Bonded preconf (A4 only) + ZK proof gating (i) +
  Shutter (hybrid) + EigenLayer (A4 only) + MEV-Boost (A4 only)

Closing claim: every surveyed mitigation instantiates (i), (ii), or A4-only.

### Section 8 — Responsible Disclosure（0.4 页）

**8.1 Disclosure scope** (4 vendor categories with $D_1, D_2, D_3$)

**8.2 Disclosure rationale**

**8.3 Vendor responses summary**

**8.4 SHA-256 commitment + per-attempt OpenTimestamps + git commit timing**

**8.5 Fallback statement**

### Section 9 — Discussion（0.4 页）

- Generalization to based rollups
- Eager sequencing
- A2/A4 separation for specification
- Future work: EIP-7702 analogy

### Section 10 — Related Work（0.8 页）

1. Classical atomic commitment (Gray, Garcia-Molina, Herlihy)
2. arXiv 2410.11552
3. CCS 2025 Denial of Sequencing
4. ethresear.ch preconfirmation taxonomies
5. Unity is Strength (Obadia et al.)
6. Flashbots cross-rollup arbitrage proposals
7. EigenLayer restaking
8. L1 MEV literature
9. Smart contract analysis

### Appendix

- **A.** Theorem 1 boundary cases (Shutter / EigenLayer / MEV-Boost /
  Across UMA full classification)
- **A.4.** Theorem 2 power-law derivation
- **B.** PoC code listings (PEO, PEFO testbed, [DEPLOYED_APP] testnet exploit)
- **C.** Application survey: codebook, IRR, results
- **D.** Measurement methodology
- **E.** Disclosure timeline + vendor correspondence + per-attempt OpenTimestamps
  proofs
- **F.** Ethics statement

---

## 漏洞修订 Summary（v8.A → v8.A-final）

| 漏洞 | 修订 | 位置 |
|---|---|---|
| 1: Week 6 abort timing | Week 6 = candidate switch checkpoint, Week 8 = soft abort, Week 10 = formal disclosure launch | TODO list |
| 2: PoC failure case | New Case 6: PoC reveals mitigation → reframe as positive finding for §7 design-space map | §4.4 populate scheme |
| 3: Disagree case scope dispute | Add structural-not-normative claim in §4.5; reframe disagreement as "industry-wide open question" linking to §9 | §4.4.4 + §4.5 |
| 5: SHA-256 timing | Per-attempt OpenTimestamps + git commit, not only submission-time aggregator | §8.4 + TODO list |
| 4: Candidate list | Thesis-fit filter (3 criteria) mandated before architecture analysis | TODO list |

---

## Critical Path Summary

### 三个里程碑

| 里程碑 | Week | Definition | If miss |
|---|---|---|---|
| **里程碑 1**: PEO real PoC | Week 6 | PEO on selected preconfer impl works end-to-end | Project quality significantly degraded; consider 抽换 preconfer choice |
| **里程碑 2a**: PEFO testnet exploit | Week 10 | PEFO exploit on [DEPLOYED_APP]'s testnet works | Trigger Case 6 (positive finding reframing) |
| **里程碑 2b**: $\hat{\alpha}$ + $\rho_{\min}$ | Week 16 | Tail-index estimation calibrated + Theorem 2 bound computed | $\rho_{\min}$ headline claim collapses → reduce paper to qualitative claim |
| **里程碑 3**: Disclosure response | Week 23 | $D_3 + 90$ days completed, vendor case determined | Populate Case 2 (ghost) — graceful degrade |

### 三个 Hard Decision Points

| Decision | Week | Question | Action |
|---|---|---|---|
| **Week 8 Abort Checkpoint** | Week 8 | Does any vendor show substantive engagement? | If yes: continue Option A. If no after follow-ups: switch backup. If all backups fail: Option B (remove §4.4) |
| **Week 11 Formal Disclosure** | Week 11 | Is vendor relationship strong enough to launch formal disclosure? | Yes: launch + 90-day clock starts. No: Option B path |
| **Week 16 Theorem 2 Calibration** | Week 16 | Does $\rho_{\min}$ confidence interval exclude 0? | Yes: Theorem 2 stands. No: reduce Theorem 2 to qualitative claim, weight on Theorem 1 + attack PoCs |

### Evidence-Driven Outline Revision Triggers

本文档之后不再对 outline 进行修订。下次 outline-level 修改的 trigger 必须是：

1. Week 4–5 architectural analysis 发现 candidate unsuitable → re-select
2. Week 6–8 vendor signals require specific framing adjustment → minor §4.4 patch
3. Week 10–11 formal disclosure response → §4.4.4 case-specific populate
4. Week 16 $\hat{\alpha}$ data → Theorem 2 statement might need adjustment

任何**非 evidence-driven** 的 outline 修订要求，拒绝回应。

---

*Locked 2026-05-28. Next scheduled revision: Week 25 reviewer feedback.*
