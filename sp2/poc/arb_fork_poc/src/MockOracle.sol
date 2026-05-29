// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title MockOracle
 * @notice Settable price oracle. The adversarial sequencer can insert a price-update
 *         call (setPrice) before the victim's force-included rescue tx.
 */
contract MockOracle {
    uint256 public price; // USD per WETH, 18 decimals

    event PriceUpdated(uint256 oldPrice, uint256 newPrice);

    constructor(uint256 initialPrice) {
        price = initialPrice;
    }

    /// @notice Anyone can update the price (simulates on-chain oracle update tx
    ///         that the adversarial sequencer inserts before the victim's tx).
    function setPrice(uint256 newPrice) external {
        emit PriceUpdated(price, newPrice);
        price = newPrice;
    }
}
