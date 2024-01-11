// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {Vm} from "forge-std/Vm.sol";

import {HelperConfig} from "script/HelperConfig.s.sol";
import {DeployAaveV2Liquidation} from "script/DeployAaveV2Liquidation.s.sol";
import {AaveV2Liquidation} from "src/AaveV2Liquidation.sol";
import {PriceOracle} from "@aave-v2/contracts/mocks/oracle/PriceOracle.sol";

contract testAaveV2Liquidation is Test {
    address[] public aaveMarketTokenAddresses = [
        0xE0B52e49357Fd4DAf2c15e02058DCE6BC0057db4,
        0x8f3Cf7ad23Cd3CaDbD9735AFf958023239c6A063,
        0xE111178A87A3BFf0c8d18DECBa5798827539Ae99,
        0x4e3Decbb3645551B8A19f0eA1678079FCB33fB4c,
        0xa3Fa99A148fA48D14Ed51d610c367C61876997F1,
        0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174,
        0xc2132D05D31c914a87C6611C10748AEb04B58e8F,
        0xD6DF932A45C0f255f85145f286eA0b292B21C90B,
        0x9a71012B13CA4d3D0Cdc72A177DF3ef03b0E76A3,
        0x172370d5Cd63279eFa6d502DAB29171933a610AF,
        0x85955046DF4668e1DD369D2DE9f3AEB98DD2A369,
        0x385Eeac5cB85A38A9a07A70c73e0a3271CfB54A7,
        0x53E0bca35eC356BD5ddDFebbD1Fc0fD03FaBad39,
        0xfa68FB4628DFF1028CFEc22b4162FCcd0d45efb6,
        0x3A58a54C066FdC0f2D55FC9C89F0415C92eBf3C4,
        0x0b3F868E0BE5597D5DB7fEB59E1CADBb0fdDa50a,
        0x1BFD67037B42Cf73acF2047067bd4F2C47D9BfD6,
        0x7ceB23fD6bC0adD59E62ac25578270cFf1b9f619,
        0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270,
        0x03b54A6e9a984069379fae1a4fC4dBAE93B3bCCD
    ];
    address public USER_1 = 0x3e122A3dB43d225DD5BFFD929AD4176ce69117E0; // account 1 metamask dev (same as .env private key)
    address public USER_TO_LIQUIDATE = 0x7fA57d19b5C60a8ADa62929fd21bcEaC0689851A;

    HelperConfig helperConfig;

    uint256 deployerKey;
    AaveV2Liquidation aaveV2LiquidationAAVE;
    PriceOracle priceOracleOriginal;
    PriceOracle priceOracleMock;

    IPoolAddressesProvider iPoolAddressesProvider;
    PoolAddressesProvider poolAddressesProvider;
    address poolAddressesProviderOwner;
    address polygonUsdc = 0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174;
    mapping(address => uint256) tokenPrices;

    function setUp() public {
        DeployAaveV2Liquidation aaveV2LiquidationDeployer = new DeployAaveV2Liquidation();
        (, aaveV2LiquidationAAVE, helperConfig) = aaveV2LiquidationDeployer.run();
        console.log("aaveV2LiquidationAAVE: %s", address(aaveV2LiquidationAAVE));
        console.log("aaveV2LiquidationAAVE owner: %s", address(aaveV2LiquidationAAVE.owner()));
        (iPool, deployerKey,) = helperConfig.activeNetworkConfig();
        iPoolAddressesProvider = IPoolAddressesProvider(iPool.ADDRESSES_PROVIDER());
        poolAddressesProvider = PoolAddressesProvider(address(iPoolAddressesProvider));
        console.log("iPoolAddressesProvider: %s", address(iPoolAddressesProvider));
        poolAddressesProviderOwner = poolAddressesProvider.owner();

        priceOracleOriginal = PriceOracle(poolAddressesProvider.getPriceOracle());
    }

    function checkUserHasAavePositions() public view returns (bool) {
        (
            uint256 totalCollateralBase,
            uint256 totalDebtBase,
            uint256 availableBorrowsBase,
            uint256 currentLiquidationThreshold,
            uint256 ltv,
            uint256 healthFactor
        ) = iPool.getUserAccountData(USER_TO_LIQUIDATE);
        console.log("totalCollateralBase: %s", totalCollateralBase);
        console.log("totalDebtBase: %s", totalDebtBase);
        console.log("availableBorrowsBase: %s", availableBorrowsBase);
        console.log("currentLiquidationThreshold: %s", currentLiquidationThreshold);
        console.log("ltv: %s", ltv);
        console.log("healthFactor: %s", healthFactor);
        if (healthFactor > 0) {
            return true;
        }
        return false;
    }

    function setMockPriceOracleAsOracle() public {
        for (uint256 i = 0; i < aaveMarketTokenAddresses.length; i++) {
            address tokenAddress = aaveMarketTokenAddresses[i];
            uint256 tokenPrice = priceOracleOriginal.getAssetPrice(tokenAddress);
            tokenPrices[tokenAddress] = tokenPrice;
        }
        vm.startPrank(poolAddressesProviderOwner);

        priceOracleMock = new PriceOracle();
        poolAddressesProvider.setPriceOracle(address(priceOracleMock));
        for (uint256 i = 0; i < aaveMarketTokenAddresses.length; i++) {
            address tokenAddress = aaveMarketTokenAddresses[i];
            uint256 tokenPrice = tokenPrices[tokenAddress];
            priceOracleMock.setAssetPrice(tokenAddress, tokenPrice);
        }
        vm.stopPrank();
    }

    function testLiquidateUserFlAave() public {
        uint256 contractUsdcPreviousBalance = IERC20(polygonUsdc).balanceOf(address(aaveV2LiquidationAAVE));
        if (!checkUserHasAavePositions()) {
            console.log("user has no aave positions");
            return;
        }

        setMockPriceOracleAsOracle();
        uint256 usdcNewPrice = priceOracleMock.getAssetPrice(polygonUsdc);
        console.log("usdc  price: %s", usdcNewPrice);
        vm.startPrank(address(priceOracleMock));
        priceOracleMock.setAssetPrice(polygonUsdc, 10000008560);
        console.log("new usdc price: %s", priceOracleMock.getAssetPrice(polygonUsdc));
        vm.stopPrank();

        vm.deal(USER_1, 100 ether);
        address vDebtUsdc = iPool.getReserveData(polygonUsdc).variableDebtTokenAddress;
        uint256 vDebtUsdcBalance = IERC20(vDebtUsdc).balanceOf(USER_TO_LIQUIDATE);
        console.log("vDebtUsdcBalance: %s", vDebtUsdcBalance);
        vm.startBroadcast(USER_1);

        aaveV2LiquidationAAVE.liquidateUser(
            USER_TO_LIQUIDATE,
            0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270, /* wmatic */
            polygonUsdc,
            vDebtUsdcBalance,
            false,
            3000
        );
        vm.stopBroadcast();

        uint256 contractUsdcNewBalance = IERC20(polygonUsdc).balanceOf(address(aaveV2LiquidationAAVE));
        console.log("usdcEarned: %s", contractUsdcNewBalance - contractUsdcPreviousBalance);
        assert(contractUsdcNewBalance > contractUsdcPreviousBalance);
    }

    function testPossibleFeesFlAave() public {}
}
