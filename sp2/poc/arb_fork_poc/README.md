# C2 PoC: Inclusion Without Outcome — Arbitrum One Fork

## Attack Scenario

1. **Setup**: A victim has a near-liquidation borrowing position on a lending protocol (e.g., Aave V3 on Arbitrum)
2. **Victim action**: Victim submits a self-rescue transaction via `DelayedInbox` (force-include path). After 24h, anyone can call `SequencerInbox.forceInclusion()` to force-include it.
3. **Adversarial sequencer action**: Before the forced tx is batched, the sequencer inserts:
   - An oracle price update (dropping collateral value below liquidation threshold)
   - A liquidation transaction (from the adversary's address)
4. **Result**: The victim's force-included self-rescue tx is processed AFTER the liquidation. The victim is liquidated despite force-inclusion succeeding.

## Key Contract Addresses (Arbitrum One mainnet / fork)

| Contract | Address | Role |
|----------|---------|------|
| SequencerInbox | `0x1c479675ad559DC151F6Ec7ed3FbF8ceE79582B6` | FI entry point (L1) |
| DelayedInbox | `0x4Dbd4fc535Ac27206064B68FfCf827b0A60BAB3f` | Message queue (L1) |
| AaveV3 Pool | `0x794a61358D6845594F94dc1DB02A252b5b4814aD` | Lending protocol (L2) |
| AaveV3 Oracle | `0xb56c2F0B653B2e0b10C9b928C8580Ac5Df02C7C7` | Price oracle (L2) |

## Files

- `test/InclusionWithoutOutcome.t.sol` — Main Foundry fork test
- `src/MockOracle.sol` — Oracle price manipulation helper
- `src/AttackerSequencer.sol` — Simulates adversarial sequencer ordering
- `script/SetupVictimPosition.s.sol` — Creates near-liquidation borrowing position

## How to Run

```bash
# Install Foundry
curl -L https://foundry.paradigm.xyz | bash
foundryup

# Set Arbitrum mainnet RPC
export ARBITRUM_RPC=https://arb1.arbitrum.io/rpc

# Run the fork test
forge test --fork-url $ARBITRUM_RPC --match-test test_InclusionWithoutOutcome -vvv
```

## Expected Output

```
[PASS] test_InclusionWithoutOutcome()
  Victim force-inclusion: SUCCESS (tx included in L2)
  Victim self-rescue outcome: FAIL (liquidated before rescue tx executed)
  Adversary profit: X ETH
  Victim loss: Y ETH
  Gas cost for adversary: Z gwei
```

## Status: IN PROGRESS

See `test/InclusionWithoutOutcome.t.sol` for implementation.

## Ethics

- Fork only — no real funds
- No interaction with production systems
- Disclosure to Arbitrum team planned (90-day coordinated disclosure)
