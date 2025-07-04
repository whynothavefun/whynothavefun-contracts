// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import "./interfaces/IBase.sol";

import "solady/auth/Ownable.sol";
import "solady/utils/SafeTransferLib.sol";

/**
 * @title Base
 * @dev Abstract contract that provides emergency withdrawal functionality and reverting receive/fallback functions.
 * Can be inherited by other contracts that need these features.
 */
abstract contract Base is IBase, Ownable {
    using SafeTransferLib for address;

    /**
     * @dev Allows the owner to withdraw all tokens of a specific type in case of emergency
     * @param token The address of the token to withdraw
     * @param recipient The address to send the tokens to
     */
    function emergencyWithdraw(address token, address recipient) external onlyOwner {
        require(token != address(0), ZeroAddress());
        require(recipient != address(0), ZeroAddress());

        uint256 balance = token.balanceOf(address(this));
        token.safeTransfer(recipient, balance);

        emit EmergencyWithdraw(recipient, balance);
    }

    /**
     * @dev Reverts any direct ETH transfers to the contract
     */
    receive() external payable {
        revert BaseNotAllowed();
    }

    /**
     * @dev Reverts any direct ETH transfers to the contract
     */
    fallback() external payable {
        revert BaseNotAllowed();
    }
}
