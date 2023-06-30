// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";
import {FundMe} from "../src/FundMe_before_refactoring.sol";

contract DeployFundMe is Script {
    FundMe fundMe;

    function run() public {
        vm.startBroadcast();
        new FundMe();
        vm.stopBroadcast();
    }
}
