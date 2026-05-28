// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title ProviderRegistry (faithful simplified version of mev-commit ProviderRegistry.sol)
/// @notice Holds provider stake and executes slashing.
/// @dev Preserves the exact function signature and slashing logic from
///      github.com/primev/mev-commit/contracts/contracts/core/ProviderRegistry.sol
///      Simplified: no upgradability, no oracle role checks, no ERC20 support.
contract ProviderRegistry {
    // --- State ---

    /// @notice Stake balance per provider address
    mapping(address => uint256) public providerStake;

    /// @notice Address of the PreconfManager (only it can call slash)
    address public preconfManager;

    /// @notice Protocol treasury address (receives 5% slash fee)
    address public treasury;

    // --- Events (matching mev-commit) ---
    event ProviderRegistered(address indexed provider, uint256 stakedAmount);
    event FundsSlashed(address indexed provider, address indexed bidder, uint256 slashAmount);

    // --- Constructor ---
    constructor(address _treasury) {
        treasury = _treasury;
    }

    // --- Modifiers ---
    modifier onlyPreconfManager() {
        require(msg.sender == preconfManager, "ProviderRegistry: not PreconfManager");
        _;
    }

    // --- Setup ---
    function setPreconfManager(address _preconfManager) external {
        require(preconfManager == address(0), "already set");
        preconfManager = _preconfManager;
    }

    // --- Provider registration ---

    /// @notice Provider registers by staking ETH.
    function registerAndStake() external payable {
        require(msg.value > 0, "must stake > 0");
        providerStake[msg.sender] += msg.value;
        emit ProviderRegistered(msg.sender, msg.value);
    }

    // --- Slashing (called by PreconfManager.initiateSlash) ---

    /// @notice Slash provider stake. Transfers slashAmt to bidder + 5% fee to treasury.
    /// @dev Matches mev-commit: "exactly equal to the slash amount specified in the bid
    ///      they committed to, in addition to a 5% penalty fee."
    function slash(
        address provider,
        address bidder,
        uint256 slashAmt
    ) external onlyPreconfManager {
        uint256 fee = (slashAmt * 5) / 100; // 5% protocol fee
        uint256 totalDeducted = slashAmt + fee;

        require(providerStake[provider] >= totalDeducted, "insufficient stake");

        providerStake[provider] -= totalDeducted;

        // Transfer slash amount to bidder
        (bool ok1, ) = bidder.call{value: slashAmt}("");
        require(ok1, "bidder transfer failed");

        // Transfer fee to treasury
        (bool ok2, ) = treasury.call{value: fee}("");
        require(ok2, "treasury transfer failed");

        emit FundsSlashed(provider, bidder, slashAmt);
    }
}
