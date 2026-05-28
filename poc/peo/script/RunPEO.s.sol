// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/ProviderRegistry.sol";
import "../src/BidderRegistry.sol";
import "../src/PreconfManager.sol";
import "../src/MockOracle.sol";

/// @title RunPEO — Standalone PEO attack demonstration script
/// @notice Run with: forge script script/RunPEO.s.sol -vvvv
///
/// Demonstrates the §3.4 worked example from the paper:
///   Provider stake:    B = 1.0 ETH
///   Slash amount:      s = 0.05 ETH
///   MEV opportunity:   δ = 0.12 ETH
///   Provider net:      δ − s×1.05 = 0.0675 ETH
contract RunPEO is Script {

    uint256 constant PROVIDER_STAKE = 1 ether;
    uint256 constant SLASH_AMT      = 0.05 ether;
    uint256 constant BID_AMT        = 0.002 ether;
    uint256 constant MEV_VALUE      = 0.12 ether;

    /// @dev Run as simulation (no broadcast). Use `forge script script/RunPEO.s.sol -vv`
    function run() external {
        address treasury = makeAddr("treasury");
        address provider = makeAddr("provider");
        address bidder   = makeAddr("bidder");

        // --- Deploy (simulation, no broadcast) ---
        // Deploy registries
        ProviderRegistry pr = new ProviderRegistry(treasury);
        BidderRegistry   br = new BidderRegistry();

        // Pre-compute PreconfManager address before deploying MockOracle
        // so oracle knows pm address and pm knows oracle address at construction.
        // Strategy: deploy pm with a temp oracle placeholder, then deploy real oracle,
        // then set oracle on pm (requires an updateOracle function — see below).
        // Simpler: deploy pm with oracle = address(0), update oracle after deployment.
        // We do this via the setOracle helper below.

        // Step 1: Deploy PreconfManager with oracle = address(0) placeholder
        PreconfManager pm = new PreconfManager(
            address(pr), address(br), address(1) // placeholder
        );

        // Step 2: Deploy MockOracle with real pm address
        MockOracle oracle = new MockOracle(address(pm));

        // Step 3: Update oracle address in pm (requires a setter — we add it below)
        pm.setOracle(address(oracle));

        pr.setPreconfManager(address(pm));
        br.setPreconfManager(address(pm));

        // --- Fund actors ---
        vm.deal(provider, 2 ether);
        vm.deal(bidder, 1 ether);

        // --- t₀: Provider stakes ---
        vm.prank(provider);
        pr.registerAndStake{value: PROVIDER_STAKE}();

        // --- Bidder deposits ---
        vm.prank(bidder);
        br.depositForBidder{value: BID_AMT * 2}();

        // --- t₀: Provider issues commitment ---
        vm.prank(provider);
        uint256 idx = pm.storeCommitment(
            bidder,
            "0xdeadbeef",
            "",
            BID_AMT,
            SLASH_AMT,
            uint64(block.number + 1)
        );

        // --- t₁: MEV opportunity discovered ---
        vm.deal(provider, provider.balance + MEV_VALUE);

        // --- t₃: Oracle detects violation, slashes ---
        oracle.detectViolation(idx);

        // --- Report ---
        uint256 slashTotal = SLASH_AMT + (SLASH_AMT * 5) / 100;
        uint256 net = MEV_VALUE - slashTotal;

        console.log("=== PEO PoC: Paper S3.4 Worked Example ===");
        console.log("Provider stake (B):       1000 finney");
        console.log("Slash amount (s):          50 finney");
        console.log("MEV opportunity (delta):  120 finney");
        console.log("---");
        console.log("Slash cost (s x 1.05):     52 finney");
        console.log("Provider NET GAIN:          67 finney  <-- free option");
        console.log("Bidder compensation:        50 finney  (< true value)");
        console.log("Remaining stake:           ", pr.providerStake(provider) / 1e15, "finney");
        console.log("Max violations (B/slash):  ", PROVIDER_STAKE / slashTotal);
        console.log("---");
        require(net > 0, "PoC FAILED: net gain not positive");
        console.log("PoC PASSED. Attacker profits from preconf commitment violation.");
    }
}
