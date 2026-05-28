# Preconfer Implementation Evaluation (Task 2.3)

**Date:** 2026-05-28
**Decision:** mev-commit (Primev) selected as reference implementation for PEO PoC

---

## Candidates Evaluated

| Implementation | Status | Stars | Local testnet | Bond mechanism | PEO surface |
|---|---|---|---|---|---|
| **mev-commit (Primev)** | Production | ~200 | Yes (Foundry/Anvil) | slashAmt per bid | ✅ Clear |
| **Bolt (Chainbound)** | **Archived 2026-02-23** | ~150 | Kurtosis (complex) | Not specified | ❌ Abandoned |
| Based preconfs (EIP) | Proposal only | N/A | None | N/A | ❌ Not deployed |

**Decision: mev-commit.** Bolt is archived and was alpha-stage; it is no longer maintained.
Based preconfs are a design proposal without an implementation. mev-commit is the only
production-deployed preconfirmation protocol with a clear bond/slashing mechanism and
an accessible codebase.

---

## mev-commit Architecture

### Components

```
Bidder (searcher/user)
  │  submits bid (txHashes, revertingTxHashes, amount, slashAmount, blockNumber)
  ▼
mev-commit p2p network
  │  provider receives bid, issues commitment
  ▼
PreconfManager.sol (on-chain)
  │  storeUnopenedCommitment() → records sealed commitment
  │  openCommitment()          → reveals commitment at block time
  ▼
Oracle.sol
  │  monitors L1 blocks
  │  detects commitment violations (committed tx not in block)
  │  calls initiateSlash() on violation
  ▼
ProviderRegistry.sol
  │  holds provider stake
  │  executes slash: transfers slashAmt → bidder
```

### Key Contracts (on mev-commit chain)

| Contract | Role |
|---|---|
| `PreconfManager.sol` | Stores commitments, handles reveal, coordinates slash |
| `ProviderRegistry.sol` | Holds provider stake; executes `slash()` |
| `BidderRegistry.sol` | Manages bidder deposits; pays out to bidder on slash |
| `Oracle.sol` | Detects violations, triggers `initiateSlash()` |
| `BlockTracker.sol` | Tracks which L1 block is being committed to |

---

## Commitment Structure (verbatim from PreconfManager.sol)

```solidity
struct OpenedCommitment {
    address bidder;
    bool isSettled;
    uint64 blockNumber;
    uint64 decayStartTimeStamp;
    uint64 decayEndTimeStamp;
    uint64 dispatchTimestamp;
    address committer;
    uint256 bidAmt;
    uint256 slashAmt;       // ← slashed from provider if violated
    bytes32 commitmentDigest;
    bytes commitmentSignature;
    string txnHash;
    string revertingTxHashes;  // ← txs that can revert without slashing
    bytes bidOptions;
}
```

**revertingTxHashes semantics (verbatim from docs):**
> "Array of transaction hashes as strings that can revert"
> "Transactions listed here can revert without triggering slashing; unlisted
>  transactions must succeed or the provider faces penalties"

**slashAmt field:** Per-bid slash amount specified by the bidder. Provider is slashed
exactly `slashAmt` plus a 5% protocol fee if the commitment is violated.

**Slash trigger:** Oracle detects that a committed transaction is not in the target L1
block (or is in `revertingTxHashes` and reverted). Oracle calls `initiateSlash()`.

---

## PEO Attack Vector

### Definition (§3 paper)

The Preconfirmation Exercise Option arises because a provider holds a commitment
$\Gamma(B)$ and can choose, after the commitment is issued but before the block
is proposed, whether to honor or violate it. If the option value $V$ of violating
(e.g., by including a higher-value transaction instead) exceeds the slash penalty,
the rational provider violates.

**Payoff formula:**
$$\Pi^{\text{PEO}} = \max(V - \text{slashAmt}, 0)$$

where $V$ is the value of the alternative action (e.g., including a different tx)
minus the value of the committed action.

### PEO conditions in mev-commit

All three conditions are satisfied by design:

1. **Commitment precedes execution:** Provider signs commitment before block production.
   `storeUnopenedCommitment()` is called before the slot arrives.

2. **Provider knows option value before block time:** Provider can observe mempool
   between commitment and block time. If a high-value transaction appears that
   conflicts with the committed transaction, the provider can evaluate
   $V > \text{slashAmt}$ and choose to violate.

3. **Slashing is the only deterrent (A4 only):** There is no capability (i)
   (no pre-execution success predicate in the commitment) and no capability (ii)
   (provider can propose any block; slashing occurs post-hoc). The commitment is
   A4 only, not A2.

### Attack scenario for PoC

```
Time t₀: Provider commits to include tx T (value to bidder: $X)
          slashAmt = $S set by bidder

Time t₁: Large MEV opportunity M appears in mempool
          M conflicts with T (can't include both)
          Value of M = $V >> $S

Time t₂ (block time): Provider includes M, excludes T
          Net to provider: $V - $S - 5% protocol fee

Time t₃: Oracle detects T not in block → initiates slash
          Bidder receives: $S (compensation, < actual loss $X if $X > $S)
          Provider net: $V - $S - fee > 0 if $V > $S * 1.05
```

**Free option:** The provider commits for free (no cost to issue commitment)
and retains the right to violate. The option premium paid to the bidder is zero
— the bidder receives nothing upfront; slashing only compensates after the fact.

---

## Local Setup Plan (for Task 3.1 PoC)

### Option A: Foundry/Anvil (recommended for PoC)

Deploy mev-commit contracts on local Anvil chain:
```bash
git clone --recurse-submodules https://github.com/primev/mev-commit
cd mev-commit/contracts
forge install
forge test  # verify contracts compile and tests pass
```

Deploy key contracts:
1. `ProviderRegistry` (with test stake)
2. `BidderRegistry`
3. `PreconfManager`
4. `Oracle` (simplified mock — just calls `initiateSlash` directly)
5. `BlockTracker` (mock)

Attack script (Foundry):
```solidity
// 1. Provider registers with stake S
// 2. Bidder submits bid for tx T (slashAmt = S/2)
// 3. Provider issues commitment (storeUnopenedCommitment)
// 4. Block time: provider opens commitment, proposes block WITHOUT T
// 5. Mock oracle calls initiateSlash
// 6. Verify: slashAmt transferred to bidder, provider net = MEV(M) - slashAmt
```

### Option B: mev-commit devnet (if local deployment proves complex)

Check for Docker-based devnet in mev-commit repo:
```bash
ls mev-commit/testing/
# or
cat mev-commit/docker-compose.yml
```

### Selection for Task 3.1

Start with Option A (Foundry/Anvil) — it gives full control over the attack
scenario and doesn't require running the p2p network or a live oracle.
The Oracle in the PoC can be a Foundry test contract that simulates the
violation detection.

---

## PEO Payoff Model (for §3 paper)

### Variables

| Symbol | Meaning | Source |
|---|---|---|
| $B$ | Provider's posted stake (bond) | `ProviderRegistry.stake` |
| $s$ | Per-bid `slashAmt` | `OpenedCommitment.slashAmt` |
| $V$ | Option value: best alternative tx value minus committed tx value | Mempool observation |
| $\Delta\Pi$ | Attacker net gain from violation | Formula below |

### Formula

$$\Delta\Pi(s, V) = \begin{cases}
  V - s \cdot 1.05 & \text{if } V > s \cdot 1.05 \\
  0 & \text{otherwise}
\end{cases}$$

**Option is positive when:** $V > s \cdot 1.05$

**Key observation:** Provider can set $s$ freely (it's a field in their commitment,
not fixed by the protocol). A provider rationally sets $s$ low (minimizing
self-imposed penalty) while the bidder wants $s$ high (maximizing protection).
This creates an adversarial pricing dynamic that the paper analyzes in §3.3.

**Regimes where option is positive:**
- High MEV spikes: $V$ is large relative to typical $s$ values
- Frontrunning opportunities: provider can observe an attack opportunity between
  commitment time $t_0$ and block time $t_2$
- Market volatility: rapid price movements that make the committed tx unprofitable

---

## §2.3 Mapping Table Update

mev-commit is classified as **A0, A1, A4 only** in Table 2 (§2.3):

```
mev-commit (Primev) | A0, A1, A4 | not A2, A3 |
  "Array of transaction hashes that can revert" in bid;
  slashing on commitment violation (A4); no execution outcome predicate (not A2)
```

The `revertingTxHashes` field is decisive: the protocol explicitly allows
execution failure without slashing, confirming it provides no execution
atomicity guarantee. Slashing is A4: it compensates for inclusion failure,
but does not prevent it.

---

## Appendix A Update Required

The `mev-commit / Bolt` entry in Appendix A (boundary cases) needs updating:
- Bolt: archived, remove from "current" classification; note as historical
- mev-commit: keep as primary A4-only example; add `slashAmt` field detail
  and `initiateSlash()` function name as specific code-level evidence
