// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import "./interfaces/IRangedBondingCurve.sol";
import "./interfaces/IBondedToken.sol";

import "solady/tokens/ERC20.sol";
import "solady/utils/ReentrancyGuard.sol";
import "solady/utils/Initializable.sol";

import "./Base.sol";

contract BondedToken is IBondedToken, Base, ERC20, Initializable, ReentrancyGuard {
    string private _name;
    string private _symbol;

    address public curve;

    constructor(string memory nameToSet, string memory symbolToSet, address owner) {
        require(owner != address(0), ZeroAddress());
        _initializeOwner(owner);
        _name = nameToSet;
        _symbol = symbolToSet;
    }

    function initialize(address curveAddress, uint256 maxBondedTokenSupply) external initializer onlyOwner {
        require(curveAddress != address(0), ZeroAddress());
        curve = curveAddress;

        _mint(curveAddress, maxBondedTokenSupply);

        emit Minted(address(curve), maxBondedTokenSupply);
    }

    function name() public view override returns (string memory) {
        return _name;
    }

    function symbol() public view override returns (string memory) {
        return _symbol;
    }

    function _afterTokenTransfer(address from, address to, uint256 amount) internal override {
        emit BondedTokenTransferred(address(this), from, to, amount);
    }

    /**
     * @dev The burn method is callable only by the corresponding curve contract
     * @param from The address to burn the token from
     * @param amount The amount of token to burn
     */
    function burn(address from, uint256 amount) external nonReentrant {
        require(msg.sender == curve, OnlyCurveCanBurn());
        _burn(from, amount);

        IRangedBondingCurve(curve).withdrawResidualNativeTokens(amount);

        emit Burned(from, amount);
    }
}
