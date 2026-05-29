# C2: "Inclusion Without Outcome" Attack PoCs

## Overview

These PoCs demonstrate that **force-inclusion does not guarantee execution outcome** on deployed L2s. An adversarial sequencer can order oracle updates + liquidation transactions BEFORE a force-included self-rescue transaction, making the victim's protection ineffective.

## Structure

```
poc/
  arb_fork_poc/   ← Arbitrum One mainnet fork (primary PoC)
  op_fork_poc/    ← OP Stack (Optimism/Base) fork (secondary PoC)
```

## Attack Sequence

```
T=0:      Victim submits self-rescue tx via L1 DelayedInbox
T=24h:    Force-inclusion window expires → anyone can call forceInclusion()

ADVERSARY BATCH (constructed by sequencer):
  [1]  Oracle price update → WETH drops 30%
  [2]  adversary.liquidationCall(victim)     ← adversary's tx
  [3]  victim.repay(...)                     ← FORCE-INCLUDED tx ← arrives too late

OUTCOME:
  ✓ Force-inclusion succeeded (victim's tx IS in L2)
  ✗ Victim still gets liquidated
  ✓ Adversary profits
```

## Why This Works

The key insight from our taxonomy:
- **A1 (Ordering guarantee)**: Force-inclusion provides this — the tx WILL be included
- **A2 (Execution outcome)**: Force-inclusion does NOT provide this — the sequencer retains full ordering power within batches

From `SequencerInbox.addSequencerL2BatchImpl()`:
```solidity
// No constraint on WHERE in the batch a force-included tx is placed
// Sequencer can freely interleave adversarial txs before the force-included tx
```

## Running the PoCs

### Prerequisites
```bash
# Install Foundry
curl -L https://foundry.paradigm.xyz | bash
foundryup

# Set RPC endpoints
export ARBITRUM_RPC=https://arb1.arbitrum.io/rpc
export OP_RPC=https://mainnet.optimism.io
```

### Arbitrum Fork PoC
```bash
cd arb_fork_poc
forge install foundry-rs/forge-std
forge test --fork-url $ARBITRUM_RPC --match-test test_InclusionWithoutOutcome -vvv
```

### OP Stack Fork PoC
```bash
cd op_fork_poc
forge install foundry-rs/forge-std
forge test --fork-url $OP_RPC --match-test test_InclusionWithoutOutcome -vvv
```

## Measured Quantities

For each PoC, we measure and report:
1. **Force-inclusion success**: Did the victim's tx get included? (always YES)
2. **Victim outcome**: Was the victim liquidated despite force-inclusion?
3. **Adversary profit**: ETH/WETH gained from liquidation bonus
4. **Victim loss**: Collateral seized
5. **Gas cost**: For the full adversarial ordering sequence

## Ethics

- Fork-only — no real funds used
- No interaction with production systems
- Responsible disclosure to Arbitrum and OP Stack teams planned (90-day window)
