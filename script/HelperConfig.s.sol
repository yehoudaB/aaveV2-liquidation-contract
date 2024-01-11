// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {ISwapRouter} from "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";
import {LendingPoolAddressesProvider} from "../src/aave-v2-updated/LendingPoolAddressesProvider.sol";

contract HelperConfig is Script {
    struct NetworkConfig {
        LendingPoolAddressesProvider lendingPoolAddressesProvider;
        uint256 deployerKey;
        ISwapRouter iSwapRouter;
    }

    uint256 public constant DEFAULT_ANVIL_PRIVATE_KEY =
        0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;
    NetworkConfig public activeNetworkConfig;
    address public constant lendingPoolAddressesProviderAddressPolygon = 0xd05e3E715d945B59290df0ae8eF85c1BdB684744;

    constructor() {
        if (block.chainid == 137) {
            activeNetworkConfig = getPolygonConfig();
        }
        // for local testing we use a fork  localy (see README.md)
    }

    function getPolygonConfig() public view returns (NetworkConfig memory) {
        LendingPoolAddressesProvider lendingPoolAddressesProvider =
            LendingPoolAddressesProvider(lendingPoolAddressesProviderAddressPolygon);
        ISwapRouter iSwapRouter = ISwapRouter(0xE592427A0AEce92De3Edee1F18E0157C05861564);
        return NetworkConfig({
            lendingPoolAddressesProvider: lendingPoolAddressesProvider,
            deployerKey: vm.envUint("PRIVATE_KEY"),
            iSwapRouter: iSwapRouter
        }); // this is for fork testing only
    }
}
