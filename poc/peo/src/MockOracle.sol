// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./PreconfManager.sol";

/// @title MockOracle
/// @notice Simulates Oracle.sol from mev-commit.
///         In production, Oracle.sol monitors L1 blocks and detects
///         commitment violations. Here, the test calls detectViolation()
///         directly to simulate the oracle observing that a committed
///         transaction was NOT included in the target block.
///
/// @dev The real mev-commit Oracle.sol:
///        - Subscribes to L1 block events via BlockTracker
///        - Checks if committed txnHash is present in the finalized block
///        - If absent (and not in revertingTxHashes): calls PreconfManager.initiateSlash()
///        - If present: calls PreconfManager.settleCommitment()
contract MockOracle {

    PreconfManager public preconfManager;

    event ViolationDetected(
        uint256 indexed commitmentIndex,
        string  txnHash,
        uint64  blockNumber
    );
    event CommitmentHonored(
        uint256 indexed commitmentIndex,
        string  txnHash,
        uint64  blockNumber
    );

    constructor(address _preconfManager) {
        preconfManager = PreconfManager(_preconfManager);
    }

    /// @notice Simulates oracle detecting that the committed transaction
    ///         was NOT included in the target block (violation).
    ///         In production: this is triggered automatically by monitoring L1.
    function detectViolation(uint256 commitmentIndex) external {
        PreconfManager.OpenedCommitment memory c =
            preconfManager.getCommitment(commitmentIndex);
        emit ViolationDetected(commitmentIndex, c.txnHash, c.blockNumber);
        preconfManager.initiateSlash(commitmentIndex);
    }

    /// @notice Simulates oracle confirming the committed transaction was included.
    function confirmInclusion(uint256 commitmentIndex) external {
        PreconfManager.OpenedCommitment memory c =
            preconfManager.getCommitment(commitmentIndex);
        emit CommitmentHonored(commitmentIndex, c.txnHash, c.blockNumber);
        preconfManager.settleCommitment(commitmentIndex);
    }
}
