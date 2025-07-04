// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

/**
 * @title IPoints
 * @dev Interface for points tokens
 */
interface IPoints {
    /**
     * @dev Burns tokens
     * @param from Address burning the tokens
     * @param amount Amount of tokens to burn
     */
    function burn(address from, uint256 amount) external;

    function initialize(address curveToSet, address signerToSet) external;

    function setSigner(address signerToSet) external;

    function getClaimSigner(address user, uint256 threshold, bytes memory signature) external view returns (address);

    function getClaimDigest(address user, uint256 threshold) external view returns (bytes32);
}
