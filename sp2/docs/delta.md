# Delta vs Prior Work — Written Dead

This file is the canonical "novelty firewall". Every reviewer who asks "isn't this covered by X?" gets answered here. Do not soften these deltas.

---

## vs L2BEAT / Quantstamp Security Frameworks

**What they do**: Qualitative documentation-based scoring — "does an escape hatch exist?", "how long is the delay?". Produce risk ratings from docs and audits.

**What we do differently**:
1. **Empirical functional testing**, not doc-reading. We call contracts, trace on-chain behavior, and identify cases where the mechanism exists in code but fails at runtime boundaries.
2. **Reveal the inclusion≠outcome gap** their scoring cannot capture: even a "functional" (by their rubric) force-inclusion mechanism leaves victims exposed to adversarial ordering. Their rubric has no column for "ordering constraints after inclusion."
3. **Quantify the attack surface**: $X TVL in positions where this matters.

**Key sentence**: *L2BEAT and Quantstamp tell you whether the escape hatch door exists; we tell you whether walking through it actually gets you out.*

---

## vs "Hidden Tax" / Impracticality Blogs (Gate Learn, ChainsScore, etc.)

**What they say**: Force-inclusion is impractical because it's expensive (user must construct raw tx, pay high gas), slow (24h delay), and difficult (requires L1 interaction). It's a "hidden tax" or "theoretical right."

**What we do differently**:
1. **Different and stronger failure mode**: We prove that *even if force-inclusion were free and instant*, a rational adversarial sequencer can still make the victim's outcome fail via ordering control. The cost/impracticality argument is orthogonal — we don't contest it, we show there's a deeper structural problem *underneath* it.
2. **Formal attack + measurement + defense**, not qualitative commentary.
3. We cite these blogs as *motivation* (confirming the mechanism is rarely used), not as prior work with overlap.

**Key sentence**: *Prior work argues force-inclusion is impractical; we argue it's structurally insufficient — even a perfect force-inclusion mechanism leaves a sequencer ordering attack surface.*

---

## vs arXiv 2502.20334 "Economic Censorship Games in Fraud Proofs"

**What they do**: Game-theoretic analysis of bribery attacks at the **fraud-proof challenge layer** — adversary bribes block proposers to exclude honest challengers' dispute steps. Pure theory, no deployed system measurement.

**What we do differently**:
1. **Different layer**: We attack the **sequencer ordering / inclusion layer**, not the fraud-proof challenge layer. Our adversary has sequencer power, not proposer bribery budgets.
2. **Empirical, not pure theory**: Deployed L2 measurement + mainnet fork PoC.
3. **Different victim mechanism**: Force-inclusion is supposed to bypass the sequencer; our attack shows it doesn't bypass *ordering* even when it bypasses *exclusion*.
4. **Defense prototyped**: We provide a concrete fix; they provide game-theoretic bounds.

**Key sentence**: *arXiv 2502 attacks the challenge-game layer assuming the sequencer is already honest; we attack the sequencer's residual ordering power that survives force-inclusion.*

---

## vs Our Own Prior Rollup Paper (s-p-roll-up)

**What that paper did**: Introduced the inclusion≠execution-outcome taxonomy (A0–A4) in the context of rollup preconfirmation sequencing commitments; demonstrated PEO and PEFO attacks on cross-rollup bundles; theoretical lower bounds on violation rates.

**Relationship**:
- **Concept reuse (explicit)**: The A1 vs A2 distinction (inclusion guarantee vs execution-outcome guarantee) is the same lens. We cite it explicitly and say "we apply this lens to a different mechanism."
- **Genre switch**: Prior paper was economic theory + cross-rollup bundles. This paper is empirical survey + single-L2 attack + deployed system measurement — the S&P genre.
- **Mechanism switch**: Prior paper targets *preconfirmation commitments*; this paper targets *force-inclusion / escape-hatch* — a different deployed mechanism with a different victim population (anyone using L2 DeFi, not just preconf users).
- **No double-publication**: Different mechanism, different contribution claims, complementary not duplicative.

**Key sentence**: *We reuse the inclusion≠outcome lens as a conceptual tool, not as a contribution — the contribution is applying it to force-inclusion empirically, finding N decorative implementations, and demonstrating a concrete attack on a victim-dense mechanism.*

---

## Summary Table

| Prior Work | Layer | Method | Our Delta |
|-----------|-------|--------|-----------|
| L2BEAT/Quantstamp | Documentation | Qualitative scoring | Contract-level testing; reveals inclusion≠outcome gap their rubric misses |
| Cost/impracticality blogs | UX | Qualitative | Structural failure even if FI were free+instant |
| arXiv 2502.20334 | Fraud-proof challenge | Pure game theory | Sequencer layer; empirical; deployed systems; defense |
| Our prior rollup paper | Preconfirmation | Economic theory + cross-rollup | Same lens; different mechanism; empirical survey + attack + defense |
