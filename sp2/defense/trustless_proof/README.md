# Trustless rescue defense — build notes

This closes the trust hole in the watcher prototype: activation no longer
relies on an off-chain oracle, but on an L1-inclusion proof verified **on L2**
against the L1 block hash the chain already exposes (`L1Block` predeploy),
using the **same audited MerkleTrie/RLP primitives `OptimismPortal` uses for
withdrawal proofs**. That reuse is itself a selling point for the paper.

## Dependencies
```
forge install ethereum-optimism/optimism   # for MerkleTrie / RLPReader / RLPWriter
```
Verify import paths + function signatures against your installed
`@eth-optimism/contracts-bedrock` version (they move between releases).

## Proof recipe (the one offchain step)
For a real Base/OP deposit you want to prove:
1. Find a real `OptimismPortal.TransactionDeposited` log (Etherscan → portal
   address → Events), note its **L1 block** and **tx index**.
2. `headerRLP` = RLP of that L1 block header; check `keccak256(headerRLP)`
   equals the block hash. (e.g. `cast block <num> --rpc-url $L1 --json` then
   RLP-encode the 20 header fields, or use a helper lib.)
3. `receiptRLP` = the typed receipt for that tx
   (`eth_getTransactionReceipt`, then re-encode per EIP-2718:
   `type(1 byte) || rlp(receipt)`).
4. `trieProof` = MPT proof of `receiptRLP` under `header.receiptsRoot`,
   keyed by `RLP(txIndex)`. Generate with `eth-proof`,
   `@ethereumjs/mpt`, or `merkle-patricia-tree` over the block's receipts.
5. Set `victim` = the `from` address of that deposit; paste the four values
   into `_loadRealDepositFixture()`.

`_hasUserDeposit` (the TODO in the contract): strip the EIP-2718 type byte,
`readList` the receipt, take `logs = field[3]`, and match a log with
`address == optimismPortal`, `topic0 == TX_DEPOSITED_TOPIC`,
`topic1 == bytes32(uint160(user))`. ~30 lines with RLPReader.

## Known refinements (state these in the paper, don't hide them)
- **`L1Block.hash()` exposes only the *latest* L1 origin.** To prove a deposit
  made a few L1 blocks earlier, either (a) submit once the L2's L1-origin has
  advanced to ≥ the deposit block (still well within the 12h window), or
  (b) keep a small ring-buffer of recent L1 hashes. Both are simple; pick one.
- **Receipts trie is a *non-secure* MPT** keyed by `RLP(index)` → `MerkleTrie`,
  not `SecureMerkleTrie` (the latter is for state/storage, keys hashed).
- **Typed receipts (EIP-2718):** strip the leading type byte before `readList`.
- Test mocks `L1Block.hash()` to point at the real L1 block — disclose this.

## The honest caveat a reviewer WILL raise — and the answer
`proveRescue()` is itself an L2 transaction. A *fully* censoring sequencer
could also censor it. So **treat this as the fast-path, not a complete
censorship-proof defense.** Claim the censorship-proof BASELINE below; offer
this proof-path as an immediate-activation optimization.

### Censorship-proof baseline: liquidation finality-delay + auto-unwind
- A liquidation is **not final for ≥ the force-inclusion window** (12h on OP).
- If, within that window, the user's forced self-save **derives into L2**
  (protocol-enforced; the sequencer *cannot* suppress derivation), the
  liquidation is **unwound** and the position restored.
- No L2 tx is required during the window → nothing for the sequencer to
  censor. The trigger is derivation itself.
- **Cost (state it):** liquidators face delayed settlement; bad-debt exposure
  is bounded by (further adverse move over the window) × (protected positions),
  and protected positions are rare (gated on a real forced deposit; on-chain
  forced-inclusion usage ≈ 0). Quantify this bound in §defense.

Recommended framing: **baseline = finality-delay+unwind (censorship-proof,
latency cost); fast-path = this trustless proof (instant, residual
activation-censorship).** Both reuse only protocol-native, trustless inputs.

## Integration
Wire `liquidationGuard(user)` into your existing `ProtectedLending.liquidationCall`
before the HF/seize logic. Keep your 4 existing tests (attack-without-defense,
blocks, expires, gas) and add these.

---
**This is the last artifact.** After it compiles + the fixture passes, stop
hardening code — the next highest-value work is *writing the paper*: the
framing (liveness≠integrity, force-inclusion is not a binary checkbox), the
delta table, the contradiction-on-Base narrative, and the defense section's
honest trust-spectrum. The writeup is now the main Revise-vs-Accept lever.
