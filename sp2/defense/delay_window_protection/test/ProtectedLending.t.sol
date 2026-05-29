// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title ProtectedLendingTest
 * @notice Tests C4 application-layer defense: ProtectedLending blocks
 *         liquidation when user has a pending force-inclusion rescue.
 *
 * Three scenarios tested:
 *   1. ATTACK WITHOUT DEFENSE: baseline - attack succeeds (replicates Part 2)
 *   2. DEFENSE ACTIVE: victim registers rescue → liquidation blocked
 *   3. DEFENSE EXPIRED: grace period over → liquidation allowed again
 *
 * Gas overhead measurement:
 *   Baseline liquidation gas vs protected-path liquidation attempt gas.
 *
 * Run:
 *   forge test --fork-url $BASE_RPC --match-contract ProtectedLending -vvv
 *   (or without fork: uses MockOracle with fixed $2000 price)
 */

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "../src/ProtectedLending.sol";
import "../src/MockDepositWatcher.sol";

// Minimal oracle for self-contained testing (no fork needed)
contract MockOracle {
    mapping(address => uint256) public prices;
    function setPrice(address asset, uint256 price) external { prices[asset] = price; }
    function getAssetPrice(address asset) external view returns (uint256) { return prices[asset]; }
}

contract ProtectedLendingTest is Test {

    address constant WETH = 0x4200000000000000000000000000000000000006;

    MockOracle          oracle;
    MockDepositWatcher  watcher;
    ProtectedLending    lending;

    address victim    = makeAddr("victim");
    address adversary = makeAddr("adversary");

    uint256 constant WETH_PRICE    = 200_000_000_000; // $2000, 8 dec
    uint256 constant ATTACK_PRICE  = 160_000_000_000; // $1600, -20%
    uint256 constant VICTIM_WETH   = 5 ether;
    // Borrow at 90% of LTV: HF = LT/LTV*0.9 = 0.83/0.72 = 1.153
    uint256 constant VICTIM_USDC   = 7_200e6;

    function setUp() public {
        oracle  = new MockOracle();
        watcher = new MockDepositWatcher();
        lending = new ProtectedLending(address(oracle), address(watcher));

        oracle.setPrice(WETH, WETH_PRICE);

        vm.label(address(oracle),  "MockOracle");
        vm.label(address(watcher), "MockDepositWatcher");
        vm.label(address(lending), "ProtectedLending");
        vm.label(victim,           "Victim");
        vm.label(adversary,        "Adversary");
    }

    // ────────────────────────────────────────────────────────────────────────

    /**
     * @notice Scenario 1: Baseline - attack without defense (replicates Part 2).
     * Confirms the attack still works when defense is NOT active.
     * HF must be < 1 after price drop and liquidation must succeed.
     */
    function test_Attack_Succeeds_Without_Defense() public {
        console.log("\n=== SCENARIO 1: Baseline attack (no defense) ===");
        _openPosition();

        // Mid-window: price drops, adversary liquidates (T=6h)
        vm.warp(block.timestamp + 6 hours);
        oracle.setPrice(WETH, ATTACK_PRICE);

        uint256 hf = lending.healthFactor(victim);
        console.log("Victim HF after drop:", hf);
        assertLt(hf, 1e18, "Must be liquidatable");

        uint256 advBefore = lending.collateralWETH(adversary);
        vm.prank(adversary);
        lending.liquidate(victim, VICTIM_USDC / 2);
        uint256 seized = lending.collateralWETH(adversary) - advBefore;

        console.log("Adversary seized (wei):", seized);
        assertGt(seized, 0, "Attack must succeed without defense");

        // Rescue lands at T=12h - too late (block head, but damage done)
        vm.warp(block.timestamp + 6 hours);
        vm.prank(victim);
        lending.repay(VICTIM_USDC);
        console.log("[PASS] Baseline: attack succeeds without defense");
    }

    // ────────────────────────────────────────────────────────────────────────

    /**
     * @notice Scenario 2: Defense active - liquidation blocked during grace period.
     *
     * Victim registers their pending L1 rescue deposit BEFORE the window opens.
     * Adversary tries to liquidate at T=6h → REVERTS (grace period active).
     * Victim's rescue lands at T=12h → succeeds, position safe.
     */
    function test_Defense_Blocks_Liquidation_During_GracePeriod() public {
        console.log("\n=== SCENARIO 2: Defense active - liquidation BLOCKED ===");
        _openPosition();

        // T=0: Victim submits L1 deposit (victim is CENSORED on L2 — cannot tx)
        // Watcher observes TransactionDeposited on L1 and calls registerRescue
        // on behalf of victim. registerRescue() has NO msg.sender restriction.
        address watcher_addr = makeAddr("watcher");
        watcher.setPendingRescue(victim, true);
        vm.prank(watcher_addr);  // watcher calls, NOT victim
        lending.registerRescue(victim);
        console.log("Watcher registered rescue for victim (victim is censored, cannot call L2 tx).");

        assertTrue(lending.isProtected(victim), "Victim should be protected");
        console.log("Rescue registered. Grace period active for 12h.");

        // Measure gas: rescue registration overhead
        // (already called above; we measure a second call for gas tracking)

        // T=6h: Price drops, adversary tries to liquidate
        vm.warp(block.timestamp + 6 hours);
        oracle.setPrice(WETH, ATTACK_PRICE);

        uint256 hf = lending.healthFactor(victim);
        assertLt(hf, 1e18, "Position must be liquidatable by price");
        console.log("Victim HF after drop:", hf, "(< 1.0, normally liquidatable)");
        console.log("But defense is active. Attempting liquidation...");

        // Liquidation MUST revert
        vm.expectRevert("LiquidationBlocked: user has pending rescue deposit");
        vm.prank(adversary);
        lending.liquidate(victim, VICTIM_USDC / 2);
        console.log("[PASS] Liquidation REVERTED - defense works at T=6h");

        // Adversary gains nothing
        assertEq(lending.collateralWETH(adversary), 0, "Adversary must gain nothing");

        // T=12h: Victim's rescue lands (force-included tx)
        vm.warp(block.timestamp + 6 hours);
        watcher.setPendingRescue(victim, false); // deposit derived into L2
        vm.prank(victim);
        lending.repay(VICTIM_USDC);

        uint256 hfAfterRepay = lending.healthFactor(victim);
        console.log("Victim HF after rescue repay:", hfAfterRepay);
        assertGt(hfAfterRepay, 1e18, "Victim restored to health after rescue");
        console.log("[PASS] Defense scenario complete: victim saved");
    }

    // ────────────────────────────────────────────────────────────────────────

    /**
     * @notice Scenario 3: Grace period expires - liquidation resumes normally.
     * Ensures the defense does not permanently block liquidations (liveness).
     */
    function test_Defense_Expires_Allows_Liquidation() public {
        console.log("\n=== SCENARIO 3: Grace period expires - liveness preserved ===");
        _openPosition();

        watcher.setPendingRescue(victim, true);
        lending.registerRescue(victim);

        // Skip past grace period (victim's rescue never landed - edge case)
        vm.warp(block.timestamp + 13 hours);
        oracle.setPrice(WETH, ATTACK_PRICE);

        assertFalse(lending.isProtected(victim), "Grace period must have expired");
        console.log("Grace period expired. Liquidation should now be allowed.");

        uint256 hf = lending.healthFactor(victim);
        assertLt(hf, 1e18);

        uint256 advBefore = lending.collateralWETH(adversary);
        vm.prank(adversary);
        lending.liquidate(victim, VICTIM_USDC / 2);
        uint256 seized = lending.collateralWETH(adversary) - advBefore;

        assertGt(seized, 0, "Liquidation must succeed after grace period");
        console.log("[PASS] Liveness preserved: liquidation allowed after expiry");
    }

    // ────────────────────────────────────────────────────────────────────────

    /**
     * @notice Gas overhead measurement: compare liquidation attempts
     *         with and without the defense check.
     */
    function test_GasOverhead_Measurement() public {
        console.log("\n=== GAS OVERHEAD MEASUREMENT ===");
        _openPosition();
        oracle.setPrice(WETH, ATTACK_PRICE);

        // Scenario A: unprotected liquidation (baseline)
        uint256 gasA_start = gasleft();
        vm.prank(adversary);
        lending.liquidate(victim, VICTIM_USDC / 2);
        uint256 gasA_used = gasA_start - gasleft();
        console.log("Gas (unprotected liquidation):", gasA_used);

        // Reset for scenario B
        setUp();
        _openPosition();
        oracle.setPrice(WETH, ATTACK_PRICE);
        watcher.setPendingRescue(victim, true);
        lending.registerRescue(victim);

        // Scenario B: protected path (reverts, but we measure the attempt)
        uint256 gasB_start = gasleft();
        try lending.liquidate(victim, VICTIM_USDC / 2) {
            // Should not reach here
        } catch {
            uint256 gasB_used = gasB_start - gasleft();
            console.log("Gas (blocked liquidation attempt):", gasB_used);
            console.log("Defense overhead (approximate):", gasB_used);
        }

        // Registration overhead
        setUp();
        watcher.setPendingRescue(makeAddr("u"), true);
        uint256 gasR_start = gasleft();
        lending.registerRescue(makeAddr("u"));
        uint256 gasR_used = gasR_start - gasleft();
        console.log("Gas (registerRescue call):", gasR_used);
        console.log("(One-time cost to activate protection)");
    }

    // ────────────────────────────────────────────────────────────────────────

    function _openPosition() internal {
        vm.prank(victim);
        lending.supply(VICTIM_WETH);
        vm.prank(victim);
        lending.borrow(VICTIM_USDC);

        uint256 hf = lending.healthFactor(victim);
        assertGt(hf, 1e18, "Initial HF must be > 1.0");
        assertLt(hf, 1.3e18, "Initial HF near threshold");
    }
}
