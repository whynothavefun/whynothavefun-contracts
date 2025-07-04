// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import "./interfaces/IRangedBondingCurveFactory.sol";
import "./interfaces/IDutchAuction.sol";

import "solady/utils/ReentrancyGuard.sol";
import "solady/utils/SafeTransferLib.sol";

import "./Base.sol";

/**
 * @title DutchAuction
 * @dev Implements a Dutch auction with linear price decrease
 */
contract DutchAuction is IDutchAuction, Base, ReentrancyGuard {
    using SafeTransferLib for address;

    // Native token address
    address public immutable nativeToken;

    // Treasury address
    address public immutable treasury;

    // Auction counter
    uint256 public auctionCounter;

    // Mapping to track auctions by ID
    mapping(uint256 => Auction) public auctions;

    // Factory address
    address public immutable factory;

    constructor(address owner, address nativeTokenAddress, address treasuryAddress, address factoryAddress) {
        _initializeOwner(owner);
        require(nativeTokenAddress != address(0), InvalidNativeTokenAddress());
        require(treasuryAddress != address(0), InvalidTreasuryAddress());
        require(factoryAddress != address(0), InvalidFactoryAddress());
        nativeToken = nativeTokenAddress;
        treasury = treasuryAddress;
        factory = factoryAddress;
    }

    /**
     * @dev Starts a Dutch auction. Only the owner can start an auction.
     * @param startPrice The starting price of the auction
     * @param endPrice The ending price of the auction
     * @param duration The duration of the auction in seconds
     * @return auctionId The ID of the newly created auction
     */
    function startAuction(uint256 startPrice, uint256 endPrice, uint256 duration)
        external
        override
        onlyOwner
        returns (uint256 auctionId)
    {
        require(auctionCounter == 0 || !auctions[auctionCounter - 1].isActive, AuctionAlreadyActive());
        require(startPrice > endPrice, StartPriceMustBeGreaterThanEndPrice());
        require(duration > 0, DurationMustBeGreaterThanZero());

        auctionCounter++;
        auctionId = auctionCounter;
        auctions[auctionId - 1] = Auction({
            startPrice: startPrice,
            endPrice: endPrice,
            startTime: block.timestamp,
            duration: duration,
            isActive: true,
            winner: address(0)
        });

        emit AuctionStarted(auctionId, startPrice, endPrice, block.timestamp, duration);
    }

    /**
     * @dev Calculates the current price of a Dutch auction
     * @param auctionId The ID of the auction
     * @return The current price
     */
    function getCurrentPrice(uint256 auctionId) public view override returns (uint256) {
        require(auctionId >= 1, AuctionNumberTooLow());
        Auction memory auction = auctions[auctionId - 1];
        require(auction.isActive, AuctionNotActive());

        uint256 elapsed = block.timestamp - auction.startTime;
        if (elapsed >= auction.duration) {
            return auction.endPrice;
        }

        return auction.startPrice - ((auction.startPrice - auction.endPrice) * elapsed) / auction.duration;
    }

    /**
     * @dev Allows a user to participate in a Dutch auction, transferring the current price to the treasury
     * @param auctionId The ID of the auction, starting from 1
     */
    function participate(uint256 auctionId) external override nonReentrant {
        require(auctionId >= 1, AuctionNumberTooLow());
        Auction storage auction = auctions[auctionId - 1];

        // Checks
        require(auction.winner == address(0), AuctionAlreadyHasWinner());
        require(auction.isActive, AuctionNotActive());

        uint256 currentPrice = getCurrentPrice(auctionId);

        // Effects
        auction.isActive = false;
        auction.winner = msg.sender;

        // Interactions
        SafeTransferLib.safeTransferFrom(nativeToken, msg.sender, treasury, currentPrice);
        IRangedBondingCurveFactory(factory).grantCurveLauncherRole(msg.sender, auctionId);

        emit AuctionWon(auctionId, msg.sender, currentPrice);
    }

    /**
     * @dev Checks if an auction is active
     * @param auctionId The ID of the auction
     * @return bool True if the auction is active
     */
    function isAuctionActive(uint256 auctionId) external view override returns (bool) {
        require(auctionId >= 1, AuctionNumberTooLow());
        return auctions[auctionId - 1].isActive;
    }

    /**
     * @dev Gets the winner of an auction
     * @param auctionId The ID of the auction
     * @return address The winner's address
     */
    function getWinner(uint256 auctionId) external view override returns (address) {
        require(auctionId >= 1, AuctionNumberTooLow());
        return auctions[auctionId - 1].winner;
    }
}
