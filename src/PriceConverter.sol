// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

//this will get us a mimumalistic ABI so we can interact with this chainlink contract
//import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
//the above is not recognized by foundry (only by remix) except if we install the dependency:
//forge install /smartcontractkit/chainlink-brownie-contracts@0.6.1 --no-commit
//then these contracts will show up locally in the lib library
//Then we need to tell Foundry what this @chainlink/contracts should point to the lib folder. For this, we do a remapping in foundry.toml
//Now we are ready to import
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

//libraries cannot have state variables
//all funcs have to be internal
library PriceConverter {
    function getPrice(
        AggregatorV3Interface priceFeed
    ) internal view returns (uint256) {
        //This function returns multiple variables but we donnt care about them, only about the price
        //this price variable is representing the price of ETH in terms of USD
        //and returns a number with 8 decimals but without a decimal sign
        (, int256 price, , , ) = priceFeed.latestRoundData();
        //msg.value has 18 decimal places, price has 8. Multiply to match up
        //typecasting is necessary since price is int, msg.value is uint
        return uint256(price * 1e10);
    }

    function getConversionRate(
        uint256 ethAmount,
        AggregatorV3Interface priceFeed
    ) internal view returns (uint256) {
        uint256 ethPrice = getPrice(priceFeed);
        //division is needed as 1e18 * 1e18 = 1e36
        //In Solidity it is very important to multiply before dividing, since Solidity having 0 decimals would give 1 / 2 = 0
        uint256 ethAmountInUsd = (ethPrice * ethAmount) / 1e18;
        return ethAmountInUsd;
    }
}
