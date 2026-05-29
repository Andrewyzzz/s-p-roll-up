# Delta vs Prior Work — Written Dead
## Version 2 (2026-05-29) — updated after reviewer pressure-test

This file is the canonical novelty firewall. Every reviewer who asks
"isn't this covered by X?" gets answered here. Do NOT soften these deltas.

---

## vs "Practical Limitations on Forced Inclusion" and similar DeFi-censorship blogs
### (THE most dangerous prior-art overlap — must be addressed explicitly)

**What those blogs say**: Force-inclusion is impractical / not enough to
protect Aave/Compound positions. A censoring sequencer can block a borrower's
repayment and allow their position to be liquidated. Users effectively cannot
rely on force-inclusion for DeFi self-rescue.

**Why this matters**: The *qualitative* claim that "force-inclusion doesn't
protect DeFi positions" predates this paper. If we only repeat that claim,
we add nothing.

**What we do that they do not**:

1. **Mechanism decomposition, not just complaint.**
   Prior blogs label the outcome ("it doesn't work") without decomposing
   *why* it fails or *how* the failure varies across chains. We prove
   that the failure has two structurally distinct modes:
   - *Delay-window attack* (OP Stack / most chains): the 12 h sequencing
     window lets adversary act in preceding blocks before rescue lands.
   - *Ordering-freedom attack* (Arbitrum): even after force-inclusion,
     the sequencer retains ordering latitude within batches.
   These are different failure modes requiring different defenses.

2. **First empirical cross-chain survey.**
   We classify 10 deployed L2s against a four-dimensional rubric
   (enforcement mechanism / delay window / ordering constraint /
   proposer finality). Blogs treat "escape hatch" as binary;
   we show it is not — and that the failure spectrum spans
   fully decorative (zkSync Era, StarkNet) to mechanically enforced
   but still exploitable (OP Stack, Arbitrum).

3. **Mechanized demonstration on real deployed state.**
   We execute the attack on a real Base fork with real AaveOracle,
   real Chainlink feeds (addresses discovered at runtime), and
   cast-verified Aave V3 parameters. The prior blogs are qualitative;
   we provide end-to-end PoC with measured adversary profit.

4. **L2BEAT binary-checkbox critique.**
   L2BEAT and similar frameworks score "escape hatch: yes/no" and
   "delay: X hours". They capture neither the ordering-freedom dimension
   nor the fact that a *functionally present* escape hatch can still
   fail to protect time-sensitive outcomes. We show the rubric is
   misleading for DeFi users, and propose a replacement taxonomy.

5. **Defense.**
   Prior blogs identify the problem and stop. We prototype an
   application-layer defense (lending protocol checks for pending
   forced deposits before clearing a liquidation) and measure its
   overhead. We also sketch the L2-layer hardening required for
   full protection.

**Key sentence for Related Work**: *Prior work observes that force-inclusion
is insufficient for DeFi self-rescue; we prove the two structural mechanisms
by which it fails, measure failure rates across 10 deployed L2s, and
demonstrate the attack end-to-end on real deployed state — contributions
absent from descriptive commentary.*

---

## vs L2BEAT / Quantstamp Security Frameworks

**What they do**: Qualitative documentation-based scoring — "does an
escape hatch exist?", "how long is the delay?". Binary yes/no per category.

**What we do differently**:
1. **Empirical functional testing**, not doc-reading. We call contracts,
   trace on-chain behavior, identify chains where the mechanism exists in
   code but fails at runtime boundaries.
2. **Reveal the inclusion ≠ outcome gap** their scoring cannot capture:
   even a "functional" (by their rubric) force-inclusion mechanism leaves
   victims exposed to adversarial ordering. Their rubric has no column for
   "ordering constraints after inclusion" or "proposer finality guarantee."
3. **Quantify the attack surface**: measured TVL in attackable positions.

**Key sentence**: *L2BEAT and Quantstamp tell you whether the escape hatch
door exists; we tell you whether walking through it actually gets you out —
and show it does not for N of the 10 largest deployed L2s.*

---

## vs arXiv 2502.20334 "Economic Censorship Games in Fraud Proofs"

**What they do**: Game-theoretic analysis of bribery attacks at the
**fraud-proof challenge layer** — adversary bribes block proposers to
exclude honest challengers' dispute steps. Pure theory, no deployed system
measurement.

**What we do differently**:
1. **Different layer**: We attack the **sequencer ordering / inclusion
   layer**, not the fraud-proof challenge layer. Our adversary has
   sequencer power; theirs has proposer-bribery budgets.
2. **Empirical, not pure theory**: Deployed L2 measurement + mainnet fork PoC.
3. **Different victim mechanism**: Force-inclusion is supposed to bypass
   the sequencer; our attack shows it doesn't bypass *ordering* even when
   it bypasses *exclusion*.
4. **Defense prototyped**: We provide a concrete application-layer fix;
   they provide game-theoretic bounds.

**Complementarity, not duplication**: arXiv 2502 attacks the
challenge-game layer *assuming the sequencer is already honest*; we attack
the sequencer's residual ordering power that *survives* force-inclusion.
The two papers study different failure modes of the same broad class of
L2 censorship-resistance mechanisms.

**Key sentence**: *arXiv 2502 attacks the challenge-game layer with bribery
budgets; we attack the sequencer's ordering power that persists after
force-inclusion, on deployed systems, with empirical measurement.*

---

## vs Our Own Prior Rollup Paper (s-p-roll-up)

**What that paper did**: Introduced the inclusion ≠ execution-outcome
taxonomy (A0–A4) in the context of rollup preconfirmation sequencing
commitments; demonstrated PEO and PEFO attacks on cross-rollup bundles;
theoretical lower bounds on violation rates.

**Relationship**:
- **Concept reuse (explicit)**: The A1 vs A2 distinction (inclusion
  guarantee vs execution-outcome guarantee) is the same lens. We cite it
  explicitly and say "we apply this lens to a different mechanism."
- **Genre switch**: Prior paper was economic theory + cross-rollup bundles.
  This paper is empirical survey + single-L2 attack + deployed system
  measurement.
- **Mechanism switch**: Prior paper targets *preconfirmation commitments*;
  this paper targets *force-inclusion / escape-hatch* — a different
  deployed mechanism with a different victim population (all L2 DeFi users,
  not just preconf users).
- **No double-publication**: Different mechanism, different contribution
  claims, complementary not duplicative.

**Key sentence**: *We reuse the inclusion ≠ outcome lens as a conceptual
tool, not as a contribution — the contribution is applying it to
force-inclusion empirically, across 10 deployed L2s, with a concrete
attack and defense.*

---

## Summary Table

| Prior Work | Layer | Method | Our Delta |
|-----------|-------|--------|-----------|
| DeFi-censorship blogs | UX/outcome | Qualitative observation | Mechanism decomposition; cross-chain survey; PoC on real state; defense |
| L2BEAT/Quantstamp | Documentation | Qualitative binary scoring | Contract-level testing; ordering dimension; TVL at risk |
| arXiv 2502.20334 | Fraud-proof challenge | Pure game theory | Sequencer layer; empirical; deployed systems; defense |
| Our prior rollup paper | Preconfirmation | Economic theory + cross-rollup | Same lens; different mechanism; empirical survey + attack + defense |

---

## Claims this paper does NOT make (write explicitly in §1)

- We do not claim Aave V3 has a bug. It behaves correctly throughout.
- We do not claim real losses have occurred (no confirmed real-world attack).
- We do not claim L1 censorship is present (L1 is assumed censorship-resistant).
- We do not claim all L2s are equally vulnerable (classification shows the spectrum).
- We do not claim the attack is novel as a DeFi observation — only as a
  mechanized cross-chain measurement with demonstrated exploit and defense.
