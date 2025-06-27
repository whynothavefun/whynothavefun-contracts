// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import "./interfaces/IRangedBondingCurve.sol";
import "./interfaces/IBondedToken.sol";
import "./interfaces/IFeeCollector.sol";
import "./interfaces/IPoints.sol";
import "./interfaces/IQuoter.sol";

import "solady/utils/ReentrancyGuard.sol";
import "solady/utils/SafeTransferLib.sol";
import "solady/utils/Initializable.sol";

import "./Base.sol";

/**
 * @title RangedBondingCurve
 * @dev Implements a bonding curve with configurable formulas for different supply ranges
 */
contract RangedBondingCurve is IRangedBondingCurve, Base, Initializable, ReentrancyGuard {
    using SafeTransferLib for address;

    Config private config;
    State private state;
    RangeMath.Range[] public ranges;

    constructor(
        address owner,
        address nativeTokenAddress,
        address bondedTokenAddress,
        uint256 maxBondedTokenSupplyToSet,
        uint256 maxNativeTokenSupplyToSet,
        address feeCollectorAddress,
        address autoAbsorbAddress,
        address pointsAddress,
        address quoterAddress,
        address factoryAddress,
        RangeMath.Range[] memory rangesToSet
    ) {
        _initializeOwner(owner);
        config.bondedToken = bondedTokenAddress;

        unchecked {
            for (uint256 i = 0; i < rangesToSet.length;) {
                RangeMath.Range storage newRange = ranges.push();
                newRange.tokenSupplyAtBoundary = rangesToSet[i].tokenSupplyAtBoundary;
                newRange.nativeAmountAtBoundary = rangesToSet[i].nativeAmountAtBoundary;
                newRange.coefficient = rangesToSet[i].coefficient;
                newRange.power = rangesToSet[i].power;
                newRange.constantTerm = rangesToSet[i].constantTerm;

                i++;
            }
        }

        config.nativeToken = nativeTokenAddress;
        config.maxBondedTokenSupply = maxBondedTokenSupplyToSet;
        config.maxNativeTokenSupply = maxNativeTokenSupplyToSet;
        config.feeCollector = feeCollectorAddress;
        config.bondedToken = bondedTokenAddress;
        config.points = pointsAddress;
        config.autoAbsorb = autoAbsorbAddress;
        config.quoter = quoterAddress;
        config.factory = factoryAddress;

        emit RangedBondingCurveInitialized(
            nativeTokenAddress,
            bondedTokenAddress,
            maxBondedTokenSupplyToSet,
            maxNativeTokenSupplyToSet,
            feeCollectorAddress,
            autoAbsorbAddress,
            pointsAddress,
            rangesToSet
        );
    }

    function getConfig() external view override returns (Config memory) {
        return config;
    }

    function getState() external view override returns (State memory) {
        return state;
    }

    modifier onlyFactory() {
        require(msg.sender == config.factory, OnlyFactoryCanCallThisFunction(msg.sender));
        _;
    }

    /**
     * @dev Updates the fee collector address
     * @param feeCollectorAddress New fee collector address
     */
    function updateFeeCollector(address feeCollectorAddress) external override onlyFactory {
        require(feeCollectorAddress != address(0), InvalidFeeCollectorAddress());
        config.feeCollector = feeCollectorAddress;
        emit FeeCollectorUpdated(feeCollectorAddress);
    }

    /**
     * @dev Quotes the native amount for a given amount of bonded tokens
     * @param bondedTokenAmount The amount of bonded tokens to sell
     * @return nativeAmountWithoutFee The native amount without fee
     */
    function quoteSellExactIn(uint256 bondedTokenAmount)
        external
        view
        override
        returns (uint256 nativeAmountWithoutFee)
    {
        (,, nativeAmountWithoutFee) = IQuoter(config.quoter).quoteSellExactIn(
            ranges,
            config.maxBondedTokenSupply - state.currentTotalSupply,
            config.maxBondedTokenSupply,
            bondedTokenAmount
        );
    }

    /**
     * @dev Quotes the bonded token amount for a given amount of native tokens
     * @param nativeTokenAmount The amount of native tokens to spend
     * @return bondedTokenAmount The amount of bonded tokens to receive
     */
    function quoteBuyExactIn(uint256 nativeTokenAmount) external view override returns (uint256 bondedTokenAmount) {
        (bondedTokenAmount,,) = IQuoter(config.quoter).quoteBuyExactIn(
            ranges,
            config.maxBondedTokenSupply - state.currentTotalSupply,
            config.maxNativeTokenSupply - state.currentNativeSupply,
            nativeTokenAmount,
            config.maxBondedTokenSupply
        );
    }

    /**
     * @dev Allows users to buy bonded tokens using native tokens
     * @param nativeTokenAmount Amount of native tokens to spend
     * @param minReceiveAmount Minimum amount of bonded tokens to receive
     */
    function buyExactIn(uint256 nativeTokenAmount, uint256 minReceiveAmount)
        external
        override
        nonReentrant
        returns (uint256 buyAmount, uint256 fee)
    {
        //only the factory can skip the points check. This is necessary for initial buy on deployment
        bool skipPointsCheck = msg.sender == config.factory ? true : false;
        (buyAmount, fee) = _buyExactIn(nativeTokenAmount, minReceiveAmount, skipPointsCheck);
        emit BuyExactIn(
            msg.sender,
            nativeTokenAmount,
            buyAmount,
            fee,
            state.currentTotalSupply,
            state.currentNativeSupply,
            skipPointsCheck,
            false
        );
    }

    function _buyExactIn(uint256 nativeTokenAmount, uint256 minReceiveAmount, bool skipPointsCheck)
        internal
        returns (uint256 buyAmount, uint256 fee)
    {
        uint256 nativeAmountWithoutFee;
        (buyAmount, fee, nativeAmountWithoutFee) = IQuoter(config.quoter).quoteBuyExactIn(
            ranges,
            config.maxBondedTokenSupply - state.currentTotalSupply,
            config.maxNativeTokenSupply - state.currentNativeSupply,
            nativeTokenAmount,
            config.maxBondedTokenSupply
        );

        if (config.points != address(0) && !skipPointsCheck) {
            uint256 pointsBalance = config.points.balanceOf(msg.sender);
            require(pointsBalance >= buyAmount, InsufficientManaTokenBalance(buyAmount, pointsBalance));
        }

        require(buyAmount >= minReceiveAmount, BuyAmountLessThanMinReceive(buyAmount, minReceiveAmount));

        state.currentTotalSupply += buyAmount;
        state.currentNativeSupply += nativeAmountWithoutFee;

        config.nativeToken.safeTransferFrom(msg.sender, address(this), nativeTokenAmount);
        config.bondedToken.safeTransfer(msg.sender, buyAmount);

        if (config.points != address(0) && !skipPointsCheck) {
            IPoints(config.points).burn(msg.sender, buyAmount);
        }

        if (fee > 0) {
            config.nativeToken.safeTransfer(config.feeCollector, fee);
            IFeeCollector(config.feeCollector).onERC20Received(config.nativeToken, fee);
        }
    }

    /**
     * @dev Allows users to buy bonded tokens using native tokens and burn the bonded tokens immediately
     * @param nativeTokenAmount Amount of native tokens to spend
     * @param minReceiveAmount Minimum amount of bonded tokens to receive
     * @return Amount of bonded tokens received
     */
    function buyExactInBurn(uint256 nativeTokenAmount, uint256 minReceiveAmount)
        external
        override
        nonReentrant
        returns (uint256)
    {
        bool skipPointsCheck = msg.sender == config.autoAbsorb
            || msg.sender == IFeeCollector(config.feeCollector).buybackFund() ? true : false;
        (uint256 bondedTokenAmount, uint256 fee) = _buyExactIn(nativeTokenAmount, minReceiveAmount, skipPointsCheck);
        IBondedToken(config.bondedToken).burn(msg.sender, bondedTokenAmount);
        emit BuyExactIn(
            msg.sender,
            nativeTokenAmount,
            bondedTokenAmount,
            fee,
            state.currentTotalSupply,
            state.currentNativeSupply,
            skipPointsCheck,
            true
        );
        return bondedTokenAmount;
    }

    /**
     * @dev Allows users to sell bonded tokens to receive native tokens
     * @param tokenAmount Amount of bonded tokens to sell
     * @param minReceiveAmount Minimum amount of native tokens to receive
     */
    function sellExactIn(uint256 tokenAmount, uint256 minReceiveAmount)
        external
        override
        nonReentrant
        returns (uint256 nativeAmountWithoutFee, uint256 fee)
    {
        require(tokenAmount > 0 && tokenAmount <= state.currentTotalSupply, InvalidTokenAmount(tokenAmount));

        uint256 nativeAmount;
        (nativeAmount, fee, nativeAmountWithoutFee) = IQuoter(config.quoter).quoteSellExactIn(
            ranges, config.maxBondedTokenSupply - state.currentTotalSupply, config.maxBondedTokenSupply, tokenAmount
        );

        require(
            nativeAmountWithoutFee >= minReceiveAmount,
            BuyAmountLessThanMinReceive(nativeAmountWithoutFee, minReceiveAmount)
        );

        state.currentTotalSupply -= tokenAmount;
        state.currentNativeSupply -= nativeAmount;

        config.bondedToken.safeTransferFrom(msg.sender, address(this), tokenAmount);
        config.nativeToken.safeTransfer(msg.sender, nativeAmountWithoutFee);

        if (fee > 0) {
            config.nativeToken.safeTransfer(config.feeCollector, fee);
            IFeeCollector(config.feeCollector).onERC20Received(config.nativeToken, fee);
        }

        emit Sell(
            msg.sender, tokenAmount, nativeAmountWithoutFee, fee, state.currentTotalSupply, state.currentNativeSupply
        );
    }

    /**
     * @dev Withdraw residual native tokens as a result of burning bonded tokens
     * @dev This function is called by the bonded token when it is burned. It can only be called by the HigherToken contract
     * @param bondedTokenAmount Amount of bonded tokens burned
     */
    function withdrawResidualNativeTokens(uint256 bondedTokenAmount) external {
        require(msg.sender == config.bondedToken, OnlyBondedTokenCanCallThisFunction(msg.sender));
        require(
            bondedTokenAmount <= state.currentTotalSupply,
            InsufficientBondedTokenBalance(bondedTokenAmount, state.currentTotalSupply)
        );

        state.totalBurned += bondedTokenAmount;
        uint256 remainingSupplyWhenEveryoneSold = config.maxBondedTokenSupply - state.totalBurned;

        (uint256 nativeAmount,,) = IQuoter(config.quoter).quoteSellExactIn(
            ranges, remainingSupplyWhenEveryoneSold, config.maxBondedTokenSupply, bondedTokenAmount
        );

        // transfer out the min of the native amount or the current native supply
        uint256 transferAmount = nativeAmount > state.currentNativeSupply ? state.currentNativeSupply : nativeAmount;

        state.currentNativeSupply -= transferAmount;

        config.nativeToken.safeTransfer(config.autoAbsorb, transferAmount);
        emit ResidualTokensWithdrawn(transferAmount, state.totalBurned);
    }
}
