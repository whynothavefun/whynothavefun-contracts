// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import "../libraries/RangeMath.sol";

/**
 * @title IQuoter
 * @dev Interface for the Quoter contract
 */
interface IQuoter {
    // Custom Errors
    error InvalidTokenAmount(uint256 amount);
    error BuyAmountOutOfBounds();
    error ReceivingAmountTooLow();
    error ActualNativeAmountTooHigh();

    // Functions
    /**
     * @dev Calculates the native token amount needed to buy a specific amount of bonded tokens
     * @param ranges Array of ranges defining the bonding curve formulas
     * @param remainingTotalSupply Remaining supply of bonded tokens
     * @param bondedTokenAmount Amount of bonded tokens to buy
     * @param maxBondedTokenSupply Maximum supply of the bonded token
     * @return nativeAmount The amount of native tokens needed (excluding fee)
     * @return fee The fee amount
     * @return totalAmount The total amount including fee
     */
    function quoteBuyExactOut(
        RangeMath.Range[] memory ranges,
        uint256 remainingTotalSupply,
        uint256 bondedTokenAmount,
        uint256 maxBondedTokenSupply
    ) external view returns (uint256 nativeAmount, uint256 fee, uint256 totalAmount);

    /**
     * @dev Calculates the native token amount received when selling a specific amount of bonded tokens
     * @param ranges Array of ranges defining the bonding curve formulas
     * @param remainingTotalSupply Remaining supply of bonded tokens
     * @param maxBondedTokenSupply Maximum supply of the bonded token
     * @param bondedTokenAmount Amount of bonded tokens to sell
     * @return nativeAmount The amount of native tokens received (excluding fee)
     * @return fee The fee amount
     * @return totalAmount The total amount after fee deduction
     */
    function quoteSellExactIn(
        RangeMath.Range[] memory ranges,
        uint256 remainingTotalSupply,
        uint256 maxBondedTokenSupply,
        uint256 bondedTokenAmount
    ) external view returns (uint256 nativeAmount, uint256 fee, uint256 totalAmount);

    /**
     * @dev Calculates the amount of bonded tokens that can be bought with a given amount of native tokens
     * @param ranges Array of ranges defining the bonding curve formulas
     * @param remainingTotalSupply Remaining supply of bonded tokens
     * @param remainingNativeSupply Remaining supply of native tokens
     * @param nativeAmount Amount of native tokens to spend
     * @param maxBondedTokenSupply Maximum supply of the bonded token
     * @return buyAmount The amount of bonded tokens that can be bought
     * @return fee The fee amount
     * @return nativeAmountWithoutFee The amount of native tokens without fee
     */
    function quoteBuyExactIn(
        RangeMath.Range[] memory ranges,
        uint256 remainingTotalSupply,
        uint256 remainingNativeSupply,
        uint256 nativeAmount,
        uint256 maxBondedTokenSupply
    ) external view returns (uint256 buyAmount, uint256 fee, uint256 nativeAmountWithoutFee);
}
