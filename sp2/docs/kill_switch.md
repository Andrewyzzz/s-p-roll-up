# Kill-Switch Validation Log
## Weeks 1–3: Go / No-Go Decision

**Decision deadline**: End of Week 3 (2026-06-19)
**Decision rule**: At least ONE of (a) or (b) must be TRUE to continue.

---

## Condition (a): Decorative / Boundary-Unenforced FI

**Question**: Does at least 1 deployed L2 have a force-inclusion mechanism that is either non-functional or boundary-unenforced?

**Status: ✅ SATISFIED (2026-05-29)**

| L2 | Status | Evidence | Source |
|----|--------|----------|--------|
| **zkSync Era** | ✅ DECORATIVE (full) | L2BEAT: "no mechanism that forces L2 Sequencer to include transactions from the queue"; ITransactionFilterer can block priority queue; no timeout enforcement | L2BEAT; era-contracts GitHub |
| **StarkNet** | ✅ NO MECHANISM | L2BEAT: "no general mechanism to force the sequencer to include the transaction"; escape hatch requires Security Council minority (centralized) | L2BEAT |
| Linea | ✅ ECONOMICALLY INFEASIBLE | 6-month delay — DeFi positions liquidated in hours; functionally zero protection | L2BEAT |
| Optimism/Base/Mantle | ⚠️ DECORATIVE (partial) | OptimismPortal2 only emits `TransactionDeposited` event; no L1 slashing; enforcement lives in rollup node only | Contract audit; optimism GitHub |
| Arbitrum | ✓ Functional | forceInclusion() callable by anyone after 24h, enforced on-chain | nitro-contracts; L2BEAT |
| Scroll | ✓ Functional (7d) | EnforcedTxGateway with enforced liveness | L2BEAT; scroll-contracts |
| Taiko | ✓ Functional (strong) | Two-tier: ~10min / ~25h, based sequencing | L2BEAT |
| Polygon zkEVM | 🔍 TBD | Contract audit pending | — |

**Result (a): ✅ SATISFIED** — zkSync Era (confirmed decorative), StarkNet (no mechanism), Linea (infeasible), OP Stack family (partially decorative)

---

## Condition (b): Inclusion≠Outcome Attack on Fork

**Question**: Can we demonstrate on a mainnet fork that force-inclusion succeeds but victim outcome fails due to adversarial sequencer ordering?

**Status: 🔍 IN PROGRESS — PoC skeleton complete, needs execution**

### Theoretical basis (confirmed)

From Arbitrum nitro-contracts source:
- `SequencerInbox.forceInclusion()`: callable by anyone after 24h — **confirmed**
- `addSequencerL2BatchImpl()`: **no ordering constraint** on force-included tx position — **confirmed**
- Sequencer can prepend arbitrary txs before force-included tx — **confirmed by docs**

This means the attack is architecturally viable. The PoC is a demonstration, not a discovery.

### PoC Status

| L2 | Framework | Status | Location |
|----|-----------|--------|----------|
| Arbitrum One | Foundry fork | ⚙️ Skeleton written | `poc/arb_fork_poc/` |
| OP Stack | Foundry fork | 📋 TODO | `poc/op_fork_poc/` |

**Key implementation gap**: Need to fix `_getOracleOwner()` — find the actual Aave V3 oracle owner/admin on Arbitrum fork to impersonate for price manipulation. Alternatively, use `vm.store` to directly write the price into the Chainlink aggregator's storage slot.

**Result (b): ⏳ PENDING** — run `forge test` once ARBITRUM_RPC is set.

---

## Preliminary Verdict

**Condition (a) is definitively satisfied.** Multiple deployed L2s confirmed.

**The project should continue even before (b) is verified**, because:
- (a) alone is sufficient per the kill-switch rule
- (b) is architecturally confirmed; only the test execution is pending
- Evidence for (b) is in the contracts — no speculation required

---

## Final Decision

| Date | Decision | Reason |
|------|----------|--------|
| 2026-05-29 | **GO (preliminary)** | Condition (a) satisfied by zkSync Era + StarkNet + OP Stack family |
| (End Week 3) | ⏳ Pending (b) confirmation | Run fork PoC to confirm (b) |
