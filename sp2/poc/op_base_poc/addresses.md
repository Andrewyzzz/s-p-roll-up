# Address Fill-In Sheet — op_base_poc
## All slots must be verified against on-chain source before `forge test`

---

## Ethereum L1 (for Part 1)

| Symbol | Address | Source | Verified |
|--------|---------|--------|---------|
| `OPTIMISM_PORTAL_BASE` | `0x49048044D57e1C92A77f79988d21Fa8fAF74E97e` | base-org/contract-deployments/mainnet/.env | ✅ |
| `SYSTEM_CONFIG_BASE` | `0x73a79Fab69143498Ed3712e519A88a918e1f4072` | same source | 🔍 verify |
| `SEQUENCING_WINDOW_SIZE` | 3600 L1 blocks (~12h at 12s/block) | OP Stack spec derivation.md | ✅ |

### How to verify OptimismPortal address:
```bash
cast call 0x49048044D57e1C92A77f79988d21Fa8fAF74E97e "version()" --rpc-url $ETH_RPC
# Should return "2.x.x" or similar OP Stack version string
```

---

## Base L2 (for Part 2)

### Aave V3 on Base
Source: https://github.com/bgd-labs/aave-address-book/blob/main/src/AaveV3Base.sol

| Symbol | Address | Verified |
|--------|---------|---------|
| `AAVE_POOL` | `0xA238Dd80C259a72e81d7e4664a9801593F98d1c5` | ✅ |
| `AAVE_ORACLE` | `0x2Cc0Fc26eD4563A5ce5e8bdcfe1A2878676Ae156` | ✅ |
| `AAVE_ADDRESSES_PROVIDER` | `0xe20fCBdBfFC4Dd138cE8b2E6FBb6CB49777ad64D` | ✅ |

### Assets on Base
| Symbol | Address | Decimals | Verified |
|--------|---------|----------|---------|
| `WETH` | `0x4200000000000000000000000000000000000006` | 18 | ✅ |
| `USDC` | `0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913` | 6 | ✅ |

### Chainlink Feeds on Base
Source: Chainlink docs + AaveOracle.getSourceOfAsset(asset)

| Feed | Address | Verified |
|------|---------|---------|
| WETH/USD aggregator | `0x9dA00D23465282005DB222a441a663eE7B9dfCc8` | 🔍 verify via: `cast call $AAVE_ORACLE "getSourceOfAsset(address)(address)" $WETH --rpc-url $BASE_RPC` |
| L2 Sequencer Uptime Feed (Base) | `0xBCF85224fc0756B9Fa45aA7892Bd48cFe1D77da` | 🔍 verify via Chainlink Base docs |

### How to pull aggregator at runtime (in test):
```solidity
// Inside test, on Base fork:
address wethFeed = IAaveOracle(AAVE_ORACLE).getSourceOfAsset(WETH);
// Then mockCall on wethFeed for latestRoundData()
```

### Aave V3 WETH risk parameters on Base
Read at runtime from fork; approximate values for reference:
| Param | Approx value | How to read |
|-------|-------------|-------------|
| LTV | 80% | `pool.getConfiguration(WETH)` → unpack |
| Liquidation Threshold | 82.5% | same |
| Liquidation Bonus | 5% | same |
| For 20% price drop → HF crosses below 1.0 | Yes (if borrowed at >~90% of max LTV) | verified by test assertion |

---

## RPC Environment Variables

```bash
export ETH_RPC=https://eth.llamarpc.com          # or Alchemy/Infura
export BASE_RPC=https://mainnet.base.org          # or Alchemy Base
# Optional: pin block numbers for reproducibility
export BASE_FORK_BLOCK=28000000                   # any block after Aave V3 launch (~2024-02)
export ETH_FORK_BLOCK=22000000
```
