# Research Outline — "Included but Not Saved"
## Version: v1 (2026-05-29) — LOCKED until kill-switch passes

---

## Paper Structure (~13 pages, IEEE double-column)

### §1 Introduction (~1.5p)
- Hook: L2 force-inclusion as the "last guarantee" — widely marketed, rarely scrutinized
- Two failure modes: decorative implementation + structural inclusion≠outcome gap
- Threat model, victim profile, contributions summary
- Key finding preview (N decorative out of 10; attack demonstrated on K L2s; $X TVL at risk)

### §2 Background & Threat Model (~1p)
- L2 sequencer architecture: sequencer → delayed inbox / portal → L1
- Force-inclusion mechanics: deposit tx, delayed inbox, escape hatch
- Threat model formalization: adversarial sequencer, honest victim, scope boundaries

### §3 Taxonomy: Inclusion vs Outcome (~1p)
- **This is the lens from the prior rollup paper, repurposed**
- A1: Ordering guarantees (sequencer can include)
- A2: Execution atomicity (outcome matches intent)
- Force-inclusion achieves A1 but does NOT guarantee A2
- Why compensation/bonds don't close the A2 gap here either

### §4 Empirical Survey of Deployed L2s (C1) (~2.5p)
- Methodology: contract-level audit vs documentation claims
- Classification rubric: functional / decorative / economically-infeasible
- Per-L2 findings table (10 L2s)
- Key finding: N implementations are decorative or boundary-unenforced

### §5 The "Inclusion Without Outcome" Attack (C2) (~2.5p)
- Attack scenario: victim's self-rescue vs adversarial sequencer front-running
- Arbitrum fork PoC: DelayedInbox, 24h window, lending liquidation scenario
- OP Stack fork PoC: OptimismPortal.depositTransaction(), same scenario
- Quantified: adversary gain, victim loss, gas cost

### §6 Exposure Measurement (C3) (~1.5p)
- Methodology: on-chain TVL analysis, position classification
- Historical force-inclusion call counts (≈0 — finding in itself)
- Per-L2 attack window analysis: what adversary can do within the window
- Aggregate: $X TVL in attackable positions across affected L2s

### §7 Defenses (C4) (~1.5p)
- Defense space analysis: why naive approaches fail
- Atomic FI bundle prototype: conditional revert on bad outcome
- Gas overhead measurement
- FI-bench: reusable robustness test suite (ecosystem contribution)

### §8 Related Work (~0.75p)
- L2BEAT / Quantstamp — delta written dead
- "Hidden tax" / cost blogs — delta written dead
- arXiv 2502.20334 — delta written dead
- Prior rollup preconfirmation work — delta written dead

### §9 Discussion (~0.5p)
- Generalizability beyond tested L2s
- Responsible disclosure status
- Limitations

### §10 Conclusion (~0.25p)

---

## Kill-Switch Gates

### Gate 1 (End of Week 3) — GO / NO-GO
- [ ] At least 1 L2 with decorative/boundary-unenforced FI confirmed in contract code
- [ ] **AND/OR** inclusion≠outcome attack lands on at least 1 L2 mainnet fork

**If neither: KILL the project immediately. Pivot cost = 3 weeks.**

### Gate 2 (End of Week 10) — Scope check
- [ ] Survey covers ≥6–8 L2s with contract-level evidence
- [ ] Attack demonstrated on ≥2 high-TVL L2s
- [ ] Exposure numbers defensible

### Gate 3 (End of Week 14) — Submission readiness
- [ ] All reject-proof checklist items satisfied
- [ ] Disclosure sent to affected teams (90-day clock started)
- [ ] Paper at draft-complete

---

## Reject-Proof Checklist (copy from proposal)

- [ ] **Novelty**: delta vs L2BEAT/Quantstamp, cost blogs, arXiv 2502, prior work written dead
- [ ] **Genre**: framed as real-system attack + measurement + defense (not economic theory)
- [ ] **Real victims + concrete attack**: end-to-end PoC on mainnet fork with quantified loss
- [ ] **Breadth**: survey ≥6–8 deployed L2s
- [ ] **Defense**: at least one prototyped + overhead measured
- [ ] **No overclaiming**: claims strictly scoped to demonstrated range
- [ ] **Ethics**: fork-only, coordinated disclosure, no real funds
- [ ] **Only fixable gaps remain**: residual weaknesses are "measure more L2s / deeper defense" type
