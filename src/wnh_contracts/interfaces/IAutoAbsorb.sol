// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

/**
 * @title IAutoAbsorb
 * @dev Interface for the AutoAbsorb contract
 */
interface IAutoAbsorb {
    // Custom Errors
    error AutoAbsorbInvalidAddress();

    error AutoAbsorbInvalidAmount();

    event AutoAbsorbBoughtAndBurned(uint256 nativeAmount, uint256 bondedAmount);

    function initialize(address curveAddress, address nativeTokenAddress) external;

    /**
     * @dev External method to call the curve's buyExactInBurn
     * @return Amount of bonded tokens received and burned
     */
    function buyExactInBurn(uint256 amount) external returns (uint256);
}
