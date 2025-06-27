// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import "./IRangedBondingCurveFactory.sol";

/**
 * @title ITradingAccounts
 * @dev Interface for the TradingAccounts contract
 */
interface ITradingAccounts {
    // Custom Errors
    error InsufficientBalance(uint256 required, uint256 available);
    error BalanceNotAboveThreshold(uint256 required, uint256 available);
    error InsufficientContractTokenBalance(uint256 required, uint256 available);
    error InvalidTradingAccountCurveAddress(address curve);
    error ArrayLengthMismatch();
    error InvalidAmount();
    error WrongMaxSpendNativeAmount(uint256 maxSpendNativeAmount, uint256 userNativeBalanceBeforeTrade);
    error CurveNotDeployed(address curve);
    error CannotSetBalanceBelowCurrent(uint256 amount, uint256 current);

    // Events
    event NativeBalancesSet(address[] users, uint256[] amounts);
    event TokensBought(
        address indexed user,
        address indexed curve,
        address indexed bondedToken,
        uint256 bondedAmount,
        uint256 nativeCost
    );
    event TokensSold(
        address indexed user,
        address indexed curve,
        address indexed bondedToken,
        uint256 bondedAmount,
        uint256 nativeReceived
    );
    event BondedTokensWithdrawn(address indexed user, address indexed bondedToken, uint256 amount);
    event NativeTokensWithdrawn(address indexed recipient, uint256 amount);
    event NativeTokensDeposited(address indexed depositor, uint256 amount);

    // State Variables
    function factory() external view returns (IRangedBondingCurveFactory);
    function nativeToken() external view returns (address payable);
    function userNativeBalances(address) external view returns (uint256);
    function userBondedTokenBalances(address, address) external view returns (uint256);
    function subsidizedAmount(address) external view returns (uint256);

    // Functions
    function initialize(address factoryAddress, address owner, address payable nativeTokenAddress) external;
    function setNativeBalances(address[] calldata users, uint256[] calldata amounts) external;
    function buyExactIn(address curveAddress, uint256 nativeAmount, uint256 minReceiveAmount)
        external
        returns (uint256);
    function sellTokens(address curveAddress, uint256 bondedTokenAmount, uint256 minReceiveAmount) external;
    function withdrawNativeTokens(uint256 amount) external;
    function depositNativeTokens(uint256 amount) external;
    function getUserBalance(address token, address user) external view returns (uint256);
}
