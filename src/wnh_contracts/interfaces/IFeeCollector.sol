// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

/**
 * @title IFeeCollector
 * @dev Interface for the FeeCollector contract
 */
interface IFeeCollector {
    // Custom Errors
    error InvalidFundAddress();
    error InvalidFundRatio();
    error TransferFailed();
    error NativeTokensNotAccepted();
    error IncorrectToken();
    error InsufficientBalance(uint256 required, uint256 available);
    error OnlyCurveCanCall();
    // Events

    event FundRatioUpdated(uint256 newFundRatio);
    event FeesDistributed(address sender, uint256 fundAmount, uint256 ownerAmount);
    event BuybackFundUpdated(address newBuybackFund);
    event TreasuryUpdated(address newTreasury);

    // Functions
    function buybackFund() external view returns (address);
    function treasury() external view returns (address);
    function nativeToken() external view returns (address);
    function fundRatio() external view returns (uint256);
    function updateFundRatio(uint256 _newFundRatio) external;
    function onERC20Received(address token, uint256 amount) external;
}
