// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";
import {FundMe} from "../src/FundMe.sol";
import {HelperConfig} from "./HelperConfig.s.sol"; //this is a part of our refactoring efforts: we do not want any hardcoded pricefeed addresses in the code, as we want to be able to use and test this in any EVm chains

contract DeployFundMe is Script {
    //.
    function run() public returns (FundMe) {
        //before startBroadcast => not a "real" transaction
        HelperConfig helperConfig = new HelperConfig();
        address ethUsdPriceFeed = helperConfig.activeNetworkConfig();

        //after startBroadcast => a "real" transaction
        vm.startBroadcast();
        FundMe fundMe = new FundMe(ethUsdPriceFeed); //ethUsdPriceFeed param goes to the constructor of FundMe
        vm.stopBroadcast();
        return fundMe;
    }
}
