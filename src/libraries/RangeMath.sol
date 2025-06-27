// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import "solady/utils/FixedPointMathLib.sol";

/**
 * @title RangeMath
 * @dev Library for handling range-specific calculations in bonding curves using fixed-point math
 *
 * This library provides functionality for:
 * 1. Managing ranges in bonding curves
 * 2. Calculating prices based on the formula y = k/x^n - c
 *
 * The bonding curve is divided into ranges, each with its own formula:
 * y = k/x^n - c
 * Where:
 * - y is the price (scaled by 1e19)
 * - x is the remaining percentage of tokens
 * - k is the coefficient (scaled by 1e19)
 * - n is the power
 * - c is the constant term (scaled by 1e19)
 */
library RangeMath {
    using FixedPointMathLib for uint256;

    // Maximum error allowed in token calculation
    // we are alright with up ot 9 decimals of precision, so we allow the other 9 as error
    uint256 private constant TOKEN_CALCULATION_MAX_ERROR = 1e9;

    /**
     * @dev Emitted when k/x^n is less than c
     * @param kOverXPower The value of k/x^n
     * @param constantTerm The value of c
     */
    error KOverXPowerLessThanConstantTerm(uint256 kOverXPower, uint256 constantTerm);

    /**
     * @dev Represents a range in the bonding curve
     * @param tokenSupplyAtBoundary The remaining token supply when reaching the curve boundary
     * @param nativeAmountAtBoundary The native amount when reaching the curve boundary
     * @param coefficient The k value in the curve (scaled by 1e19, which is the max token supply)
     * @param power The power of the x in the curve
     * @param constantTerm The c value in the curve (scaled by 1e19)
     */
    struct Range {
        uint256 tokenSupplyAtBoundary; // the remaining token supply when reaching the curve boundary
        uint256 nativeAmountAtBoundary; // the native amount when reaching the curve boundary
        uint256 coefficient; // the k value in the curve (scaled by 1e19, which is the max token supply)
        uint256 power; // the power of the x in the curve
        uint256 constantTerm; // the c value in the curve (scaled by 1e19)
    }

    function calculateCurveXRatio(Range memory range, uint256 targetSupply, uint256 maxSupply, bool roundUp)
        internal
        pure
        returns (uint256)
    {
        // require(targetSupply != maxSupply, TargetSupplyEqualToMaxSupply());
        uint256 xRatio = FixedPointMathLib.divWadUp(targetSupply, maxSupply);

        uint256 xPower =
            range.power > 1 ? uint256(FixedPointMathLib.powWad(int256(xRatio), int256(range.power * 1e18))) : xRatio;

        uint256 y = roundUp
            ? FixedPointMathLib.divWadUp(range.coefficient, xPower)
            : FixedPointMathLib.divWad(range.coefficient, xPower);

        require(y >= range.constantTerm, KOverXPowerLessThanConstantTerm(y, range.constantTerm));
        y = y - range.constantTerm;
        return y;
    }
    // y = k / x ^ n - c

    /**
     * @dev Finds the root of the curve equation for a given target native amount using binary search
     * @param ranges The ranges parameters
     * @param currentRangeIndex The index of the current range
     * @param remainingTokenSupply The remaining supply of the token
     * @param remainingTokenSupplyNativeAmount The native amount corresponding to the remaining token supply
     * @param payAmount The amount of native tokens to be paid
     * @return The amount of tokens that can be bought
     */
    function findRoot(
        Range[] memory ranges,
        uint256 currentRangeIndex,
        uint256 remainingTokenSupply,
        uint256 remainingTokenSupplyNativeAmount,
        uint256 payAmount,
        uint256 maxSupply
    ) internal pure returns (uint256) {
        // edge case: if payAmount is 0, return the zero. We don't want to allow for approximation error attacks
        if (payAmount == 0) {
            return 0;
        }

        uint256 targetNativeAmount = remainingTokenSupplyNativeAmount + payAmount;

        Range memory range = ranges[currentRangeIndex];

        uint256 low = range.tokenSupplyAtBoundary;
        uint256 high = remainingTokenSupply;

        while (high - low > TOKEN_CALCULATION_MAX_ERROR) {
            uint256 mid = (low + high) >> 1;
            // // round up to ensure that high is moved as little as possible
            uint256 y = calculateCurveXRatio(range, mid, maxSupply, true);
            if (targetNativeAmount > y) {
                high = mid;
            } else {
                low = mid;
            }
        }

        // we are using the high end of the search here on purpose, because we are subtracting and the result should be off by the rounding error in the negative direction
        return FixedPointMathLib.zeroFloorSub(remainingTokenSupply, high);
    }
}
