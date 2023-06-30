//SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Test, console} from "forge-std/Test.sol";
import {FundMe} from "../../src/FundMe.sol";
import {DeployFundMe} from "../../script/DeployFundMe.s.sol"; //this ensures we always deploy in our test setup the exact same way we deploy in our script
import {FundFundMe, WithdrawFundMe} from "../../script/Interactions.s.sol"; //this ensures we always deploy in our test setup the exact same way we deploy in our script

//with the "is" keyword we can inherit from other contracts
contract InteractionsTest is Test {
    FundMe fundMe;

    address USER = makeAddr("user"); //makeAddr is a Foundry cheatcode (https://book.getfoundry.sh/) and creates a random address
    uint256 constant SEND_VALUE = 0.1 ether;
    uint256 constant STARTING_BALANCE = 10.0 ether;
    uint256 constant GAS_PRICE = 1; //if we want to take into account trx costs during test

    function setUp() external {
        DeployFundMe deploy = new DeployFundMe();
        fundMe = deploy.run();
        vm.deal(USER, STARTING_BALANCE);
    }

    function testUserCanFundInteractions() public {
        //instead of funding directly with the functions, we are fonna import FundFundMe
        FundFundMe fundFundMe = new FundFundMe();
        fundFundMe.fundFundMe(address(fundMe));

        WithdrawFundMe withdrawFundMe = new WithdrawFundMe();
        withdrawFundMe.withdrawFundMe(address(fundMe));

        assertEq(address(fundMe).balance, 0);
    }
}
