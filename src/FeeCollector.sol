// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import "./interfaces/IFeeCollector.sol";

import "solady/tokens/ERC20.sol";
import "solady/utils/SafeTransferLib.sol";
import "solady/utils/Initializable.sol";

import "./Base.sol";

contract FeeCollector is IFeeCollector, Base, Initializable {
    using SafeTransferLib for address;

    // Custom errors
    address public buybackFund;
    address public treasury;
    address public immutable nativeToken;
    uint256 public fundRatio; // in basis points (1 = 0.01%)
    uint256 public constant BASIS_POINTS = 10000;

    constructor(address buybackFundToSet, address treasuryToSet, address nativeTokenToSet, address owner) {
        if (buybackFundToSet == address(0)) revert ZeroAddress();
        if (treasuryToSet == address(0)) revert ZeroAddress();
        if (nativeTokenToSet == address(0)) revert ZeroAddress();
        if (owner == address(0)) revert ZeroAddress();
        buybackFund = buybackFundToSet;
        treasury = treasuryToSet;
        nativeToken = nativeTokenToSet;
        fundRatio = 5000; // 50% in basis points
        _initializeOwner(owner);
    }

    /**
     * @dev Sets the buyback fund address, only callable by the owner
     * @param newBuybackFund The new buyback fund address
     */
    function setBuybackFund(address newBuybackFund) external onlyOwner {
        if (newBuybackFund == address(0)) revert ZeroAddress();
        buybackFund = newBuybackFund;
        emit BuybackFundUpdated(newBuybackFund);
    }

    /**
     * @dev Sets the treasury address, only callable by the owner
     * @param newTreasury The new treasury address
     */
    function setTreasury(address newTreasury) external onlyOwner {
        if (newTreasury == address(0)) revert ZeroAddress();
        treasury = newTreasury;
        emit TreasuryUpdated(newTreasury);
    }

    function updateFundRatio(uint256 newFundRatio) external override onlyOwner {
        if (newFundRatio > BASIS_POINTS) revert InvalidFundRatio();
        fundRatio = newFundRatio;
        emit FundRatioUpdated(newFundRatio);
    }

    /**
     * @dev Handles the transfer of native tokens to the buyback fund and treasury. This is a custom endpoint called by the curve contract.
     * @param token The token that is being transferred
     * @param amount The amount of tokens that is being transferred
     */
    function onERC20Received(address token, uint256 amount) external override {
        require(token == nativeToken, IncorrectToken());

        // Verify we have the tokens before splitting
        uint256 balance = ERC20(nativeToken).balanceOf(address(this));
        require(balance >= amount, InsufficientBalance(amount, balance));

        uint256 buybackAmount = (amount * fundRatio) / BASIS_POINTS;
        uint256 treasuryAmount = amount - buybackAmount;

        if (buybackAmount > 0) {
            // Transfer part to buyback fund
            nativeToken.safeTransfer(buybackFund, buybackAmount);
        }

        if (treasuryAmount > 0) {
            // Transfer the remainder to treasury
            nativeToken.safeTransfer(treasury, treasuryAmount);
        }

        emit FeesDistributed(msg.sender, buybackAmount, treasuryAmount);
    }
}
