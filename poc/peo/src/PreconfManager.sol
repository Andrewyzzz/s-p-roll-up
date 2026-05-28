// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./ProviderRegistry.sol";
import "./BidderRegistry.sol";

/// @title PreconfManager (faithful simplified version of mev-commit PreconfManager.sol)
/// @notice Stores preconfirmation commitments and coordinates slashing.
/// @dev Preserves the exact struct layout and function semantics from
///      github.com/primev/mev-commit/contracts/contracts/core/PreconfManager.sol
///      Key simplifications for PoC:
///        - No ZK proofs (just record block inclusion result directly)
///        - No BLS signature verification (commitment identified by index)
///        - No decay timestamps (focus on slashing logic)
///        - Oracle role is the MockOracle contract
contract PreconfManager {

    // ---------------------------------------------------------------
    // Structs — matching mev-commit OpenedCommitment struct
    // ---------------------------------------------------------------

    /// @notice Opened (revealed) commitment, corresponding to the real
    ///         OpenedCommitment struct in PreconfManager.sol.
    struct OpenedCommitment {
        address bidder;
        bool    isSettled;
        uint64  blockNumber;
        address committer;          // provider
        uint256 bidAmt;
        uint256 slashAmt;           // per-bid slash amount
        bytes32 commitmentDigest;
        string  txnHash;
        string  revertingTxHashes;  // "array of tx hashes that can revert"
    }

    // ---------------------------------------------------------------
    // State
    // ---------------------------------------------------------------

    ProviderRegistry public providerRegistry;
    BidderRegistry   public bidderRegistry;
    address          public oracle;       // only oracle can call initiateSlash

    /// @notice Opened commitments by index
    mapping(uint256 => OpenedCommitment) public openedCommitments;
    uint256 public commitmentCount;

    // ---------------------------------------------------------------
    // Events
    // ---------------------------------------------------------------
    event CommitmentStored(
        uint256 indexed index,
        address indexed committer,
        address indexed bidder,
        string  txnHash,
        uint256 slashAmt,
        uint64  blockNumber
    );
    event CommitmentSettled(uint256 indexed index, bool slashed);

    // ---------------------------------------------------------------
    // Constructor
    // ---------------------------------------------------------------
    constructor(
        address _providerRegistry,
        address _bidderRegistry,
        address _oracle
    ) {
        providerRegistry = ProviderRegistry(_providerRegistry);
        bidderRegistry   = BidderRegistry(_bidderRegistry);
        oracle           = _oracle;
    }

    // ---------------------------------------------------------------
    // Modifiers
    // ---------------------------------------------------------------
    modifier onlyOracle() {
        require(msg.sender == oracle, "PreconfManager: not oracle");
        _;
    }

    // ---------------------------------------------------------------
    // Setup
    // ---------------------------------------------------------------

    /// @notice Set oracle address. Can only be called once (after initial
    ///         deployment with placeholder). Used by deployment scripts to
    ///         resolve circular dependency: pm needs oracle addr, oracle needs pm addr.
    function setOracle(address _oracle) external {
        require(oracle == address(1), "oracle already set");
        oracle = _oracle;
    }

    // ---------------------------------------------------------------
    // Core functions
    // ---------------------------------------------------------------

    /// @notice Provider stores a preconfirmation commitment.
    /// @param bidder     Address of the bidder being served.
    /// @param txnHash    Hash of the committed transaction (as string, matching mev-commit).
    /// @param revertingTxHashes  Transactions permitted to revert without slashing.
    ///        Verbatim from mev-commit docs:
    ///        "Array of transaction hashes as strings that can revert."
    /// @param bidAmt     Payment to provider from bidder for the commitment.
    /// @param slashAmt   Amount slashed from provider stake if commitment violated.
    /// @param blockNumber  Target L1 block number.
    function storeCommitment(
        address bidder,
        string  calldata txnHash,
        string  calldata revertingTxHashes,
        uint256 bidAmt,
        uint256 slashAmt,
        uint64  blockNumber
    ) external returns (uint256 index) {
        // Provider must have enough stake to cover the slash amount + 5% fee
        uint256 requiredStake = (slashAmt * 105) / 100;
        require(
            providerRegistry.providerStake(msg.sender) >= requiredStake,
            "insufficient provider stake"
        );

        index = commitmentCount++;
        openedCommitments[index] = OpenedCommitment({
            bidder:           bidder,
            isSettled:        false,
            blockNumber:      blockNumber,
            committer:        msg.sender,
            bidAmt:           bidAmt,
            slashAmt:         slashAmt,
            commitmentDigest: keccak256(abi.encodePacked(txnHash, blockNumber)),
            txnHash:          txnHash,
            revertingTxHashes: revertingTxHashes
        });

        // Pay bidAmt from bidder to provider immediately (bid accepted)
        bidderRegistry.openBid(bidder, bidAmt, msg.sender);

        emit CommitmentStored(index, msg.sender, bidder, txnHash, slashAmt, blockNumber);
    }

    /// @notice Oracle calls this after detecting a commitment violation.
    ///         The committed transaction was absent from the target block and
    ///         is NOT in revertingTxHashes.
    /// @param commitmentIndex  Index of the violated commitment.
    function initiateSlash(uint256 commitmentIndex) external onlyOracle {
        OpenedCommitment storage c = openedCommitments[commitmentIndex];
        require(!c.isSettled, "already settled");

        c.isSettled = true;

        // Slash provider: transfers slashAmt to bidder + 5% to treasury
        providerRegistry.slash(c.committer, c.bidder, c.slashAmt);

        emit CommitmentSettled(commitmentIndex, true);
    }

    /// @notice Oracle calls this when the commitment was honored (tx included).
    function settleCommitment(uint256 commitmentIndex) external onlyOracle {
        OpenedCommitment storage c = openedCommitments[commitmentIndex];
        require(!c.isSettled, "already settled");
        c.isSettled = true;
        emit CommitmentSettled(commitmentIndex, false);
    }

    /// @notice Returns a commitment struct by index.
    /// @dev Necessary because Solidity external callers cannot assign a
    ///      public mapping tuple-return to a struct memory variable directly.
    function getCommitment(uint256 index)
        external view
        returns (OpenedCommitment memory)
    {
        return openedCommitments[index];
    }
}
