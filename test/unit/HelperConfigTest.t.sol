// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {Test} from "forge-std/Test.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";

contract HelperConfigTest is Test {
    HelperConfig config;
    address public constant WETH_USD_PRICE_FEED_SEPOLIA = 0x694AA1769357215DE4FAC081bf1f309aDC325306;
    address public expectedWethUsdPriceFeed;

    function testSepoliaConfigIsUsedOnSepoliaChain() public {
        vm.chainId(11155111);
        config = new HelperConfig();
        (expectedWethUsdPriceFeed,,,,) = config.activeNetworkConfig();

        assertEq(expectedWethUsdPriceFeed, WETH_USD_PRICE_FEED_SEPOLIA);
    }
}
