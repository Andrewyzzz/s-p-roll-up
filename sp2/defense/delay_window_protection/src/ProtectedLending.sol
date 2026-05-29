// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title ProtectedLending
 * @notice C4 Defense prototype: Application-layer liquidation protection for
 *         users who have a pending force-inclusion rescue on L1.
 *
 * Core defense: Before clearing a liquidation, the lending protocol checks
 * whether the liquidation target has a *pending forced deposit* recorded
 * on the L1 OptimismPortal. If yes, the liquidation is blocked for a
 * grace period equal to the sequencing window (12 h), giving the rescue
 * time to land.
 *
 * This addresses the REAL attack vector (delay-window), not just the
 * symptom (inclusion without outcome).
 *
 * ── Design choices ──────────────────────────────────────────────────────────
 *
 * Option A (on-chain L1 proof, fully trustless):
 *   User submits a Merkle proof of their OptimismPortal deposit event on L1.
 *   The lending contract verifies it against a trusted L1 block hash oracle.
 *   Cost: high (proof generation + verification gas).
 *
 * Option B (oracle-attested, implemented here):
 *   A lightweight "deposit watcher" oracle attests that a specific user has
 *   a pending TransactionDeposited event on L1 OptimismPortal.
 *   The user calls registerRescue(proof) → oracle verifies → grace period set.
 *   Cost: one oracle call per rescue registration.
 *   Deployed-by: Aave governance or any permissionless operator.
 *
 * We prototype Option B here as it is the most immediately deployable.
 * Option A is noted as the trustless upgrade path.
 *
 * ── On-chain verified Aave V3 Base parameters ──────────────────────────────
 *   LTV     = 8000 bps = 80.0%   (cast call getReserveData WETH, bits 0-15)
 *   LT      = 8300 bps = 83.0%   (bits 16-31)
 *   Bonus   = 10500 bps → 5%     (bits 32-47)
 */

interface IAaveOracle {
    function getAssetPrice(address asset) external view returns (uint256);
}

interface IDepositWatcher {
    /**
     * @return True if `user` has a TransactionDeposited event on L1
     *         OptimismPortal within the last SEQUENCING_WINDOW seconds
     *         that has NOT yet been derived into L2.
     */
    function hasPendingRescue(address user) external view returns (bool);
}

contract ProtectedLending {

    // ── Aave V3 Base parameters (on-chain verified) ──────────────────────────
    uint256 public constant LT_BPS      = 8300;   // 83.0%
    uint256 public constant BONUS_BPS   = 500;    // 5.0%
    uint256 public constant BPS         = 10000;

    // ── OP Stack sequencing window ───────────────────────────────────────────
    uint256 public constant SEQUENCING_WINDOW = 12 hours;

    // ── Addresses ────────────────────────────────────────────────────────────
    address public oracle;
    address public depositWatcher; // L1 deposit watcher oracle

    // ── State ─────────────────────────────────────────────────────────────────
    mapping(address => uint256) public collateralWETH;
    mapping(address => uint256) public debtUSDC;

    // Grace period: user → timestamp until which they cannot be liquidated
    // Set when a pending rescue deposit is registered
    mapping(address => uint256) public rescueProtectedUntil;

    // ── Events ────────────────────────────────────────────────────────────────
    event LiquidationBlocked(
        address indexed user,
        address indexed liquidator,
        uint256 protectedUntil,
        string reason
    );
    event RescueRegistered(address indexed user, uint256 protectedUntil);
    event Liquidated(
        address indexed user,
        address indexed liquidator,
        uint256 usdcRepaid,
        uint256 wethSeized,
        uint256 adversaryNetProfitUSD
    );

    constructor(address _oracle, address _depositWatcher) {
        oracle        = _oracle;
        depositWatcher = _depositWatcher;
    }

    // ── User actions ──────────────────────────────────────────────────────────

    function supply(uint256 wethAmt) external {
        collateralWETH[msg.sender] += wethAmt;
    }

    function borrow(uint256 usdcAmt) external {
        debtUSDC[msg.sender] += usdcAmt;
        require(healthFactor(msg.sender) > 1e18, "borrow exceeds LT");
    }

    function repay(uint256 usdcAmt) external {
        uint256 r = usdcAmt > debtUSDC[msg.sender]
            ? debtUSDC[msg.sender] : usdcAmt;
        debtUSDC[msg.sender] -= r;
    }

    /**
     * @notice Register a pending rescue deposit from L1.
     *
     * User calls this after submitting OptimismPortal.depositTransaction()
     * on L1. The depositWatcher oracle verifies the deposit exists.
     * If confirmed, the user's position is protected from liquidation for
     * SEQUENCING_WINDOW seconds (12 h).
     *
     * Gas overhead vs unprotected borrow: one oracle call + one SSTORE.
     */
    function registerRescue(address user) external {
        require(
            IDepositWatcher(depositWatcher).hasPendingRescue(user),
            "No pending rescue deposit found on L1"
        );
        uint256 protectedUntil = block.timestamp + SEQUENCING_WINDOW;
        rescueProtectedUntil[user] = protectedUntil;
        emit RescueRegistered(user, protectedUntil);
    }

    // ── Liquidation (with protection check) ──────────────────────────────────

    /**
     * @notice Liquidate a position — blocked if user has a pending rescue.
     *
     * DEFENSE: If the liquidation target has registered a pending rescue
     * deposit (and the grace period has not expired), liquidation is reverted.
     * This gives the rescue tx time to land at L2 block head.
     */
    function liquidate(address user, uint256 usdcRepay) external {
        // ── DEFENSE: check rescue grace period ──────────────────────────────
        uint256 protectedUntil = rescueProtectedUntil[user];
        if (protectedUntil > block.timestamp) {
            emit LiquidationBlocked(
                user,
                msg.sender,
                protectedUntil,
                "Pending force-inclusion rescue: liquidation blocked until rescue lands"
            );
            revert("LiquidationBlocked: user has pending rescue deposit");
        }

        // ── Normal liquidation logic ─────────────────────────────────────────
        require(healthFactor(user) < 1e18, "position healthy");
        require(usdcRepay <= debtUSDC[user], "repay > debt");

        uint256 wethPrice = IAaveOracle(oracle).getAssetPrice(
            0x4200000000000000000000000000000000000006
        );
        uint256 wethToSeize = usdcRepay
            * 1e12 * 1e8 / wethPrice
            * (BPS + BONUS_BPS) / BPS;

        require(wethToSeize <= collateralWETH[user], "insufficient collateral");

        debtUSDC[user]             -= usdcRepay;
        collateralWETH[user]       -= wethToSeize;
        collateralWETH[msg.sender] += wethToSeize;

        // Economic breakdown: net profit = bonus portion only
        uint256 seizedUSD  = wethToSeize * wethPrice / 1e8 / 1e12;
        uint256 repaidUSD  = usdcRepay;
        uint256 netProfit  = seizedUSD > repaidUSD ? seizedUSD - repaidUSD : 0;

        emit Liquidated(user, msg.sender, usdcRepay, wethToSeize, netProfit);
    }

    // ── View ──────────────────────────────────────────────────────────────────

    function healthFactor(address user) public view returns (uint256) {
        if (debtUSDC[user] == 0) return type(uint256).max;
        uint256 price  = IAaveOracle(oracle).getAssetPrice(
            0x4200000000000000000000000000000000000006
        );
        uint256 colUSD = collateralWETH[user] * price / 1e8;
        uint256 debtUSD = debtUSDC[user] * 1e12;
        return (colUSD * LT_BPS / BPS) * 1e18 / debtUSD;
    }

    function isProtected(address user) external view returns (bool) {
        return rescueProtectedUntil[user] > block.timestamp;
    }
}
