// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/*//////////////////////////////////////////////////////////////////////////
  Trustless rescue defense (fast-path) for the "Included but Not Saved" attack.

  Threat model: a censoring OP-Stack sequencer blocks a borrower's self-save
  on L2 and liquidates the position inside the ~12h force-inclusion window.

  This contract lets ANYONE activate liquidation protection for a user by
  proving, trustlessly on L2, that the user has a pending forced deposit on L1.
  Verification uses the SAME audited primitives OptimismPortal uses for L2→L1
  withdrawal proofs (MerkleTrie / RLPReader), anchored to the L1 block hash
  that the L2 already knows via the L1Block predeploy (0x4200..0015).

  ── Trust model ─────────────────────────────────────────────────────────────
  FAST-PATH (this contract): proveRescue() is itself an L2 tx. A fully
  censoring sequencer could also censor it. This is better than the oracle
  watcher (raises attacker cost: must censor both victim AND proof submitter)
  but not fully censorship-proof.

  CENSORSHIP-PROOF BASELINE (stated in paper §defense, not implemented here):
  A liquidation is not final for ≥ the force-inclusion window (12h on OP).
  If, within that window, the user's forced self-save derives into L2
  (protocol-enforced; sequencer cannot suppress derivation), the liquidation
  is unwound and the position restored. No L2 tx required during the window —
  nothing for the sequencer to censor. Paper claims BOTH: baseline (proof of
  concept) + fast-path (this contract, with honest residual assumption).

  ── Paper disclosure ─────────────────────────────────────────────────────────
  - L1Block.hash() exposes only the latest L1 origin; proofs for older
    deposits work once L2's L1-origin has advanced past the deposit block
    (still well within 12h window). Ring-buffer extension is straightforward.
  - proveRescue() is an L2 tx; a fully censoring sequencer could censor it.
  - Test mocks L1Block.hash() — standard Foundry practice; disclosed.
//////////////////////////////////////////////////////////////////////////*/

import {MerkleTrie} from "@eth-optimism/contracts-bedrock/src/libraries/trie/MerkleTrie.sol";
import {RLPReader}  from "@eth-optimism/contracts-bedrock/src/libraries/rlp/RLPReader.sol";
import {RLPWriter}  from "@eth-optimism/contracts-bedrock/src/libraries/rlp/RLPWriter.sol";

interface IL1Block {
    function hash()   external view returns (bytes32);
    function number() external view returns (uint64);
}

contract ProtectedLendingTrustless {
    using RLPReader for RLPReader.RLPItem;
    using RLPReader for bytes;

    // ── Constants ─────────────────────────────────────────────────────────────

    // L1Block predeploy — updated every L2 block by the L1-attributes deposit
    IL1Block constant L1BLOCK = IL1Block(0x4200000000000000000000000000000000000015);

    // keccak256("TransactionDeposited(address,address,uint256,bytes)")
    // Verified against Base OptimismPortal event signature.
    bytes32 public constant TX_DEPOSITED_TOPIC =
        0xb3813568d9991fc951961fcb4c784893574240a28925604d09fc577c55bb7c32;

    // OP Stack worst-case sequencing window = GRACE_PERIOD
    uint256 public constant GRACE_PERIOD = 12 hours;

    // ── State ─────────────────────────────────────────────────────────────────

    address public immutable optimismPortal;

    mapping(address => uint256) public rescueDeadline;  // user → protected-until
    mapping(bytes32 => bool)    public usedProof;        // anti-replay

    // ── Events ────────────────────────────────────────────────────────────────

    event RescueActivated(address indexed user, uint256 deadline, bytes32 l1Hash);

    // ── Constructor ───────────────────────────────────────────────────────────

    constructor(address _portal) {
        optimismPortal = _portal;
    }

    // ── Core: trustless rescue activation ────────────────────────────────────

    /**
     * @notice PERMISSIONLESS. Activate liquidation protection for `user` by
     *         proving a pending L1 forced deposit via MPT receipt proof.
     *
     * Griefing protection: proof must be valid (real L1 data required).
     * Cannot be fabricated to manufacture grace periods for healthy positions.
     *
     * @param user          The borrower whose position should be protected.
     * @param l1HeaderRLP   Full RLP of the L1 block header containing the deposit.
     * @param txIndex       Transaction index in that L1 block.
     * @param receiptRLP    EIP-2718 typed receipt for txIndex (trie value).
     * @param trieProof     MPT proof of receiptRLP under header.receiptsRoot.
     */
    function proveRescue(
        address       user,
        bytes calldata l1HeaderRLP,
        uint256        txIndex,
        bytes calldata receiptRLP,
        bytes[] calldata trieProof
    ) external {
        // 1. Bind to an L1 block hash the L2 chain already trusts.
        bytes32 l1Hash = L1BLOCK.hash();
        require(keccak256(l1HeaderRLP) == l1Hash, "header != L1Block.hash");

        // 2. Extract receiptsRoot from header field index 5.
        bytes32 receiptsRoot = _receiptsRoot(l1HeaderRLP);

        // 3. Receipt trie is a non-secure MPT keyed by RLP(txIndex).
        //    verifyInclusionProof confirms (key, receiptRLP) is in the trie under receiptsRoot.
        bytes memory key = RLPWriter.writeUint(txIndex);
        bool valid = MerkleTrie.verifyInclusionProof(key, receiptRLP, trieProof, receiptsRoot);
        require(valid, "receipt not in trie");

        // 4. Confirm receipt contains TransactionDeposited(from=user) from portal.
        require(_hasUserDeposit(receiptRLP, user), "no deposit for user in receipt");

        // 5. Anti-replay + activate grace period.
        bytes32 id = keccak256(abi.encode(l1Hash, txIndex, user));
        require(!usedProof[id], "proof already used");
        usedProof[id] = true;

        rescueDeadline[user] = block.timestamp + GRACE_PERIOD;
        emit RescueActivated(user, rescueDeadline[user], l1Hash);
    }

    /**
     * @notice Liquidation guard. Call at the TOP of any liquidation function.
     *         Reverts if user has an active rescue grace period.
     *         LIVENESS: protection auto-expires; no permanent block.
     */
    function liquidationGuard(address user) public view {
        require(block.timestamp >= rescueDeadline[user], "rescue active");
    }

    function isProtected(address user) external view returns (bool) {
        return block.timestamp < rescueDeadline[user];
    }

    // ── RLP helpers ──────────────────────────────────────────────────────────

    /**
     * @dev Extract receiptsRoot from a block header RLP.
     *      Header fields: 0=parentHash 1=ommersHash 2=coinbase 3=stateRoot
     *      4=txRoot 5=receiptsRoot (bytes32) 6=logsBloom ...
     */
    function _receiptsRoot(bytes calldata headerRLP) internal pure returns (bytes32 r) {
        RLPReader.RLPItem[] memory fields = headerRLP.toRLPItem().readList();
        bytes memory rr = fields[5].readBytes();
        assembly { r := mload(add(rr, 32)) }
    }

    /**
     * @dev Parse an EIP-2718 typed receipt and check whether it contains
     *      a TransactionDeposited(from=user) log emitted by optimismPortal.
     *
     * Receipt structure (type-2 = EIP-1559):
     *   type_byte || RLP([status, cumulativeGasUsed, logsBloom, logs])
     *
     * Each log:
     *   RLP([emitter_address, [topic0, topic1, ...], data])
     *
     * TransactionDeposited:
     *   topic0 = TX_DEPOSITED_TOPIC
     *   topic1 = bytes32(uint256(uint160(from)))  ← must equal user
     */
    function _hasUserDeposit(bytes calldata receiptRLP, address user)
        internal
        view
        returns (bool)
    {
        // Strip EIP-2718 type byte (type < 0x80 = typed; >= 0x80 = legacy RLP list)
        bytes memory raw;
        if (receiptRLP.length > 0 && uint8(receiptRLP[0]) < 0x80) {
            raw = new bytes(receiptRLP.length - 1);
            for (uint256 i; i < raw.length; i++) {
                raw[i] = receiptRLP[i + 1];
            }
        } else {
            raw = abi.encodePacked(receiptRLP);
        }

        // Decode receipt list: [status, cumulativeGas, logsBloom, logs]
        RLPReader.RLPItem[] memory fields = raw.toRLPItem().readList();
        require(fields.length >= 4, "malformed receipt");

        // logs = fields[3]
        RLPReader.RLPItem[] memory logs = fields[3].readList();

        bytes32 userTopic = bytes32(uint256(uint160(user)));

        for (uint256 i; i < logs.length; i++) {
            // Each log: [emitter, topics[], data]
            RLPReader.RLPItem[] memory entry = logs[i].readList();
            if (entry.length < 2) continue;

            // Emitter address (20 bytes in RLP)
            bytes memory addrBytes = entry[0].readBytes();
            if (addrBytes.length != 20) continue;
            address emitter;
            assembly {
                emitter := shr(96, mload(add(addrBytes, 32)))
            }
            if (emitter != optimismPortal) continue;

            // Topics list
            RLPReader.RLPItem[] memory topics = entry[1].readList();
            if (topics.length < 2) continue;

            // topic0 = event signature (32 bytes)
            bytes memory t0b = topics[0].readBytes();
            if (t0b.length != 32) continue;
            bytes32 t0;
            assembly { t0 := mload(add(t0b, 32)) }
            if (t0 != TX_DEPOSITED_TOPIC) continue;

            // topic1 = from address padded to bytes32
            bytes memory t1b = topics[1].readBytes();
            if (t1b.length != 32) continue;
            bytes32 t1;
            assembly { t1 := mload(add(t1b, 32)) }
            if (t1 == userTopic) return true;
        }
        return false;
    }
}
