// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import "forge-std/Script.sol";
import "../src/wnh_contracts/RangedBondingCurveFactory.sol";
import "../src/wnh_contracts/DutchAuction.sol";
import "../src/wnh_contracts/Quoter.sol";
import "../src/wnh_contracts/FeeCollector.sol";
import "../src/wnh_contracts/libraries/RangeMath.sol";
import "../src/wnh_contracts/interfaces/IRangedBondingCurveFactory.sol";

contract MinimalDeployAuctionAndFactory is Script {
    uint256 constant MAX_TOKEN_SUPPLY = 100_000_000 ether;
    uint256 constant MAX_NATIVE_TOKEN_SUPPLY = 34999999999999999649036406300000000000000;

    function run() external {
        vm.createSelectFork("hyper_evm_testnet");
        
        address owner = vm.envAddress("OWNER");
        address treasury = vm.envAddress("TREASURY");
        address nativeToken = vm.envAddress("NATIVE_TOKEN_ADDRESS");

        // Step 1: Deploy factory
        vm.startBroadcast();
        RangedBondingCurveFactory factory = new RangedBondingCurveFactory(owner);
        vm.stopBroadcast();
        console.log("Step 1: Factory deployed at:", address(factory));

        // Step 2: Deploy quoter
        vm.startBroadcast();
        Quoter quoter = new Quoter(owner);
        vm.stopBroadcast();
        console.log("Step 2: Quoter deployed at:", address(quoter));

        // Step 3: Deploy FeeCollector
        vm.startBroadcast();
        address tempBuybackFund = treasury; // Use treasury as temporary buyback fund
        FeeCollector feeCollector = new FeeCollector(
            tempBuybackFund,  // buybackFund
            treasury,         // treasury
            nativeToken,      // nativeToken
            owner            // owner
        );
        vm.stopBroadcast();
        console.log("Step 3: FeeCollector deployed at:", address(feeCollector));

        // Step 4: Deploy Dutch auction
        vm.startBroadcast();
        DutchAuction dutchAuction = new DutchAuction(owner, nativeToken, treasury, address(factory));
        vm.stopBroadcast();
        console.log("Step 4: DutchAuction deployed at:", address(dutchAuction));

        // Step 5: Initialize factory with minimal params
        vm.startBroadcast();
        IRangedBondingCurveFactory.CurveParams memory params = _getMinimalCurveParams(
            address(quoter),
            nativeToken,
            address(feeCollector)
        );
        factory.initialize(address(dutchAuction), params);
        vm.stopBroadcast();
        console.log("Step 5: Factory initialized");

        // Step 6: Deploy curve
        vm.startBroadcast();
        bytes32 salt = 0x64e6ca0e7e054882cabc608a4ed03fa0f0fc1dd1977fc2a8c24a885fca1cc991;
        (address curve,) = factory.deployCurve(
            IRangedBondingCurveFactory.DeploymentParams({
                name: "Higher Token",
                symbol: "$HIGHER",
                round: 0,
                salt: salt,
                initialBuyAmount: 0
            })
        );
        vm.stopBroadcast();
        console.log("Step 6: Curve deployed at:", address(curve));

        console.log("\n=== MINIMAL DEPLOYMENT COMPLETE ===");
        console.log("RangedBondingCurveFactory:", address(factory));
        console.log("DutchAuction:", address(dutchAuction));
        console.log("Curve:", address(curve));
        console.log("HigherToken:", IRangedBondingCurve(payable(curve)).getConfig().bondedToken);
        console.log("Quoter:", address(quoter));
        console.log("FeeCollector:", address(feeCollector));

        console.log("\n=== ENV FORMAT ===");
        console.log("FACTORY_ADDRESS=%s", address(factory));
        console.log("DUTCH_AUCTION_ADDRESS=%s", address(dutchAuction));
        console.log("CURVE_ADDRESS=%s", address(curve));
        console.log("HIGHER_TOKEN_ADDRESS=%s", IRangedBondingCurve(payable(curve)).getConfig().bondedToken);
        console.log("QUOTER_ADDRESS=%s", address(quoter));
        console.log("FEE_COLLECTOR_ADDRESS=%s", address(feeCollector));

        console.log("\n=== NEXT STEPS ===");
        console.log("1. Deploy AutoAbsorb contract for buyback fund");
        console.log("2. Call feeCollector.setBuybackFund() with the new AutoAbsorb address");
        console.log("3. Deploy Points contract");
        console.log("4. Call factory.setCurveParams() with all contract addresses");
        console.log("5. Initialize the deployed contracts with the curve address");
    }

    function _getMinimalCurveParams(
        address quoter,
        address nativeToken,
        address feeCollector
    ) internal pure returns (IRangedBondingCurveFactory.CurveParams memory) {
        RangeMath.Range[] memory ranges = new RangeMath.Range[](3);
        ranges[0] = RangeMath.Range({
            coefficient: 280 ether,
            power: 4,
            constantTerm: 280 ether,
            tokenSupplyAtBoundary: MAX_TOKEN_SUPPLY * 80 / 100,
            nativeAmountAtBoundary: 403593750000000001669
        });
        ranges[1] = RangeMath.Range({
            coefficient: 875 ether,
            power: 2,
            constantTerm: 963.59375 ether,
            tokenSupplyAtBoundary: MAX_TOKEN_SUPPLY * 5 / 100,
            nativeAmountAtBoundary: 349036406250000140000001
        });
        ranges[2] = RangeMath.Range({
            coefficient: 35000 ether,
            power: 1,
            constantTerm: 350963.5937 ether,
            tokenSupplyAtBoundary: 1 ether,
            nativeAmountAtBoundary: MAX_NATIVE_TOKEN_SUPPLY
        });

        return IRangedBondingCurveFactory.CurveParams({
            maxSupply: MAX_TOKEN_SUPPLY,
            maxNativeTokenSupply: MAX_NATIVE_TOKEN_SUPPLY,
            feeCollector: feeCollector,
            autoAbsorb: address(0),   // Will be set later
            points: address(0),       // Will be set later
            quoter: quoter,
            nativeToken: nativeToken,
            maxInitialBuyAmount: 0,
            ranges: ranges
        });
    }
} 