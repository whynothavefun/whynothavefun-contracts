// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

/**
 * @title IBondedToken
 * @dev Interface for bonded tokens with transfer hooks
 */
interface IBondedToken {
    // Events
    /**
     * @dev Emitted when tokens are minted
     * @param to Address receiving the tokens
     * @param amount Amount of tokens minted
     */
    event Minted(address indexed to, uint256 indexed amount);

    /**
     * @dev Emitted when tokens are burned
     * @param from Address burning the tokens
     * @param amount Amount of tokens burned
     */
    event Burned(address indexed from, uint256 indexed amount);

    /**
     * @dev Emitted when tokens are transferred
     * @param from Address sending the tokens
     * @param to Address receiving the tokens
     * @param amount Amount of tokens transferred
     */
    event BondedTokenTransferred(address indexed token, address indexed from, address indexed to, uint256 amount);

    // Custom Errors
    error OnlyCurveCanBurn();

    /**
     * @dev Burns tokens
     * @param from Address burning the tokens
     * @param amount Amount of tokens to burn
     */
    function burn(address from, uint256 amount) external;
}
