# Attack 1: Preconfirmation Exercise Option (PEO)

**Reference implementation:** mev-commit (Primev) — selected Task 2.3
**Milestone:** Milestone 1 (Week 6) — PEO PoC works end-to-end

## Attack Summary

Provider holds commitment Γ(τ, s) and violates when MEV opportunity M
appears with marginal value δ > s × 1.05.

**Payoff:** ΔΠ = max(δ − s × 1.05, 0)   (see §3.2 of paper)

## Repository Structure

```
poc/peo/
├── src/
│   ├── MockOracle.sol          # Calls initiateSlash directly (no p2p needed)
│   └── interfaces/             # Minimal mev-commit interfaces
├── test/
│   └── PEO.t.sol               # End-to-end Foundry test
├── script/
│   └── RunPEO.s.sol            # Clean demo script
└── foundry.toml
```

## Requirements

- Foundry (forge, cast, anvil)
- mev-commit contracts (primev/mev-commit — submodule or copy)

## Setup (Task 3.1)

```bash
cd poc/peo
forge install
# Copy mev-commit core contracts:
#   PreconfManager.sol, ProviderRegistry.sol, BidderRegistry.sol, Oracle.sol
# from github.com/primev/mev-commit/contracts/contracts/core/
forge build
```

## Run

```bash
forge test -vvvv --match-test testPEO_ViolationProfit
```

## Attack Scenario (§3.4 worked example)

```
Provider stake:   B = 1.0 ETH
slashAmt:         s = 0.05 ETH
MEV opportunity:  δ = 0.12 ETH (arrives between t₀ and t₂)

t₀: provider issues Γ(τ, s=0.05)     [storeUnopenedCommitment]
t₁: MEV M appears, δ = 0.12 ETH
t₂: provider violates (excludes τ)   [openCommitment without τ]
t₃: Oracle detects → initiateSlash() [MockOracle]

Provider net:    0.12 − 0.05×1.05 = +0.0675 ETH ✓
Bidder receives: 0.05 ETH (< true value of reliable preconf)
Max violations:  ⌊1.0 / 0.0525⌋ = 19 before bond depletion
```

## Expected Output (Milestone 1)

- Bond B: 1.0 ETH
- Observed option value V (MEV): 0.12 ETH
- Slash cost: 0.0525 ETH
- **Attacker net: 0.0675 ETH**
- Bond depletion N_max: 19 violations

## TODO (Task 3.1, Week 6)

- [ ] Copy PreconfManager.sol + ProviderRegistry.sol from primev/mev-commit
- [ ] Write MockOracle.sol (calls initiateSlash directly)
- [ ] Write PEO.t.sol with worked-example numbers
- [ ] Write RunPEO.s.sol for clean demo output
- [ ] Measure timing window t₂ − t₀ on local Anvil (feeds §5.1)
