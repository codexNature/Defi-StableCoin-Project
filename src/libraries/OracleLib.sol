// SPDX-License-Identifier: MIT

pragma solidity 0.8.20;

import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

/**
 * @title OracleLib
 * @author Olusola Jaiyeola
 * @notice This Library is used to che3ck the chainlink Oracle for stale data.
 * If a price is stale, the function will revert, and render the DSCEngine unsuable = this is by design
 * We want the DSCEngine to freeze if prices becomes stale
 *
 * so if the chainlink network explodes and you have a lot of money locked in the protocol, you don't wamnt that to happen.
 */
library OracleLib {
    error OracleLib__StalePrice();

    uint256 private constant TIMEOUT = 3 hours;
    function staleCheckLatestRoundData(AggregatorV3Interface priceFeed)
        public
        view
        returns (uint80, int256, uint256, uint256, uint80)
    {
      (uint80 roundId,
      int256 answer,
      uint256 startedAt,
      uint256 updatedAt,
      uint80 answeredInRound
    ) =
          priceFeed.latestRoundData();
      
      uint256 secondsSince = block.timestamp - updatedAt;
      if(secondsSince > TIMEOUT) revert OracleLib__StalePrice();
      return (roundId, answer, startedAt, updatedAt, answeredInRound);

    }
}
