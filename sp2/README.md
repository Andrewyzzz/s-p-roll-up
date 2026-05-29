# Included but Not Saved
## The Limits of Forced Inclusion as Censorship Resistance in Deployed L2 Rollups

**Target venue**: IEEE S&P 2027 (Cycle 2)
**Lens**: inclusion ≠ execution-outcome (A1 vs A2 from prior rollup work)

---

## Core Claim

L2 rollups market force-inclusion / escape-hatch as the user's last guarantee against sequencer censorship or downtime. We empirically demonstrate this guarantee is significantly weaker than advertised:

1. **Decorative implementations**: Several deployed L2s have force-inclusion mechanisms that are non-functional or have unenforced boundaries.
2. **Inclusion ≠ Outcome (structural)**:  Even when force-inclusion works exactly as designed, it only guarantees *inclusion*, not the user's needed *execution result*. A rational adversarial sequencer can make the force-included transaction economically void.
3. **Quantified exposure**: We measure real TVL and user positions at risk, and provide a defense + reusable robustness test suite.

---

## Contributions

| ID | Contribution | Directory |
|----|-------------|-----------|
| C1 | Empirical survey: functional / decorative / economically-infeasible classification of 10 deployed L2s | `survey/` |
| C2 | "Inclusion without outcome" attack PoC on mainnet forks (Arbitrum + OP Stack) | `poc/` |
| C3 | Real exposure measurement: TVL at risk, historical FI usage stats | `measurement/` |
| C4 | Defense prototype (atomic FI bundle) + FI-bench reusable test suite | `defense/` |

---

## Threat Model

- **Adversary**: Censoring/coerced sequencer or state-proposer with ordering power
- **Victim**: Honest users with DeFi positions (lending, perps, AMM LP) relying on force-inclusion for self-rescue
- **Out of scope**: L1 censorship of the force-include tx itself; key compromise; consensus attacks

---

## Repository Structure

```
survey/          C1: force-inclusion survey scripts and results
poc/             C2: attack PoC (Arbitrum fork, OP Stack fork)
measurement/     C3: exposure measurement, timing, historical usage
defense/         C4: defense prototype + FI-bench suite
paper/           LaTeX source (IEEE S&P format)
docs/            Outline, kill-switch checklist, research plan
```

---

## Timeline

| Phase | Weeks | Goal |
|-------|-------|------|
| Kill-switch | 1–3 | Validate: ≥1 decorative FI **AND/OR** inclusion≠outcome attack lands on ≥1 L2 fork |
| Build-out | 4–10 | Full survey (≥6–8 L2s) + solid attack + exposure measurement |
| Polish | 11–14 | Defense prototype + FI-bench + writing |

---

## Ethics

- All PoCs run on mainnet **forks** only — no real funds at risk
- 90-day coordinated disclosure to affected L2 teams before public release
- No claims of real-world losses having occurred

---

## Delta vs Prior Work

See `docs/delta.md` for the detailed comparison against:
- L2BEAT / Quantstamp frameworks (qualitative only, miss inclusion≠outcome)
- "Hidden tax" blogs (cost argument, not structural outcome failure)
- arXiv 2502.20334 (fraud-proof challenge layer, not sequencer ordering layer)
- Our own prior rollup paper (concept lens reused, venue/genre switched)
