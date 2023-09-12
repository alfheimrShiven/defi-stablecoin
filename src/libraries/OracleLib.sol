// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

/*
 * @title OracleLib
 * @author Shiven 
 * @notice This library will return the latestRoundData of the Eth Usd pricefeed.
 * If the last updated value is more than 3 hours stale (from the Chainlink Oracle), 
 * we will consider the service to be down, hence revert with an error.
 * Known Error:
 * This will mean that our protocol might hold a lot of value and may not function, unless the service
 * is back to normal..
*/ 

import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

library OracleLib {
    error OracleLib__PriceFeedTimeout();
    uint256 private constant TIMEOUT = 3 hours; 
    function staleCheckLatestRoundData(AggregatorV3Interface chainlinkPriceFeed) public view returns (
            uint80,
            int256,
            uint256,
            uint256,
            uint80) {

            (uint80 roundId,
            int256 answer,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound) = chainlinkPriceFeed.latestRoundData();

            if(block.timestamp - updatedAt > TIMEOUT) {
                revert OracleLib__PriceFeedTimeout();
            }

            return (roundId, answer, startedAt, updatedAt, answeredInRound);
            }
}