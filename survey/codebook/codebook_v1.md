# Cross-Rollup Application Survey Codebook v1

**Status:** DRAFT — to be pre-registered via OpenTimestamps before coding begins (Task 1.6)

**Pre-registration commit:** [TO BE FILLED after Task 1.6]

**OpenTimestamps proof:** `codebook_v1.md.ots` (generated after Task 1.6)

---

## Survey Scope

- **Population:** Cross-rollup applications deployed on 2+ rollups sharing a common
  sequencer or preconfirmation layer
- **Time range:** Active deployment 2024–2026
- **Sample size target:** N=30–50 applications

---

## Mandatory Thesis-Fit Filter (Task 1.1)

ALL THREE must be satisfied for a candidate to pass:

| # | Criterion | Pass | Fail |
|---|---|---|---|
| TF-1 | Application spans 2+ rollups sharing same sequencer/preconfirmation | Yes | No |
| TF-2 | Bundle legs execute independently on different rollups (not cross-chain messaging) | Yes | No |
| TF-3 | Sequencer/preconf layer is lazy (doesn't execute STFs) | Yes | No |

---

## Auxiliary Filters

| # | Criterion | Preferred range |
|---|---|---|
| AX-1 | TVL | $5M–$100M |
| AX-2 | Contracts verified | Yes |
| AX-3 | Active deployment period | 2024–2026 |
| AX-4 | Architecture does NOT already instantiate Theorem 1 (i) or (ii) | Confirmed |

---

## Coding Variables

For each candidate application:

### V1: Application Identity
- Name, URL, contract addresses

### V2: Rollup Coverage
- Which rollups? (OP, Base, Arb, zkEVM, other)
- Shared sequencer/preconf layer?

### V3: TF Filter Results
- TF-1 pass/fail + evidence
- TF-2 pass/fail + evidence
- TF-3 pass/fail + evidence

### V4: PEFO Condition Mapping
- Condition 1 (independent STFs): where instantiated?
- Condition 2 (lazy sequencer): evidence?
- Condition 3 (economic gap): quantification?

### V5: Theorem 1 Mitigation Check
- Does application already implement (i) pre-execution evidence? Evidence:
- Does application already implement (ii) partial-effect prevention? Evidence:
- If yes to either: fail AX-4, exclude from PEFO attack surface

### V6: Vendor Responsiveness Prior
- Historical disclosure response (if any public record)
- Contact channels available (security@, DM, forum)

### V7: Testnet Availability
- Testnet URL
- Faucet availability

---

## Double-Coding Protocol

- Primary coder: [Author]
- Secondary coder: [Collaborator]
- Cohen's kappa target: > 0.6
- Disagreement resolution: discussion, then majority rule

---

## IRR Calculation

Cohen's kappa for binary variables (TF-1/2/3, V5 mitigation check).
Reported in Appendix C.
