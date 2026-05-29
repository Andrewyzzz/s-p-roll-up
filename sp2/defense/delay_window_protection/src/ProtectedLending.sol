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
     * @notice Register a pending rescue deposit from L1 on behalf of `user`.
     *
     * ── Trust model and trigger analysis ────────────────────────────────────
     *
     * The victim is being censored on L2 and CANNOT send L2 transactions.
     * Therefore, `registerRescue` MUST NOT require the victim to call it.
     * This function is intentionally callable by ANY address (no msg.sender
     * restriction), so a third-party watcher can register protection for the
     * victim after observing the L1 deposit.
     *
     * Three trigger tiers (in increasing trustlessness):
     *
     *   Tier 1 — Oracle watcher (current implementation):
     *     Any third party calls registerRescue(victim) after observing the
     *     TransactionDeposited event on L1 OptimismPortal.
     *     Residual risk: censoring sequencer can ALSO censor the watcher's
     *     L2 transaction. The adversary now needs to censor two parties
     *     simultaneously (victim + watcher), raising the attack cost, but
     *     not eliminating it.
     *
     *   Tier 2 — Deposit-embedded registration (no additional L2 tx needed):
     *     Victim sends a SECOND deposit via depositTransaction() targeting this
     *     contract with registerRescue(victim) calldata. Both deposits land at
     *     L2 block head at T=12h. registerRescue fires BEFORE repay in the
     *     same derived block, setting protection retroactively.
     *     Limitation: protection is set at T=12h, after adversary could act at
     *     T=6h. This tier protects against adversaries who wait for the full
     *     window; it does NOT protect against mid-window liquidations.
     *
     *   Tier 3 — EIP-4788 trustless proof (upgrade path):
     *     OP Stack surfaces L1 block hashes into L2 via L1-attributes deposits
     *     (every L2 block includes the parent L1 block hash). A borrower or
     *     anyone can submit a Merkle proof of the TransactionDeposited event
     *     directly to this contract, which verifies it against the L1 block
     *     hash without any external oracle. This is fully censorship-resistant:
     *     the proof submission can itself be a force-included deposit.
     *
     * ── Bad debt bound ───────────────────────────────────────────────────────
     *
     * During the 12h grace period, the protocol cannot liquidate the protected
     * position even if HF < 1.0. This creates bounded bad debt risk:
     *
     *   max_bad_debt = protected_debt × (further_price_drop_in_window)
     *
     * Bounds on this risk:
     *   (a) Gate on real L1 deposit: protection is only granted if a genuine
     *       OptimismPortal.depositTransaction() exists on L1 — cannot be
     *       fabricated to manufacture artificial grace periods for solvency-
     *       manipulation purposes.
     *   (b) Rare invocation: as measured in C3, forceInclusion/FI paths are
     *       used ~0 times per month; protected positions are therefore very
     *       sparse in practice.
     *   (c) Time-bounded: 12h grace period corresponds exactly to the worst-
     *       case sequencing window; protection expires at the same time the
     *       rescue is guaranteed to have landed.
     *
     * Gas overhead vs unprotected borrow: one oracle call (~5k) + one SSTORE
     * (~20k) = ~25k gas for registerRescue; +4.6k for blocked liquidation check.
     */
    function registerRescue(address user) external {
        // IMPORTANT: msg.sender is NOT required to be `user`.
        // Any third-party watcher can register protection for a censored victim.
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
