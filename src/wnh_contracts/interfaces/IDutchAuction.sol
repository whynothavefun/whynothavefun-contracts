// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

/**
 * @title IDutchAuction
 * @dev Interface for the DutchAuction contract
 */
interface IDutchAuction {
    // Structs
    struct Auction {
        uint256 startPrice;
        uint256 endPrice;
        uint256 startTime;
        uint256 duration;
        bool isActive;
        address winner;
    }

    // Custom errors
    error AuctionNotActive();
    error AuctionAlreadyHasWinner();
    error InvalidNativeTokenAddress();
    error InvalidTreasuryAddress();
    error StartPriceMustBeGreaterThanEndPrice();
    error DurationMustBeGreaterThanZero();
    error AuctionAlreadyActive();
    error AuctionNumberTooLow();
    error InvalidFactoryAddress();

    // Events
    event AuctionStarted(
        uint256 indexed auctionId, uint256 startPrice, uint256 endPrice, uint256 startTime, uint256 duration
    );
    event AuctionWon(uint256 indexed auctionId, address indexed winner, uint256 finalPrice);

    // Functions

    function nativeToken() external view returns (address);

    function treasury() external view returns (address);

    function auctionCounter() external view returns (uint256);

    function auctions(uint256 auctionId)
        external
        view
        returns (
            uint256 startPrice,
            uint256 endPrice,
            uint256 startTime,
            uint256 duration,
            bool isActive,
            address winner
        );

    function factory() external view returns (address);

    function startAuction(uint256 startPrice, uint256 endPrice, uint256 duration)
        external
        returns (uint256 auctionId);

    function getCurrentPrice(uint256 auctionId) external view returns (uint256);

    function participate(uint256 auctionId) external;

    function isAuctionActive(uint256 auctionId) external view returns (bool);

    function getWinner(uint256 auctionId) external view returns (address);
}
