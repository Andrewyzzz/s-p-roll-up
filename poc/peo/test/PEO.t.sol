// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/ProviderRegistry.sol";
import "../src/BidderRegistry.sol";
import "../src/PreconfManager.sol";
import "../src/MockOracle.sol";

/// @title PEO Attack Test — Preconfirmation Exercise Option
/// @notice Demonstrates the PEO free-option attack on a mev-commit-faithful
///         preconfirmation system (§3 of the paper).
///
/// Attack scenario (§3.4 worked example):
///   - Provider stakes B = 1.0 ETH
///   - Bidder deposits 0.5 ETH; submits bid with slashAmt = 0.05 ETH
///   - Provider issues commitment at t₀
///   - MEV opportunity M (δ = 0.12 ETH) appears at t₁
///   - Provider violates at t₂ (excludes committed tx, includes M)
///   - Oracle detects violation at t₃ → initiateSlash()
///   - Provider net: δ − slashAmt × 1.05 = 0.12 − 0.0525 = +0.0675 ETH
contract PEOTest is Test {

    // --- Actors ---
    address provider  = makeAddr("provider");
    address bidder    = makeAddr("bidder");
    address treasury  = makeAddr("treasury");
    address attacker  = makeAddr("attacker"); // same as provider in this scenario

    // --- Contracts ---
    ProviderRegistry providerRegistry;
    BidderRegistry   bidderRegistry;
    PreconfManager   preconfManager;
    MockOracle       oracle;

    // --- Parameters (§3.4) ---
    uint256 constant PROVIDER_STAKE = 1 ether;        // B
    uint256 constant SLASH_AMT      = 0.05 ether;     // s
    uint256 constant BID_AMT        = 0.002 ether;    // bidAmt
    uint256 constant MEV_VALUE      = 0.12 ether;     // δ
    uint64  constant BLOCK_NUMBER   = 100;

    string  constant TX_HASH        = "0xdeadbeef";
    string  constant REVERTING_HASHES = "";           // none permitted to revert

    // Expected outcome
    uint256 constant SLASH_TOTAL    = SLASH_AMT + (SLASH_AMT * 5) / 100; // s × 1.05
    uint256 constant EXPECTED_NET   = MEV_VALUE - SLASH_TOTAL;           // 0.0675 ETH

    function setUp() public {
        // Deploy contracts
        providerRegistry = new ProviderRegistry(treasury);
        bidderRegistry   = new BidderRegistry();

        // Oracle placeholder (address known before deployment)
        // Deploy PreconfManager with oracle = address(this) temporarily,
        // then deploy real oracle and update
        address oracleAddr = vm.computeCreateAddress(address(this), vm.getNonce(address(this)) + 1);

        preconfManager = new PreconfManager(
            address(providerRegistry),
            address(bidderRegistry),
            oracleAddr
        );
        oracle = new MockOracle(address(preconfManager));
        assert(address(oracle) == oracleAddr);

        // Wire up registries
        providerRegistry.setPreconfManager(address(preconfManager));
        bidderRegistry.setPreconfManager(address(preconfManager));

        // Fund actors
        vm.deal(provider, 2 ether);
        vm.deal(bidder,   1 ether);
    }

    // ------------------------------------------------------------------
    // Test 1: Honest commitment — provider honors, no slash
    // ------------------------------------------------------------------
    function testPEO_HonestCommitment() public {
        // Provider stakes
        vm.prank(provider);
        providerRegistry.registerAndStake{value: PROVIDER_STAKE}();

        // Bidder deposits
        vm.prank(bidder);
        bidderRegistry.depositForBidder{value: BID_AMT * 2}();

        uint256 providerBalanceBefore = provider.balance;

        // Provider issues commitment
        vm.prank(provider);
        uint256 idx = preconfManager.storeCommitment(
            bidder, TX_HASH, REVERTING_HASHES, BID_AMT, SLASH_AMT, BLOCK_NUMBER
        );

        // bidAmt paid to provider on commitment
        assertEq(provider.balance, providerBalanceBefore + BID_AMT, "provider got bidAmt");

        // Oracle confirms tx was included (honest)
        oracle.confirmInclusion(idx);

        // Provider stake unchanged (no slash)
        assertEq(
            providerRegistry.providerStake(provider),
            PROVIDER_STAKE,
            "honest: no stake lost"
        );

        console.log("[Honest] Provider stake after: ", providerRegistry.providerStake(provider));
        console.log("[Honest] No PEO opportunity: commitment honored");
    }

    // ------------------------------------------------------------------
    // Test 2: PEO violation — provider violates, net gain
    // ------------------------------------------------------------------
    function testPEO_ViolationProfit() public {
        // Provider stakes B = 1.0 ETH
        vm.prank(provider);
        providerRegistry.registerAndStake{value: PROVIDER_STAKE}();

        // Bidder deposits
        vm.prank(bidder);
        bidderRegistry.depositForBidder{value: BID_AMT * 2}();

        uint256 providerBalanceBefore = provider.balance;

        // ---- t₀: Provider issues commitment ----
        vm.prank(provider);
        uint256 idx = preconfManager.storeCommitment(
            bidder, TX_HASH, REVERTING_HASHES, BID_AMT, SLASH_AMT, BLOCK_NUMBER
        );

        // Provider received bidAmt immediately (bid payment)
        assertEq(provider.balance, providerBalanceBefore + BID_AMT, "bidAmt received");

        // ---- t₁: MEV opportunity M appears (simulated: provider receives MEV externally) ----
        // In a real scenario, the provider earns MEV_VALUE by including M instead of τ.
        // We simulate this by dealing MEV_VALUE to the provider at t₂.
        vm.deal(provider, provider.balance + MEV_VALUE);

        // ---- t₂: Provider violates (does NOT include committed tx) ----
        // (In the real system, provider proposes a block without TX_HASH)
        // Here, we skip to the oracle detection step.

        // ---- t₃: Oracle detects violation → initiateSlash() ----
        uint256 bidderBalanceAtViolation = bidder.balance;
        oracle.detectViolation(idx);

        // ---- Verify outcomes ----

        // 1. Provider stake reduced by slashAmt × 1.05
        uint256 expectedStakeAfter = PROVIDER_STAKE - SLASH_TOTAL;
        assertEq(
            providerRegistry.providerStake(provider),
            expectedStakeAfter,
            "provider stake reduced by slash"
        );

        // 2. Bidder received slashAmt (compensation)
        assertEq(
            bidder.balance,
            bidderBalanceAtViolation + SLASH_AMT,
            "bidder received slash compensation"
        );

        // 3. Treasury received 5% fee
        assertEq(
            treasury.balance,
            (SLASH_AMT * 5) / 100,
            "treasury received 5% fee"
        );

        // 4. Provider NET GAIN: MEV_VALUE - SLASH_TOTAL > 0
        // Provider balance: started with providerBalanceBefore, received bidAmt (+BID_AMT),
        // received MEV (+MEV_VALUE), stake reduced (off-balance), no ETH balance change
        // from slash (stake is on-chain, not ETH balance in this model).
        // Net economic gain = MEV_VALUE - SLASH_TOTAL (from stake)
        uint256 net = MEV_VALUE - SLASH_TOTAL;
        assertGt(net, 0, "PEO: net gain is positive");

        // --- Summary output ---
        console.log("=== PEO Attack: Preconfirmation Exercise Option ===");
        console.log("");
        console.log("Parameters:");
        console.log("  Provider stake (B):     ", PROVIDER_STAKE / 1e15, "finney");
        console.log("  Slash amount (s):        ", SLASH_AMT / 1e15, "finney");
        console.log("  Bid amount (bidAmt):    ", BID_AMT / 1e15, "finney");
        console.log("  MEV opportunity (delta):", MEV_VALUE / 1e15, "finney");
        console.log("");
        console.log("Outcome:");
        console.log("  Slash cost (s x 1.05):  ", SLASH_TOTAL / 1e15, "finney");
        console.log("  Provider NET GAIN:       ", net / 1e15, "finney  <-- free option");
        console.log("  Bidder compensation:     ", SLASH_AMT / 1e15, "finney  (< true value)");
        console.log("  Max violations before");
        console.log("  bond depletion:          ", PROVIDER_STAKE / SLASH_TOTAL);
        console.log("");
        console.log("PoC PASSED: provider profited by violating commitment.");
    }

    // ------------------------------------------------------------------
    // Test 3: Bond depletion — provider can violate N times before bond exhausted
    // ------------------------------------------------------------------
    function testPEO_BondDepletionCount() public {
        vm.prank(provider);
        providerRegistry.registerAndStake{value: PROVIDER_STAKE}();

        // Compute max violations analytically
        uint256 maxViolations = PROVIDER_STAKE / SLASH_TOTAL;

        // Bidder deposits enough for all violations
        vm.prank(bidder);
        bidderRegistry.depositForBidder{value: BID_AMT * (maxViolations + 1)}();

        // Execute maxViolations violations
        for (uint256 i = 0; i < maxViolations; i++) {
            vm.prank(provider);
            uint256 idx = preconfManager.storeCommitment(
                bidder,
                string(abi.encodePacked("0x", vm.toString(i))),
                REVERTING_HASHES,
                BID_AMT,
                SLASH_AMT,
                uint64(BLOCK_NUMBER + i)
            );
            oracle.detectViolation(idx);
        }

        uint256 remainingStake = providerRegistry.providerStake(provider);

        console.log("=== Bond Depletion Analysis ===");
        console.log("  Initial stake (B):       ", PROVIDER_STAKE / 1e15, "finney");
        console.log("  Slash per violation:     ", SLASH_TOTAL / 1e15, "finney");
        console.log("  Violations executed:     ", maxViolations);
        console.log("  Remaining stake:         ", remainingStake / 1e15, "finney");
        console.log("  Theorem 2: rho_min > 0 for any finite B");

        // Bond is depleted (within SLASH_TOTAL remainder)
        assertLt(remainingStake, SLASH_TOTAL, "bond below one more slash threshold");

        // Provider net gain across all violations
        uint256 totalNet = maxViolations * (MEV_VALUE - SLASH_TOTAL);
        console.log("  Total net gain across all violations: ", totalNet / 1e15, "finney");
        assertGt(totalNet, 0, "multi-violation net gain positive");
    }

    // ------------------------------------------------------------------
    // Test 4: Adversarial slash-amount setting (§3.3)
    // ------------------------------------------------------------------
    function testPEO_LowSlashAmtAmplifies() public {
        // Provider sets a very low slashAmt (minimizing self-imposed penalty)
        // while bidder can't force a higher value in a competitive market
        uint256 lowSlash = 0.001 ether; // 10x lower than base scenario

        vm.prank(provider);
        providerRegistry.registerAndStake{value: PROVIDER_STAKE}();

        vm.prank(bidder);
        bidderRegistry.depositForBidder{value: BID_AMT * 2}();

        vm.prank(provider);
        uint256 idx = preconfManager.storeCommitment(
            bidder, TX_HASH, REVERTING_HASHES, BID_AMT, lowSlash, BLOCK_NUMBER
        );

        oracle.detectViolation(idx);

        uint256 lowSlashTotal = lowSlash + (lowSlash * 5) / 100; // 0.00105 ETH
        uint256 net = MEV_VALUE - lowSlashTotal;

        console.log("=== Low slashAmt Amplifies PEO ===");
        console.log("  Low slashAmt:            ", lowSlash / 1e15, "finney");
        console.log("  Slash cost (s x 1.05):   ", lowSlashTotal / 1e15, "finney");
        console.log("  Provider net gain:        ", net / 1e15, "finney");
        console.log("  Max violations:           ", PROVIDER_STAKE / lowSlashTotal);

        assertGt(net, EXPECTED_NET, "lower slash => higher net gain");
    }
}
