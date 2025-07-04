// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import "./interfaces/IQuoter.sol";

import "./libraries/RangeMath.sol";
import "./libraries/CurveCalculations.sol";

import "solady/auth/Ownable.sol";

/**
 * @title Quoter
 * @dev Periphery contract that holds the implementation of quote functions
 * This separation contract size limitations
 */
contract Quoter is IQuoter, Ownable {
    // Fee in basis points (1 = 0.01%)
    uint256 public feeBasisPoints = 100; // Default 1%
    uint256 public constant BASIS_POINTS = 10000;

    error InvalidFeeBasisPoints();

    event FeeBasisPointsUpdated(uint256 oldFeeBasisPoints, uint256 newFeeBasisPoints);

    constructor(address owner) {
        _initializeOwner(owner);
    }

    /**
     * @dev Updates the fee basis points
     * @param newFeeBasisPoints New fee in basis points (1 = 0.01%)
     */
    function updateFeeBasisPoints(uint256 newFeeBasisPoints) external onlyOwner {
        require(newFeeBasisPoints <= BASIS_POINTS, InvalidFeeBasisPoints());
        uint256 oldFeeBasisPoints = feeBasisPoints;
        feeBasisPoints = newFeeBasisPoints;
        emit FeeBasisPointsUpdated(oldFeeBasisPoints, newFeeBasisPoints);
    }

    /**
     * @dev Calculates the native token amount needed to buy a specific amount of bonded tokens
     * @param ranges Array of ranges defining the bonding curve formulas
     * @param remainingTotalSupply Remaining supply of bonded tokens
     * @param bondedTokenAmount Amount of bonded tokens to buy
     * @param maxBondedTokenSupply Maximum supply of the bonded token
     * @return nativeAmount The amount of native tokens needed (excluding fee)
     * @return fee The fee amount
     * @return nativeAmountWithFee The total amount including fee
     */
    function quoteBuyExactOut(
        RangeMath.Range[] memory ranges,
        uint256 remainingTotalSupply,
        uint256 bondedTokenAmount,
        uint256 maxBondedTokenSupply
    ) external view returns (uint256 nativeAmount, uint256 fee, uint256 nativeAmountWithFee) {
        require(
            bondedTokenAmount > 0 && bondedTokenAmount <= maxBondedTokenSupply, InvalidTokenAmount(bondedTokenAmount)
        );

        (nativeAmount,,) =
            CurveCalculations.quoteBuyExactOut(ranges, remainingTotalSupply, bondedTokenAmount, maxBondedTokenSupply);

        require(nativeAmount > 0, BuyAmountOutOfBounds());

        fee = (nativeAmount * feeBasisPoints) / BASIS_POINTS;
        nativeAmountWithFee = nativeAmount + fee;
    }

    function quoteBuyExactIn(
        RangeMath.Range[] memory ranges,
        uint256 remainingTotalSupply,
        uint256 remainingNativeSupply,
        uint256 nativeAmount,
        uint256 maxBondedTokenSupply
    ) external view returns (uint256 buyAmount, uint256 fee, uint256 nativeAmountWithoutFee) {
        require(nativeAmount > 0, InvalidTokenAmount(nativeAmount));

        // Calculate fee based on the input amount
        fee = (nativeAmount * feeBasisPoints) / BASIS_POINTS;
        nativeAmountWithoutFee = nativeAmount - fee;

        require(nativeAmountWithoutFee <= remainingNativeSupply, InvalidTokenAmount(nativeAmountWithoutFee));

        // Calculate initial buy amount based on the amount without fee
        buyAmount = CurveCalculations.quoteBuyExactIn(
            ranges, remainingTotalSupply, nativeAmountWithoutFee, maxBondedTokenSupply
        );
    }

    /**
     * @dev Calculates the native token amount received when selling a specific amount of bonded tokens
     * @param ranges Array of ranges defining the bonding curve formulas
     * @param remainingTotalSupply Remaining supply of bonded tokens
     * @param maxBondedTokenSupply Maximum supply of the bonded token
     * @param bondedTokenAmount Amount of bonded tokens to sell
     * @return nativeAmount The amount of native tokens received (excluding fee)
     * @return fee The fee amount
     * @return nativeAmountWithoutFee The total amount after fee subtraction
     */
    function quoteSellExactIn(
        RangeMath.Range[] memory ranges,
        uint256 remainingTotalSupply,
        uint256 maxBondedTokenSupply,
        uint256 bondedTokenAmount
    ) external view returns (uint256 nativeAmount, uint256 fee, uint256 nativeAmountWithoutFee) {
        require(
            bondedTokenAmount > 0 && bondedTokenAmount <= maxBondedTokenSupply, InvalidTokenAmount(bondedTokenAmount)
        );

        (nativeAmount,,) =
            CurveCalculations.quoteSellExactIn(ranges, remainingTotalSupply, maxBondedTokenSupply, bondedTokenAmount);

        require(nativeAmount > 0, ReceivingAmountTooLow());

        fee = (nativeAmount * feeBasisPoints) / BASIS_POINTS;
        nativeAmountWithoutFee = nativeAmount - fee;
    }
}
