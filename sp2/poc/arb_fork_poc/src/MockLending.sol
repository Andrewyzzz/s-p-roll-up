// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title MockLending
 * @notice Minimal lending protocol that replicates the health-factor / liquidation
 *         mechanics needed for the inclusion-without-outcome PoC.
 *
 *         Intentionally simplified: single collateral (WETH), single debt (USDC).
 *         Liquidation threshold = 80%, liquidation bonus = 5%.
 */

interface IMockOracle {
    function price() external view returns (uint256); // USD, 18 dec
}

contract MockLending {

    // ── Config ────────────────────────────────────────────────────────────
    uint256 public constant LT  = 80;   // liquidation threshold %
    uint256 public constant BONUS = 5;  // liquidation bonus %

    IMockOracle public oracle;

    // ── State ─────────────────────────────────────────────────────────────
    mapping(address => uint256) public collateral; // WETH deposited (wei)
    mapping(address => uint256) public debt;       // USDC borrowed  (1e6)

    event Supplied(address user, uint256 wethAmount);
    event Borrowed(address user, uint256 usdcAmount);
    event Repaid(address user, uint256 usdcAmount);
    event Liquidated(address user, address liquidator, uint256 usdcRepaid, uint256 wethSeized);

    constructor(address _oracle) {
        oracle = IMockOracle(_oracle);
    }

    // ── User actions ──────────────────────────────────────────────────────

    function supply(uint256 wethAmount) external {
        collateral[msg.sender] += wethAmount;
        emit Supplied(msg.sender, wethAmount);
    }

    function borrow(uint256 usdcAmount) external {
        require(healthFactor(msg.sender) > 1e18 || debt[msg.sender] == 0, "insufficient collateral");
        debt[msg.sender] += usdcAmount;
        require(healthFactor(msg.sender) > 1e18, "borrow would breach LT");
        emit Borrowed(msg.sender, usdcAmount);
    }

    function repay(uint256 usdcAmount) external {
        uint256 repaid = usdcAmount > debt[msg.sender] ? debt[msg.sender] : usdcAmount;
        debt[msg.sender] -= repaid;
        emit Repaid(msg.sender, repaid);
    }

    // ── Liquidation ───────────────────────────────────────────────────────

    function liquidate(address user, uint256 usdcRepay) external {
        require(healthFactor(user) < 1e18, "position healthy");
        require(usdcRepay <= debt[user], "repay > debt");

        // WETH to seize = (usdcRepay / wethPrice) * (1 + BONUS%)
        // usdcRepay is in 1e6, price is in 1e18 USD/WETH
        // => wethToSeize (wei) = usdcRepay * 1e12 * 1e18 / price * (100 + BONUS) / 100
        uint256 wethPrice = oracle.price(); // USD per WETH, 18 dec
        uint256 wethToSeize = (usdcRepay * 1e12 * 1e18 / wethPrice) * (100 + BONUS) / 100;

        require(wethToSeize <= collateral[user], "insufficient collateral to seize");

        debt[user] -= usdcRepay;
        collateral[user] -= wethToSeize;
        collateral[msg.sender] += wethToSeize; // transfer seized WETH to liquidator

        emit Liquidated(user, msg.sender, usdcRepay, wethToSeize);
    }

    // ── View ──────────────────────────────────────────────────────────────

    /**
     * @return hf Health factor scaled by 1e18 (> 1e18 = healthy, < 1e18 = liquidatable)
     */
    function healthFactor(address user) public view returns (uint256 hf) {
        if (debt[user] == 0) return type(uint256).max;

        uint256 wethPrice = oracle.price();
        // collateralValueUSD (18 dec) = collateral (18 dec) * price (18 dec) / 1e18
        uint256 collateralUSD = collateral[user] * wethPrice / 1e18;
        // debtUSD (18 dec) = debt (6 dec) * 1e12
        uint256 debtUSD = debt[user] * 1e12;

        hf = (collateralUSD * LT / 100) * 1e18 / debtUSD;
    }
}
