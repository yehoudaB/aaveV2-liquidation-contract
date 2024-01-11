// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {Vm} from "forge-std/Vm.sol";

import {HelperConfig} from "script/HelperConfig.s.sol";
import {DeployAaveV2Liquidation} from "script/DeployAaveV2Liquidation.s.sol";
import {AaveV2Liquidation} from "src/AaveV2Liquidation.sol";
import {PriceOracle} from "../src/aave-v2-updated/PriceOracle.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {LendingPoolAddressesProvider} from "../src/aave-v2-updated/LendingPoolAddressesProvider.sol";
import {ILendingPool} from "../src/aave-v2-updated/ILendingPool.sol";

contract testAaveV2Liquidation is Test {
    address[] public aaveMarketTokenAddresses = [
        0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174, // usdc
        0xc2132D05D31c914a87C6611C10748AEb04B58e8F, // usdt
        0x8f3Cf7ad23Cd3CaDbD9735AFf958023239c6A063, // dai
        0x1BFD67037B42Cf73acF2047067bd4F2C47D9BfD6, // wbtc
        0x7ceB23fD6bC0adD59E62ac25578270cFf1b9f619 // weth
    ];
    address public USER_1 = 0x3e122A3dB43d225DD5BFFD929AD4176ce69117E0; // account 1 metamask dev (same as .env private key)

    address public USER_TO_LIQUIDATE = 0xAD9D3A03648dBcc27AA458238474a1ff88234Acf;

    HelperConfig helperConfig;

    uint256 deployerKey;
    AaveV2Liquidation aaveV2LiquidationAAVE;
    PriceOracle priceOracleOriginal;
    PriceOracle priceOracleMock;
    LendingPoolAddressesProvider lendingPoolAddressesProvider;
    ILendingPool lendingPool;
    address poolAddressesProviderOwner;
    address polygonUsdc = 0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174;
    mapping(address => uint256) tokenPrices;

    function setUp() public {
        DeployAaveV2Liquidation aaveV2LiquidationDeployer = new DeployAaveV2Liquidation();
        (aaveV2LiquidationAAVE, helperConfig) = aaveV2LiquidationDeployer.run();
        console.log("aaveV2LiquidationAAVE: %s", address(aaveV2LiquidationAAVE));
        console.log("aaveV2LiquidationAAVE owner: %s", address(aaveV2LiquidationAAVE.owner()));
        (lendingPoolAddressesProvider, deployerKey,) = helperConfig.activeNetworkConfig();
        poolAddressesProviderOwner = lendingPoolAddressesProvider.owner();
        console.log("poolAddressesProviderOwner: %s", poolAddressesProviderOwner);
        lendingPool = ILendingPool(lendingPoolAddressesProvider.getLendingPool());

        console.log("lendingPool: %s", address(lendingPool));
        priceOracleOriginal = PriceOracle(lendingPoolAddressesProvider.getPriceOracle());
        console.log("priceOracleOriginal: %s", address(priceOracleOriginal));
    }

    function checkUserHasAavePositions() public view returns (bool) {
        (
            uint256 totalCollateralBase,
            uint256 totalDebtBase,
            uint256 availableBorrowsBase,
            uint256 currentLiquidationThreshold,
            uint256 ltv,
            uint256 healthFactor
        ) = lendingPool.getUserAccountData(USER_TO_LIQUIDATE);
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
        lendingPoolAddressesProvider.setPriceOracle(address(priceOracleMock));
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
        priceOracleMock.setAssetPrice(polygonUsdc, 3682703684285972);
        checkUserHasAavePositions();
        console.log("new usdc price: %s", priceOracleMock.getAssetPrice(polygonUsdc));
        vm.stopPrank();

        vm.deal(USER_1, 100 ether);
        address vDebtUsdc = lendingPool.getReserveData(polygonUsdc).variableDebtTokenAddress;
        uint256 vDebtUsdcBalance = IERC20(vDebtUsdc).balanceOf(USER_TO_LIQUIDATE);
        console.log("vDebtUsdcBalance: %s", vDebtUsdcBalance);

        vm.startBroadcast(USER_1);

        aaveV2LiquidationAAVE.liquidateUser(
            USER_TO_LIQUIDATE,
            0x1BFD67037B42Cf73acF2047067bd4F2C47D9BfD6, /* wbtc */
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
}
