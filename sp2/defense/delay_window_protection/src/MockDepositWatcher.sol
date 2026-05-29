// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title MockDepositWatcher
 * @notice Simulates the L1 deposit watcher oracle for testing.
 *
 * In production, this would be an on-chain oracle that monitors
 * OptimismPortal.TransactionDeposited events on L1 and attests
 * whether a specific user has a pending rescue deposit.
 *
 * Two upgrade paths to trustless:
 * (A) EIP-4788 beacon root + SSZ Merkle proof of the L1 deposit event
 * (B) Cross-chain messaging (L1 -> L2 message confirming deposit exists)
 */
contract MockDepositWatcher {
    mapping(address => bool) private _pendingRescues;

    /// @notice Operator sets whether a user has a pending rescue (test helper)
    function setPendingRescue(address user, bool pending) external {
        _pendingRescues[user] = pending;
    }

    function hasPendingRescue(address user) external view returns (bool) {
        return _pendingRescues[user];
    }
}
