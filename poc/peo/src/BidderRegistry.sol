// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title BidderRegistry (faithful simplified version of mev-commit BidderRegistry.sol)
/// @notice Manages bidder deposits and bid payouts.
contract BidderRegistry {
    mapping(address => uint256) public bidderDeposit;
    address public preconfManager;

    event BidderDeposited(address indexed bidder, uint256 amount);
    event BidOpened(address indexed bidder, uint256 bidAmt);

    constructor() {}

    modifier onlyPreconfManager() {
        require(msg.sender == preconfManager, "not PreconfManager");
        _;
    }

    function setPreconfManager(address _pm) external {
        require(preconfManager == address(0), "already set");
        preconfManager = _pm;
    }

    function depositForBidder() external payable {
        bidderDeposit[msg.sender] += msg.value;
        emit BidderDeposited(msg.sender, msg.value);
    }

    /// @notice Called by PreconfManager when a bid is opened.
    ///         Releases bidAmt from deposit to pay the provider.
    function openBid(
        address bidder,
        uint256 bidAmt,
        address provider
    ) external onlyPreconfManager {
        require(bidderDeposit[bidder] >= bidAmt, "insufficient deposit");
        bidderDeposit[bidder] -= bidAmt;
        (bool ok, ) = provider.call{value: bidAmt}("");
        require(ok, "provider payment failed");
        emit BidOpened(bidder, bidAmt);
    }
}
