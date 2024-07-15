// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface AggregatorV3Interface {
    function latestRoundData()
        external
        view
        returns (
            uint80 roundId,
            int256 answer,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        );
}

contract EthToUsdtConverter {
    AggregatorV3Interface internal priceFeed;
    uint256 constant DECIMAL_DIFFERENCE = 12; // 18 - 6

    constructor(address _priceFeed) {
        priceFeed = AggregatorV3Interface(_priceFeed);
    }

    // Function to convert ETH amount (18 decimals) to USDT amount (6 decimals)
    function convertEthToUsdt(uint256 ethAmount) public view returns (uint256) {
        (
            ,
            int256 price,
            ,
            ,
            
        ) = priceFeed.latestRoundData();
        
        // Ensure the price is positive
        require(price > 0, "Invalid price");

        // Price is scaled by 10^8, we need to adjust it to 10^6
        uint256 usdtPrice = uint256(price) / 1e2; // Convert price to 6 decimals

        // Convert ETH to USDT
        uint256 usdtAmount = (ethAmount * usdtPrice) / (10 ** 18);

        return usdtAmount;
    }
}
