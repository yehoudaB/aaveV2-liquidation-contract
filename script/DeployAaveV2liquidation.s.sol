// SPDX-License-Identifier: MIT
import {Script, console} from "forge-std/Script.sol";
import {HelperConfig} from "./HelperConfig.s.sol";

pragma solidity ^0.8.20;

contract DeployAaveV2Liquidation is Script {
    function run() external returns (AaveV2Liquidation, HelperConfig) {
        HelperConfig helperConfig = new HelperConfig();

        (IPoLendingPoolAddressesProviderol lendingPoolAddressesProvider, uint256 deployerKey, ISwapRouter iSwapRouter) =
            helperConfig.activeNetworkConfig();

        vm.startBroadcast(deployerKey);

        AaveV2Liquidation aaveV2Liquidation =
            new AaveV2Liquidation(0x9945852318056dC9EbAfdC3caC70d05e0fBa00F7, lendingPoolAddressesProvider, iSwapRouter);
        vm.stopBroadcast();
        return (aaveV2Liquidation, helperConfig);
    }
}
