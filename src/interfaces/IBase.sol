// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

/**
 * @title IBase
 * @dev Interface for the Base contract that provides emergency withdrawal functionality
 */
interface IBase {
    // Custom Errors
    error BaseNotAllowed();
    error ZeroAddress();

    // Events
    event EmergencyWithdraw(address indexed recipient, uint256 amount);

    /**
     * @dev Allows the owner to withdraw all tokens of a specific type in case of emergency
     * @param token The address of the token to withdraw
     * @param recipient The address to send the tokens to
     */
    function emergencyWithdraw(address token, address recipient) external;
}
