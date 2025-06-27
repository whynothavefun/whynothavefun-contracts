// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import "./RangeMath.sol";
/**
 * @title CurveCalculations
 * @dev Library for performing curve calculations
 */

library CurveCalculations {
    /**
     * @dev Emitted when the native amounts are invalid
     * @param startNativeAmount Start native amount
     * @param endNativeAmount End native amount
     */
    error InvalidNativeAmounts(uint256 startNativeAmount, uint256 endNativeAmount);

    /**
     * @dev Emitted when the buy amount is invalid
     * @param buyAmount Buy amount
     * @param remainingTotalSupply Remaining total supply
     */
    error InvalidBuyAmount(uint256 buyAmount, uint256 remainingTotalSupply);

    /**
     * @dev Emitted when the target total supply is invalid
     * @param targetRemainingSupply Target remaining supply
     * @param maxSupply Maximum supply
     */
    error InvalidTargetTotalSupply(uint256 targetRemainingSupply, uint256 maxSupply);

    /**
     * @dev Emitted when the target remaining supply is insufficient
     * @param remainingTotalSupply Remaining total supply
     * @param buyAmount Buy amount
     */
    error InsufficientTargetRemainingSupply(uint256 remainingTotalSupply, uint256 buyAmount);

    uint256 constant MINIMUM_REMAINING_TOTAL_SUPPLY = 1 ether;

    /**
     * @dev Calculates the native token amount needed to buy a specific amount of bonded tokens
     * @param ranges The ranges parameters
     * @param remainingTotalSupply The remaining supply of the token
     * @param buyAmount The amount of bonded tokens to buy
     * @return nativeAmount The amount of native tokens needed
     * @return startNativeAmount The starting native amount
     * @return endNativeAmount The ending native amount
     */
    function quoteBuyExactOut(
        RangeMath.Range[] memory ranges,
        uint256 remainingTotalSupply,
        uint256 buyAmount,
        uint256 maxSupply
    ) internal pure returns (uint256 nativeAmount, uint256 startNativeAmount, uint256 endNativeAmount) {
        require(buyAmount <= remainingTotalSupply, InvalidBuyAmount(buyAmount, remainingTotalSupply));

        uint256 targetRemainingSupply = remainingTotalSupply - buyAmount;
        require(
            targetRemainingSupply >= MINIMUM_REMAINING_TOTAL_SUPPLY,
            InsufficientTargetRemainingSupply(remainingTotalSupply, buyAmount)
        );

        bool startNativeAmountNotSet = true;
        nativeAmount = 0;
        startNativeAmount = 0;
        endNativeAmount = 0;

        for (uint8 i = 0; i < ranges.length; i++) {
            if (remainingTotalSupply >= ranges[i].tokenSupplyAtBoundary) {
                if (startNativeAmountNotSet) {
                    startNativeAmountNotSet = false;
                    startNativeAmount = RangeMath.calculateCurveXRatio(ranges[i], remainingTotalSupply, maxSupply, true);
                }

                if (targetRemainingSupply >= ranges[i].tokenSupplyAtBoundary) {
                    endNativeAmount = RangeMath.calculateCurveXRatio(ranges[i], targetRemainingSupply, maxSupply, true);
                    break;
                } else {
                    remainingTotalSupply = ranges[i].tokenSupplyAtBoundary;
                }
            }
        }
        require(endNativeAmount >= startNativeAmount, InvalidNativeAmounts(startNativeAmount, endNativeAmount));
        nativeAmount = endNativeAmount - startNativeAmount;
    }

    /**
     * @dev Calculates the amount of bonded tokens that can be bought with a specific amount of native tokens
     * @param ranges The ranges parameters
     * @param remainingTotalSupply The remaining supply of the token
     * @param payAmount The amount of native tokens to spend
     * @return buyAmount The amount of bonded tokens that can be bought
     */
    function quoteBuyExactIn(
        RangeMath.Range[] memory ranges,
        uint256 remainingTotalSupply,
        uint256 payAmount,
        uint256 maxSupply
    ) internal pure returns (uint256 buyAmount) {
        require(
            remainingTotalSupply >= MINIMUM_REMAINING_TOTAL_SUPPLY,
            InsufficientTargetRemainingSupply(remainingTotalSupply, payAmount)
        );
        uint256 startNativeAmount = 0;
        bool startNativeAmountNotSet = true;
        buyAmount = 0;

        for (uint8 i = 0; i < ranges.length; i++) {
            if (remainingTotalSupply > ranges[i].tokenSupplyAtBoundary) {
                if (startNativeAmountNotSet) {
                    startNativeAmountNotSet = false;
                    startNativeAmount =
                        RangeMath.calculateCurveXRatio(ranges[i], remainingTotalSupply, maxSupply, false);
                }

                require(
                    startNativeAmount <= ranges[i].nativeAmountAtBoundary,
                    InvalidNativeAmounts(startNativeAmount, ranges[i].nativeAmountAtBoundary)
                );

                uint256 remainingNativeTokenAmount = ranges[i].nativeAmountAtBoundary - startNativeAmount;

                if (payAmount < remainingNativeTokenAmount) {
                    buyAmount +=
                        RangeMath.findRoot(ranges, i, remainingTotalSupply, startNativeAmount, payAmount, maxSupply);
                    break;
                } else if (payAmount == remainingNativeTokenAmount) {
                    buyAmount += remainingTotalSupply - ranges[i].tokenSupplyAtBoundary;
                    break;
                } else {
                    uint256 rangeTokenAmount = remainingTotalSupply - ranges[i].tokenSupplyAtBoundary;
                    buyAmount += rangeTokenAmount;
                    remainingTotalSupply = ranges[i].tokenSupplyAtBoundary;
                    payAmount -= remainingNativeTokenAmount;
                    startNativeAmount = ranges[i].nativeAmountAtBoundary;
                }
            }
        }
    }

    /**
     * @dev Calculates the native token amount received when selling bonded tokens
     * @param ranges The ranges parameters
     * @param remainingTotalSupply The remaining supply of the token
     * @param sellAmount The amount of bonded tokens to sell
     * @return nativeAmount The amount of native tokens received
     * @return startNativeAmount The starting native amount
     * @return endNativeAmount The ending native amount
     */
    function quoteSellExactIn(
        RangeMath.Range[] memory ranges,
        uint256 remainingTotalSupply,
        uint256 maxSupply,
        uint256 sellAmount
    ) internal pure returns (uint256 nativeAmount, uint256 startNativeAmount, uint256 endNativeAmount) {
        uint256 targetRemainingSupply = remainingTotalSupply + sellAmount;
        require(targetRemainingSupply <= maxSupply, InvalidTargetTotalSupply(targetRemainingSupply, maxSupply));

        startNativeAmount = 0;
        endNativeAmount = 0;
        nativeAmount = 0;

        uint256 i = ranges.length - 1;
        do {
            uint256 tokenSupplyAtStartBoundary;
            if (i == 0) {
                tokenSupplyAtStartBoundary = maxSupply;
            } else {
                tokenSupplyAtStartBoundary = ranges[i - 1].tokenSupplyAtBoundary;
            }

            if (remainingTotalSupply < tokenSupplyAtStartBoundary) {
                if (endNativeAmount == 0) {
                    endNativeAmount = RangeMath.calculateCurveXRatio(ranges[i], remainingTotalSupply, maxSupply, false);
                }

                if (targetRemainingSupply <= tokenSupplyAtStartBoundary) {
                    startNativeAmount =
                        RangeMath.calculateCurveXRatio(ranges[i], targetRemainingSupply, maxSupply, true);
                    break;
                } else {
                    remainingTotalSupply = tokenSupplyAtStartBoundary;
                }
            }

            i -= 1;
        } while (i >= 0);

        if (endNativeAmount > startNativeAmount) {
            // require(endNativeAmount - startNativeAmount > 0, NonPositiveDifference(endNativeAmount, startNativeAmount));
            nativeAmount = endNativeAmount - startNativeAmount;
        }
    }
}
