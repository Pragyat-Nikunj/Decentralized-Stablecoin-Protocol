// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import {OracleLib} from "src/libraries/OracleLib.sol";
import {Test} from "forge-std/Test.sol";
import {MockV3Aggregator} from "test/mocks/MockV3Aggregator.sol";

/**
 * @title OracleLibTest
 * @author Pragyat Nikunj
 * @notice This contract tests the OracleLib library for stale price checks.
 */

contract OraclelibTest is Test {
    using OracleLib for AggregatorV3Interface;

    AggregatorV3Interface public priceFeed;

    uint8 constant DECIMALS = 8;
    int256 constant INITIAL_PRICE = 2000e8; // 2000 with

    constructor() {
        priceFeed = AggregatorV3Interface(address(new MockV3Aggregator(DECIMALS, INITIAL_PRICE)));
    }

    function testStalePriceRevert() public {
        vm.warp(block.timestamp + 4 hours);
        vm.expectRevert(OracleLib.OracleLib__StalePrice.selector);
        priceFeed.staleCheckLatestRoundData();
    }

    function testStalePriceWorksAsExpected() public {
        (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound) =
            priceFeed.staleCheckLatestRoundData();
        assertEq(answer, INITIAL_PRICE);
    }
}
