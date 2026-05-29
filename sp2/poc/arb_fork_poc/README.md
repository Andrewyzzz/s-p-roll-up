# Arbitrum: Ordering-Freedom Analysis + Conceptual PoC

## Status: ANALYSIS + CONCEPTUAL DEMONSTRATION (not a mainnet-fork PoC)

**IMPORTANT**: This directory contains a **self-contained conceptual
demonstration** of the ordering-freedom attack on Arbitrum, using
MockOracle + MockLending. It is **not** a mainnet fork PoC.

The **mainnet-fork PoC with real oracle infrastructure** is in
`../op_base_poc/` (Base + real AaveOracle + real Chainlink). That is the
primary C2 evidence for the paper.

This Arbitrum analysis is used for **C1 classification** (documenting that
SequencerInbox has no ordering constraint on force-included txs) and as a
**conceptual illustration** of the ordering-freedom attack mode, distinct
from the delay-window attack demonstrated on Base.

---

## Why Arbitrum Is Structurally Different from OP Stack

On **OP Stack (Base)**: deposit lands at L2 block HEAD → attack vector is
the 12 h delay window (preceding blocks). No same-block front-running.

On **Arbitrum**: `SequencerInbox.forceInclusion()` is callable by anyone
after 24 h, but `addSequencerL2BatchImpl()` has **no ordering constraint**
on where the force-included tx lands within the batch. The sequencer retains
ordering freedom even after inclusion. This is a different and additional
failure mode.

*Confirmed from nitro-contracts source:*
```solidity
// SequencerInbox.addSequencerL2BatchImpl() has no constraint on
// the position of force-included messages within the batch.
// Sequencer can interleave adversarial txs before the force-included tx.
```

---

## Conceptual PoC (self-contained, no fork dependency)

**`test/InclusionWithoutOutcome.t.sol`** — demonstrates the
ordering-freedom attack with MockOracle + MockLending.

```
[PASS] test_InclusionWithoutOutcome() (gas: 170,381)

Adversary WETH seized:  2.52 WETH
Adversary net profit:   $180 USD
Victim collateral lost: 2.52 WETH
Victim HF: 1.111 -> 0.833 -> liquidated
Force-inclusion: SUCCESS | Victim outcome: FAIL
```

**How to run** (no RPC needed):
```bash
forge install foundry-rs/forge-std --no-git
forge test --match-test test_InclusionWithoutOutcome -vvv
```

---

## Paper Usage

| Claim | Evidence | Status |
|-------|----------|--------|
| Arbitrum SequencerInbox has no ordering constraint | Source code audit (nitro-contracts) | ✅ Contract analysis |
| Ordering-freedom attack concept is valid | Conceptual PoC (mock) | ✅ Demonstrated |
| Attack on real Arbitrum Aave V3 | Mainnet fork | ⚠️ Not yet — requires Alchemy/QuickNode |

In the paper:
- Cite Arbitrum as **"ordering-freedom" attack mode** (distinct from OP Stack delay-window mode)
- Mark C1 classification as contract-analysis evidence (not fork PoC)
- For full fork validation: requires archive-node RPC (Alchemy/QuickNode resolves Foundry/ArbOS NotActivated issue)

---

## Footprint in C1 Survey

From `survey/contracts.md`:

| Dimension | Arbitrum | OP Stack (Base) |
|-----------|----------|-----------------|
| FI mechanism | SequencerInbox.forceInclusion() | derivation (deposit → block HEAD) |
| Delay window | 24 h | ~12 h |
| Ordering constraint after inclusion | **None** | Deposit at block HEAD |
| Attack vector | Ordering freedom | Delay window |

This distinction drives the paper's claim that failure modes differ by chain
and require chain-specific defenses.
