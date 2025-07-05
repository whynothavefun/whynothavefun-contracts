// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import "../libraries/RangeMath.sol";

/**
 * @title IRangedBondingCurveFactory
 * @dev Interface for the RangedBondingCurveFactory contract
 */
interface IRangedBondingCurveFactory {
    // Custom Errors
    error TokenSupplyAtBoundaryIsZero(uint256 index);
    error TokenSupplyAtBoundaryNotGreaterThanNext(uint256 current, uint256 next);
    error NativeAmountAtBoundaryNotLessThanNext(uint256 current, uint256 next);
    error CurveAlreadyExistsForToken(address bondedToken);
    error TickerAlreadyUsed(string ticker);
    error InitialBuyAmountExceedsMaxInitialBuyAmount(uint256 initialBuyAmount, uint256 maxInitialBuyAmount);
    error InvalidAutoAbsorbAddress();
    error InvalidQuoterAddress();
    error InvalidFeeCollectorAddress();
    error InvalidNativeTokenAddress();
    error AtLeastOneRangeMustBeDefined();
    error MaxSupplyMustBeGreaterThanZero();
    error MaxNativeTokenSupplyMustBeGreaterThanZero();

    // Structs
    struct CurveParams {
        uint256 maxSupply;
        uint256 maxNativeTokenSupply;
        address feeCollector;
        address autoAbsorb;
        address points;
        address quoter;
        address nativeToken;
        uint256 maxInitialBuyAmount;
        RangeMath.Range[] ranges;
    }

    struct DeploymentParams {
        uint256 round;
        bytes32 salt;
        uint256 initialBuyAmount;
        string name;
        string symbol;
    }

    // Events
    event CurveDeployed(
        address indexed curve,
        address indexed bondedToken,
        address creator,
        string name,
        string symbol,
        uint256 round,
        uint256 maxSupply,
        uint256 maxNativeTokenSupply,
        address feeCollector,
        RangeMath.Range[] ranges
    );

    event TokenInfo(address indexed token, string name, string symbol, uint256 maxSupply);

    // Functions
    //@dev returns the address of the curve for a given token
    //@param _token the address of the token
    //@return the address of the curve
    function getTokenToCurve(address _token) external view returns (address);

    //@dev returns true if the curve is deployed
    //@param _curve the address of the curve
    //@return true if the curve is deployed, false otherwise
    function isCurveDeployed(address _curve) external view returns (bool);

    //@dev returns the number of deployed curves
    //@return the number of deployed curves
    function getDeployedCurvesCount() external view returns (uint256);

    //@dev returns the curve address at a given index
    //@param _index the index of the curve
    //@return the address of the curve at the given index
    function getDeployedCurveAtIndex(uint256 _index) external view returns (address);

    /**
     * @dev Initializes the factory
     * @param params The parameters for the factory
     */
    function initialize(CurveParams memory params) external;

    function setCurveParams(CurveParams memory params) external;

    function deployCurve(DeploymentParams memory params) external returns (address curve, uint256 initialBuyAmount);
}
