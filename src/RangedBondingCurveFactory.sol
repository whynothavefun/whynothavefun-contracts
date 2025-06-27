// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import "./interfaces/IRangedBondingCurveFactory.sol";
import "./interfaces/IRangedBondingCurve.sol";

import "./libraries/RangeMath.sol";

import "solady/auth/OwnableRoles.sol";
import "solady/utils/SafeTransferLib.sol";
import "solady/utils/ReentrancyGuard.sol";
import "solady/utils/Initializable.sol";

import "./RangedBondingCurve.sol";
import "./BondedToken.sol";
import "./Base.sol";

/**
 * @title RangedBondingCurveFactory
 * @dev Factory contract for deploying RangedBondingCurve instances with predefined configurations using CREATE2
 */
contract RangedBondingCurveFactory is IRangedBondingCurveFactory, Base, OwnableRoles, Initializable, ReentrancyGuard {
    using SafeTransferLib for address;
    // Role constants

    uint256 public constant AUCTION_ROLE = 2;

    //@dev Array of all deployed curves
    address[] public deployedCurves;

    //@dev Mapping from bonded token to curve address
    mapping(address => address) private tokenToCurve;

    //@dev Mapping to track deployed curves for easy lookup
    mapping(address => bool) public isDeployedCurve;

    //@dev Mapping to track used tickers
    mapping(string => bool) public isTickerUsed;

    //@dev Array of all historical curve launchers
    address[] public curveLaunchers;

    CurveParams public curveParams;

    mapping(address => mapping(uint256 => bool)) public hasDeploymentPermissionForRound;

    constructor(address owner) {
        _initializeOwner(owner);
    }

    function initialize(address auction, CurveParams memory params) external onlyOwner initializer {
        _validateRanges(params.ranges);

        _grantRoles(auction, AUCTION_ROLE);

        // grant the owners permission to deploy the first token
        hasDeploymentPermissionForRound[owner()][0] = true;

        curveParams = params;
    }

    /**
     * @dev Sets the curve parameters, only callable by the owner
     * @param params The parameters for the curve deployment
     */
    function setCurveParams(CurveParams memory params) external onlyOwner {
        require(params.maxSupply > 0, MaxSupplyMustBeGreaterThanZero());
        require(params.maxNativeTokenSupply > 0, MaxNativeTokenSupplyMustBeGreaterThanZero());
        require(params.feeCollector != address(0), InvalidFeeCollectorAddress());
        require(params.ranges.length > 0, AtLeastOneRangeMustBeDefined());
        require(params.autoAbsorb != address(0), InvalidAutoAbsorbAddress());
        require(params.quoter != address(0), InvalidQuoterAddress());
        require(params.nativeToken != address(0), InvalidNativeTokenAddress());
        _validateRanges(params.ranges);
        curveParams = params;
    }

    /**
     * @dev Grants the curve launcher role to an account for a given round
     * @param account The account to grant the role to
     */
    function grantCurveLauncherRole(address account, uint256 round) external onlyRoles(AUCTION_ROLE) {
        hasDeploymentPermissionForRound[account][round] = true;
        emit CurveLauncherRoleGranted(account);
    }

    /**
     * @dev Revokes the curve launcher role from an account for a given round
     * @param account The account to revoke the role from
     * @param round The round to revoke the role for
     */
    function revokeCurveLauncherRole(address account, uint256 round) external onlyOwner {
        hasDeploymentPermissionForRound[account][round] = false;
        emit CurveLauncherRoleRevoked(account);
    }

    /**
     * @dev Deploys a curve without salt
     * @param params The parameters for the curve deployment
     * @return curve The address of the deployed curve
     * @return initialBuyAmount The amount of initial buy amount
     */
    function deployCurve(DeploymentParams memory params)
        external
        nonReentrant
        returns (address curve, uint256 initialBuyAmount)
    {
        return _deployCurveWithInitialBuy(params);
    }

    /**
     * @dev Deploys a curve with initial buy amount
     * @param params The parameters for the curve deployment
     * @return curve The address of the deployed curve
     * @return initialBuyAmount The amount of initial buy amount
     */
    function _deployCurveWithInitialBuy(DeploymentParams memory params)
        internal
        returns (address curve, uint256 initialBuyAmount)
    {
        curve = _deployCurve(params.salt, params.name, params.round, params.symbol, curveParams);
        if (params.initialBuyAmount > 0) {
            require(
                params.initialBuyAmount <= curveParams.maxInitialBuyAmount,
                InitialBuyAmountExceedsMaxInitialBuyAmount(params.initialBuyAmount, curveParams.maxInitialBuyAmount)
            );
            curveParams.nativeToken.safeTransferFrom(msg.sender, address(this), params.initialBuyAmount);
            curveParams.nativeToken.safeApprove(address(curve), params.initialBuyAmount);
            (initialBuyAmount,) = IRangedBondingCurve(curve).buyExactIn(params.initialBuyAmount, 0);
            IRangedBondingCurve(curve).getConfig().bondedToken.safeTransfer(msg.sender, initialBuyAmount);
        }
    }

    function _deployCurve(
        bytes32 salt,
        string memory name,
        uint256 round,
        string memory symbol,
        CurveParams memory params
    ) internal returns (address) {
        require(!isTickerUsed[symbol], TickerAlreadyUsed(symbol));
        require(hasDeploymentPermissionForRound[msg.sender][round], NoDeploymentPermission(msg.sender, round));

        address deployer = address(this);
        address bondedToken = _deployBondedToken(name, symbol, salt, deployer);
        address curve = address(
            new RangedBondingCurve{salt: salt}(
                owner(),
                params.nativeToken,
                bondedToken,
                params.maxSupply,
                params.maxNativeTokenSupply,
                params.feeCollector,
                params.autoAbsorb,
                params.points,
                params.quoter,
                address(this),
                params.ranges
            )
        );

        _initializeContracts(bondedToken, curve);
        _updateFactoryState(curve, bondedToken, symbol, round);

        emit CurveDeployed(
            curve,
            bondedToken,
            msg.sender,
            name,
            symbol,
            round,
            params.maxSupply,
            params.maxNativeTokenSupply,
            params.feeCollector,
            params.ranges
        );

        return curve;
    }

    function _validateRanges(RangeMath.Range[] memory _ranges) internal pure {
        for (uint256 i = 0; i < _ranges.length; i++) {
            require(_ranges[i].tokenSupplyAtBoundary > 0, TokenSupplyAtBoundaryIsZero(i));
            if (i < _ranges.length - 1) {
                require(
                    _ranges[i].tokenSupplyAtBoundary > _ranges[i + 1].tokenSupplyAtBoundary,
                    TokenSupplyAtBoundaryNotGreaterThanNext(
                        _ranges[i].tokenSupplyAtBoundary, _ranges[i + 1].tokenSupplyAtBoundary
                    )
                );
            }
            if (i < _ranges.length - 1) {
                require(
                    _ranges[i].nativeAmountAtBoundary < _ranges[i + 1].nativeAmountAtBoundary,
                    NativeAmountAtBoundaryNotLessThanNext(
                        _ranges[i].nativeAmountAtBoundary, _ranges[i + 1].nativeAmountAtBoundary
                    )
                );
            }
        }
    }

    function _deployBondedToken(string memory name, string memory symbol, bytes32 salt, address deployer)
        internal
        returns (address)
    {
        // we cannot use encode instead of encodePacked here as we need it for the correct init code
        bytes32 bondedTokenInitCodeHash =
            keccak256(abi.encodePacked(type(BondedToken).creationCode, abi.encode(name, symbol, deployer)));
        address precomputedTokenAddress = _computeCreate2Address(salt, bondedTokenInitCodeHash, deployer);
        require(
            tokenToCurve[precomputedTokenAddress] == address(0), CurveAlreadyExistsForToken(precomputedTokenAddress)
        );

        return address(new BondedToken{salt: salt}(name, symbol, deployer));
    }

    function _initializeContracts(address bondedToken, address curve) internal {
        BondedToken(payable(bondedToken)).initialize(payable(curve), curveParams.maxSupply);
        BondedToken(payable(bondedToken)).transferOwnership(owner());
    }

    function _updateFactoryState(address curve, address bondedToken, string memory symbol, uint256 round) internal {
        deployedCurves.push(curve);
        isDeployedCurve[curve] = true;
        tokenToCurve[bondedToken] = curve;
        curveLaunchers.push(msg.sender);
        isTickerUsed[symbol] = true;
        hasDeploymentPermissionForRound[msg.sender][round] = false;
    }

    /**
     * @dev Updates the fee collector for a given curve, only callable by the owner
     * @param curve The address of the curve to update
     * @param feeCollector The address of the new fee collector
     */
    function updateFeeCollector(address curve, address feeCollector) external onlyOwner {
        RangedBondingCurve(payable(curve)).updateFeeCollector(feeCollector);
    }

    /**
     * @dev Returns the address of the curve for a given token
     * @param token The address of the token
     * @return The address of the curve
     */
    function getTokenToCurve(address token) external view returns (address) {
        return tokenToCurve[token];
    }

    /**
     * @dev Returns the number of deployed curves
     * @return Number of deployed curves
     */
    function getDeployedCurvesCount() external view returns (uint256) {
        return deployedCurves.length;
    }

    /**
     * @dev Returns the address of a deployed curve at a given index
     * @param index The index of the curve
     * @return The address of the curve
     */
    function getDeployedCurveAtIndex(uint256 index) external view returns (address) {
        return deployedCurves[index];
    }

    /**
     * @dev Checks if a curve address was deployed by this factory.
     * @param curve The address of the curve contract.
     * @return bool True if the curve was deployed by this factory.
     */
    function isCurveDeployed(address curve) public view override returns (bool) {
        return isDeployedCurve[curve];
    }

    /**
     * @dev Returns the address where a contract will be stored if deployed via `deployer` using
     * the `CREATE2` opcode. Any change in the `initCodeHash` or `salt` values will result in a new
     * destination address. This implementation is based on OpenZeppelin:
     * https://web.archive.org/web/20230921113703/https://raw.githubusercontent.com/OpenZeppelin/openzeppelin-contracts/181d518609a9f006fcb97af63e6952e603cf100e/contracts/utils/Create2.sol.
     * @param salt The 32-byte random value used to create the contract address.
     * @param initCodeHash The 32-byte bytecode digest of the contract creation bytecode.
     * @param deployer The 20-byte deployer address.
     * @return computedAddress The 20-byte address where a contract will be stored.
     */
    function _computeCreate2Address(bytes32 salt, bytes32 initCodeHash, address deployer)
        internal
        pure
        returns (address computedAddress)
    {
        bytes32 hash = keccak256(abi.encodePacked(bytes1(0xff), deployer, salt, initCodeHash));

        // NOTE: cast last 20 bytes of hash to address
        return address(uint160(uint256(hash)));
    }
}
