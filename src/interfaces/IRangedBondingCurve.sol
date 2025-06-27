// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import "../libraries/RangeMath.sol";

/**
 * @title IRangedBondingCurve
 * @dev Interface for the RangedBondingCurve contract
 */
interface IRangedBondingCurve {
    // Structs
    // Configuration - immutable after initialization
    struct Config {
        address bondedToken; // 20 bytes
        address nativeToken; // 20 bytes
        address feeCollector; // 20 bytes
        address autoAbsorb; // 20 bytes
        address points; // 20 bytes
        address quoter; // 20 bytes
        address factory; // 20 bytes
        uint256 maxBondedTokenSupply; // 32 bytes
        uint256 maxNativeTokenSupply; // 32 bytes
    }

    // State - changes during operation
    struct State {
        uint256 currentTotalSupply; // 32 bytes
        uint256 currentNativeSupply; // 32 bytes
        uint256 totalBurned; // 32 bytes
    }

    // Custom Errors
    error InsufficientManaTokenBalance(uint256 requiredAmount, uint256 balance);
    error InvalidUserAddress(address user);
    error InvalidTokenAmount(uint256 amount);
    error OnlyBondedTokenCanCallThisFunction(address caller);
    error BuyAmountLessThanMinReceive(uint256 actual, uint256 minimum);
    error InsufficientBondedTokenBalance(uint256 required, uint256 available);
    error OnlyFactoryCanCallThisFunction(address caller);
    error InvalidFeeCollectorAddress();

    // Events
    /**
     * @dev Emitted when the RangedBondingCurve is initialized
     * @param nativeToken Address of the native token
     * @param bondedToken Address of the bonded token
     * @param maxBondedTokenSupply Maximum supply of the bonded token
     * @param maxNativeTokenSupply Maximum supply of the native token
     * @param feeCollector Address of the fee collector
     * @param autoAbsorb Address of the up fund
     * @param points Address of the mana token
     * @param ranges Array of ranges defining the bonding curve formulas
     */
    event RangedBondingCurveInitialized(
        address nativeToken,
        address bondedToken,
        uint256 maxBondedTokenSupply,
        uint256 maxNativeTokenSupply,
        address feeCollector,
        address autoAbsorb,
        address points,
        RangeMath.Range[] ranges
    );

    /**
     * @dev Emitted when tokens are bought
     * @param buyer Address of the buyer
     * @param nativeAmount Amount of base tokens spent
     * @param buyAmount Amount of bonded tokens received
     * @param fee Amount of fee paid
     * @param currentTotalSupply Current total supply of bonded tokens
     * @param currentNativeSupply Current native token balance
     * @param skipPointsCheck Whether the points check is skipped
     * @param isBurned Whether the tokens are burned
     */
    event BuyExactIn(
        address buyer,
        uint256 nativeAmount,
        uint256 buyAmount,
        uint256 fee,
        uint256 currentTotalSupply,
        uint256 currentNativeSupply,
        bool skipPointsCheck,
        bool isBurned
    );

    /**
     * @dev Emitted when tokens are sold
     * @param seller Address of the seller
     * @param tokenAmount Amount of bonded tokens sold
     * @param nativeAmount Amount of base tokens received
     * @param fee Amount of fee paid
     * @param currentTotalSupply Current total supply of bonded tokens
     * @param currentNativeSupply Current native token balance
     */
    event Sell(
        address seller,
        uint256 tokenAmount,
        uint256 nativeAmount,
        uint256 fee,
        uint256 currentTotalSupply,
        uint256 currentNativeSupply
    );

    /**
     * @dev Emitted when the maximum supply is updated
     * @param newMaxBondedTokenSupply New maximum supply
     */
    event MaxBondedTokenSupplyUpdated(uint256 newMaxBondedTokenSupply);

    /**
     * @dev Emitted when the native token balance is insufficient
     * @param nativeAmount Amount of base tokens needed
     * @param currentNativeSupply Current native token balance
     */
    error InsufficientNativeTokenBalance(uint256 nativeAmount, uint256 currentNativeSupply);

    /**
     * @dev Emitted when the fee collector is updated
     * @param newFeeCollector New fee collector address
     */
    event FeeCollectorUpdated(address newFeeCollector);

    /**
     * @dev Emitted when residual tokens are bought
     * @param amount Amount of residual tokens withdrawn
     * @param totalBurned Total amount of bonded tokens burned
     */
    event ResidualTokensWithdrawn(uint256 amount, uint256 totalBurned);

    /**
     * @dev Updates the fee collector address
     * @param _feeCollector New fee collector address
     */
    function updateFeeCollector(address _feeCollector) external;

    /**
     * @dev Allows users to buy bonded tokens using base tokens
     * @param nativeTokenAmount Amount of native tokens to spend
     * @param minReceiveAmount Minimum amount of bonded tokens to receive
     * @return Amount of base tokens spent (including fee)
     */
    function buyExactIn(uint256 nativeTokenAmount, uint256 minReceiveAmount) external returns (uint256, uint256);

    /**
     * @dev Allows users to buy bonded tokens using native tokens and burn the bonded tokens immediately
     * @param nativeTokenAmount Amount of native tokens to spend
     * @param minReceiveAmount Minimum amount of bonded tokens to receive
     * @return Amount of bonded tokens received
     */
    function buyExactInBurn(uint256 nativeTokenAmount, uint256 minReceiveAmount) external returns (uint256);

    /**
     * @dev Returns the config of the bonding curve
     * @return Config of the bonding curve
     */
    function getConfig() external view returns (Config memory);

    /**
     * @dev Returns the state of the bonding curve
     * @return State of the bonding curve
     */
    function getState() external view returns (State memory);

    /**
     * @dev Allows users to sell bonded tokens to receive base tokens
     * @param tokenAmount Amount of bonded tokens to sell
     * @param minReceiveAmount Minimum amount of native tokens to receive
     * @return Amount of base tokens received (after fee deduction)
     */
    function sellExactIn(uint256 tokenAmount, uint256 minReceiveAmount) external returns (uint256, uint256);

    /**
     * @dev Calculates the amount of native tokens that would be received when selling a given amount of bonded tokens, including fee
     * @param _bondedTokenAmount Amount of bonded tokens to sell
     * @return nativeAmount Amount of native tokens that would be received
     */
    function quoteSellExactIn(uint256 _bondedTokenAmount) external view returns (uint256 nativeAmount);

    /**
     * @dev Calculates the amount of bonded tokens that would be received when buying a given amount of native tokens, including fee
     * @param _nativeTokenAmount Amount of native tokens to buy
     * @return bondedTokenAmount Amount of bonded tokens that would be received
     */
    function quoteBuyExactIn(uint256 _nativeTokenAmount) external view returns (uint256 bondedTokenAmount);

    /**
     * @dev Withdraws residual native tokens as a result of burning bonded tokens
     * @param _amount Amount of native tokens to withdraw
     */
    function withdrawResidualNativeTokens(uint256 _amount) external;
}
