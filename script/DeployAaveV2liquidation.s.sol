// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {AaveV2Liquidation} from "../src/AaveV2Liquidation.sol";
import {ILendingPoolAddressesProvider} from "../src/aave-v2-updated/ILendingPoolAddressesProvider.sol";
import {ISwapRouter} from "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";

contract DeployAaveV2Liquidation is Script {
    function run() external returns (AaveV2Liquidation, HelperConfig) {
        HelperConfig helperConfig = new HelperConfig();

        (ILendingPoolAddressesProvider lendingPoolAddressesProvider, uint256 deployerKey, ISwapRouter iSwapRouter) =
            helperConfig.activeNetworkConfig();

        vm.startBroadcast(deployerKey);

        AaveV2Liquidation aaveV2Liquidation =
            new AaveV2Liquidation(0x9945852318056dC9EbAfdC3caC70d05e0fBa00F7, lendingPoolAddressesProvider, iSwapRouter);
        vm.stopBroadcast();
        return (aaveV2Liquidation, helperConfig);
    }
}
