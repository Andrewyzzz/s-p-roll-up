# Force-Inclusion Contract Inventory
## Last updated: 2026-05-29

---

## Methodology

For each L2, we:
1. Identify the L1 contract implementing force-inclusion / escape-hatch
2. Read the **contract source**, not just documentation
3. Determine whether the mechanism is **functional**, **decorative**, or **economically infeasible**
4. Assess whether the sequencer retains ordering power over force-included txs (**the inclusion≠outcome gap**)

Classification rubric:
- **Functional**: timeout expires → inclusion is guaranteed by L1 contract logic
- **Decorative**: mechanism exists but L1 contract does NOT enforce inclusion; depends on sequencer honesty
- **Economically infeasible**: mechanism exists and is enforced but has prohibitive cost/delay (>1 week)

---

## 1. Arbitrum One

| Field | Value |
|-------|-------|
| **FI contract (L1)** | `0x4Dbd4fc535Ac27206064B68FfCf827b0A60BAB3f` (DelayedInbox / Inbox proxy) |
| **Impl** | `0x7C058ad1d0ee415f7e7f30e62db1bcf568470a10` |
| **SequencerInbox** | `0x1c479675ad559DC151F6Ec7ed3FbF8ceE79582B6` |
| **Force-inclusion function** | `SequencerInbox.forceInclusion(uint256,uint8,uint64[2],uint256,address,bytes32)` |
| **Delay (blocks)** | `delayBlocks = 5760` (~19h at 12s/block) |
| **Delay (seconds)** | `delaySeconds = 86400` (24h) |
| **Both conditions required** | Yes — block number AND timestamp must both exceed thresholds |
| **Classification** | **Functional** — `forceInclusion()` is callable by *anyone* after 24h; no access control |
| **Ordering constraint?** | **NO** — sequencer can insert new batches at arbitrary position relative to force-included tx |
| **Inclusion≠outcome gap** | **YES** — sequencer can prepend oracle-update+liquidation txs before force-included rescue tx |
| **Historical FI calls** | To be measured |
| **Sources** | nitro-contracts GitHub; L2BEAT; Etherscan |

**Key contract logic:**
```solidity
function forceInclusion(
    uint256 _totalDelayedMessagesRead,
    uint8 kind,
    uint64[2] calldata l1BlockAndTime,  // [blockNumber, timestamp] of delayed msg
    uint256 baseFeeL1,
    address sender,
    bytes32 messageDataHash
) external {
    if (l1BlockAndTime[0] + delayBlocks_ >= block.number)
        revert ForceIncludeBlockTooSoon();
    // ... verifies hash, then includes — but positions it wherever sequencer decides
}
```

**Notes for PoC**: `addSequencerL2BatchImpl()` has **no position constraint** on force-included messages. Sequencer controls final batch ordering.

---

## 2. Optimism (OP Mainnet)

| Field | Value |
|-------|-------|
| **FI contract (L1)** | `0x97cEbbf8959e2A5476fbe9B98A21806Ec234609B` (OptimismPortal2 proxy) |
| **Force-inclusion function** | `OptimismPortal2.depositTransaction(address,uint256,uint64,bool,bytes)` |
| **Sequencing window** | 12 hours |
| **Classification** | **Decorative (partially)** — OptimismPortal2 only emits `TransactionDeposited` event; actual enforcement is in rollup node, NOT in the L1 contract |
| **Ordering constraint?** | **NO contract-level constraint** — enforced at node implementation level only |
| **Inclusion≠outcome gap** | **YES** — even if deposit tx is included, sequencer can interleave adversarial txs |
| **Sources** | optimism GitHub; L2BEAT |

**Critical finding**: `OptimismPortal2.depositTransaction()` emits an event but does not enforce any on-chain obligation. A malicious/coerced OP Stack operator could ignore deposit events and no L1 contract would slash them.

---

## 3. Base

| Field | Value |
|-------|-------|
| **FI contract (L1)** | `0xC54cb22944F2bE476E02dECfCD7e3E7d3e15A8Fb` (OptimismPortal proxy) |
| **Force-inclusion function** | Inherited from OP Stack — `depositTransaction()` |
| **Classification** | **Decorative (partially)** — inherits all OP Stack issues |
| **Ordering constraint?** | Same as Optimism |
| **Notes** | Coinbase-operated sequencer; same structural vulnerability |

---

## 4. zkSync Era

| Field | Value |
|-------|-------|
| **FI contract (L1)** | `0x1800c60e4B916c4E8E1B122c70c80e95c9bF1C9D` (Mailbox in DiamondProxy) |
| **Force-inclusion function** | `Mailbox.requestL2Transaction()` — adds to priority queue |
| **Delay window** | **NONE** — no mandatory inclusion timeout |
| **Classification** | **DECORATIVE (fully)** |
| **Ordering constraint?** | Irrelevant — inclusion itself not guaranteed |
| **L2BEAT statement** | *"Right now there is no mechanism that forces L2 Sequencer to include transactions from the queue"* |
| **TransactionFilterer** | Operator can implement `ITransactionFilterer` to reject queued transactions |
| **Inclusion≠outcome gap** | N/A — inclusion itself is not guaranteed |
| **Sources** | L2BEAT zkSync Era page; era-contracts GitHub |

**Classification verdict**: DECORATIVE — confirmed by L2BEAT documentation. Priority queue is advisory-only. **This satisfies Kill-Switch Condition (a).**

---

## 5. StarkNet

| Field | Value |
|-------|-------|
| **FI contract (L1)** | StarknetMessaging (L1→L2 messaging) |
| **Force-inclusion function** | `sendMessageToL2()` — NOT a force-inclusion mechanism |
| **Mandatory inclusion** | **NONE** — no permissionless force-inclusion |
| **Classification** | **DECORATIVE (fully — no mechanism)** |
| **Escape hatch** | Requires Security Council minority vote — centralized |
| **L2BEAT statement** | *"There is no general mechanism to force the sequencer to include the transaction"* |
| **Sources** | L2BEAT StarkNet page |

**Classification verdict**: NO PERMISSIONLESS ESCAPE HATCH. **This also satisfies Kill-Switch Condition (a).**

---

## 6. Linea

| Field | Value |
|-------|-------|
| **FI contract (L1)** | `0xe68697690e8ff196a6abb3e1385156d87df85332` (L1MessageService) |
| **Force-inclusion mechanism** | After 6 months of no finalized blocks, Operator role becomes public |
| **Delay window** | **6 months** |
| **Classification** | **Economically infeasible** — 6-month delay is effectively zero protection for any DeFi position |
| **Ordering constraint?** | Irrelevant given delay length |
| **Notes** | Any borrowing/lending position would be liquidated within hours; escape hatch is useless for DeFi self-rescue |

---

## 7. Scroll

| Field | Value |
|-------|-------|
| **FI contract (L1)** | EnforcedTxGateway, L1MessageQueueV2 |
| **Force-inclusion function** | `EnforcedTxGateway.submitEnforcedTx()` |
| **Delay window** | 7 days (triggered when L1 message not finalized for 7 days) |
| **Classification** | **Functional** — enforced liveness mechanism is real |
| **Ordering constraint?** | TBD — needs contract audit |
| **Notes** | 7-day window still may be too long for DeFi positions |

---

## 8. Taiko

| Field | Value |
|-------|-------|
| **FI contract (L1)** | MainnetInbox |
| **Force-inclusion function** | `saveForcedInclusion()` |
| **Delay window (tier 1)** | 9m 36s — whitelisted proposers blocked until all FI requests processed |
| **Delay window (tier 2)** | ~25h — proposing becomes permissionless |
| **Classification** | **Functional (strongest)** — two-tier mechanism with short timeout |
| **Ordering constraint?** | TBD — needs contract audit |
| **Notes** | Based sequencing model; protocol strongly enforces inclusion |

---

## 9. Polygon zkEVM

| Field | Value |
|-------|-------|
| **FI contract (L1)** | PolygonZkEVMBridgeV2 (address TBD) |
| **Force-inclusion function** | TBD — documentation incomplete |
| **Classification** | TBD — requires direct contract audit |
| **Notes** | Need to audit GitHub: 0xPolygonHermez/zkevm-contracts |

---

## 10. Mantle

| Field | Value |
|-------|-------|
| **FI contract (L1)** | `0xc54cb22944F2bE476E02dECfCD7e3E7d3e15A8Fb` (OP Stack OptimismPortal) |
| **Classification** | **Decorative (partially)** — inherits OP Stack issues |
| **Notes** | Identical to Optimism/Base structurally |

---

## Summary Table

| L2 | Classification | FI Mechanism | Delay Window | Ordering Constraint | I≠O Gap |
|----|---------------|-------------|-------------|--------------------|----|
| Arbitrum | Functional | DelayedInbox.forceInclusion() | 24h | ❌ None | ✅ YES |
| Optimism | Decorative (partial) | OptimismPortal.depositTransaction() | 12h | ❌ Contract-level none | ✅ YES |
| Base | Decorative (partial) | Same as OP Stack | 12h | ❌ Contract-level none | ✅ YES |
| zkSync Era | **DECORATIVE (full)** | Priority queue (advisory) | **None** | N/A | N/A |
| StarkNet | **NO MECHANISM** | None (permissionless) | **None** | N/A | N/A |
| Linea | Economically infeasible | L1MessageService | **6 months** | N/A | N/A |
| Scroll | Functional | EnforcedTxGateway | 7 days | TBD | TBD |
| Taiko | Functional (strong) | saveForcedInclusion() | ~10min / ~25h | TBD | TBD |
| Polygon zkEVM | TBD | TBD | TBD | TBD | TBD |
| Mantle | Decorative (partial) | Same as OP Stack | 12h | ❌ Contract-level none | ✅ YES |

**Kill-Switch Condition (a): SATISFIED** — zkSync Era and StarkNet confirmed decorative/non-functional.
**Kill-Switch Condition (b): PENDING** — Arbitrum fork PoC needed.
