// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {Test, console} from "forge-std/Test.sol";
import {FundMe} from "../../src/FundMe.sol";
import {DeployFundMe} from "../../script/DeployFundMe.s.sol"; //this ensures we always deploy in our test setup the exact same way we deploy in our script

//with the "is" keyword we can inherit from other contracts
contract FundMeTest is Test {
    FundMe fundMe;

    address USER = makeAddr("user"); //makeAddr is a Foundry cheatcode (https://book.getfoundry.sh/) and creates a random address
    uint256 constant SEND_VALUE = 0.1 ether;
    uint256 constant STARTING_BALANCE = 10.0 ether;
    uint256 constant GAS_PRICE = 1; //if we want to take into account trx costs during testing

    function setUp() external {
        //this is a function that is part of the Test contract
        //it is used to set up the test environment
        //it is called before each test

        //we want to deploy the FundMe contract in the same way we deploy it in our script
        DeployFundMe deployFundMe = new DeployFundMe();
        fundMe = deployFundMe.run(); //now the run fucntion in the DeployFundMe contract is called and returns a FundMe contract
        vm.deal(USER, STARTING_BALANCE); //this is a Foundry cheatcode (https://book.getfoundry.sh/) and gives the USER address 10 ether
    }

    function testMinimumDollarIsFive() public {
        assertEq(fundMe.MINIMUM_USD(), 5e18);
    }

    function testOwnerisMessageSender() public {
        assertEq(fundMe.getOwner(), msg.sender);
    }

    //to run only this test and not the others: forge test -m testPriceFeedVersionIsAccurate
    //for more details on the errors, change the visibility: forge test --mt testPriceFeedVersionIsAccurate -vvv
    //but this wont work since anvil is spanning up a temporary chain and wont know about the address we are referring to
    //our options:
    //1. pass frok url: forge test --mt testPriceFeedVersionIsAccurate -vvv --fork-url $SEPOLIA_RPC_URL
    //anvil will spin up, but will pretend to run on and read from the sepolia chain as opposed to a completely blank chain
    function testPriceFeedVersionIsAccurate() public {
        uint256 version = fundMe.getVersion();
        assertEq(version, 4);
    }

    function testFundFailsWithoutEnoughEth() public {
        vm.expectRevert(); //expectRevert is a Foundry cheatcode (https://book.getfoundry.sh/) and says that the next line should revert
        fundMe.fund(); //here we call the fund function of the fundMe contract without sending any ETH, which is less than the minUSD
    }

    function testFundUpdatesFundedDataStructure() public {
        vm.prank(USER); //this is another foundry cheatcode (https://book.getfoundry.sh/) and pretends that the next line is called by the USER address
        fundMe.fund{value: SEND_VALUE}();

        uint256 amountFunded = fundMe.getAddressToAmountFunded(USER);
        assertEq(amountFunded, SEND_VALUE);
    }

    function testAddsFunderToArrayOfFunders() public {
        vm.prank(USER);
        fundMe.fund{value: SEND_VALUE}();

        address funder = fundMe.getFunder(0);
        assertEq(funder, USER);
    }

    modifier funded() {
        //we are gonna use it a loto times, this modifier will save a loto space
        vm.prank(USER);
        fundMe.fund{value: SEND_VALUE}();
        _;
    }

    function testOnlyOwnerCanWithdraw() public funded {
        vm.expectRevert(); //the next line should revert (skips vm stuff)
        vm.prank(USER); //USER was a funder but is not the owner of the contract
        fundMe.withdraw();
    }

    function testWirhdrawWithASingleFunder() public funded {
        //Arrange - Act - Assert methodology:
        //Arrange
        uint256 startingOwnerBalance = fundMe.getOwner().balance;
        uint256 startingFundMeBalance = address(fundMe).balance;

        //Act
        /*uint256 gasStart = gasleft(); //gasLeft() is a built-in function in Solidity, tells how much gas is left after the trx call. If we sent e.g. 1000 gas ***
        vm.txGasPrice(GAS_PRICE); //we can set the gas price with this cheatcode (https://book.getfoundry.sh/)*/
        vm.prank(fundMe.getOwner());
        fundMe.withdraw(); //*** and this costed 200 gas
        /*uint256 gasEnd = gasleft();    //gas left after calling withdraw(). ***this would be 800 gas
        //uint256 gasUsed = (gasStart - gasEnd) * tx.gasprice;
        //console.log(gasUsed); */

        //Assert
        uint256 EndingOwnerBalance = fundMe.getOwner().balance;
        uint256 EndingFundMeBalance = address(fundMe).balance;
        assertEq(EndingFundMeBalance, 0);
        assertEq(
            startingOwnerBalance + startingFundMeBalance,
            EndingOwnerBalance
        ); //how is this true when we are spending gas when calling withdraw()? On anvil, gas price defaults to 0
    }

    function testWithdrawFromMultipleFunders() public funded {
        //Arrange
        uint160 numberOfFunders = 10;
        uint160 startingFunderIndex = 1; //we can crate an address with an index like: address(0). However, the index has to be a uint160, which has the same size as an address-type variable
        for (uint160 i = startingFunderIndex; i < numberOfFunders; i++) {
            hoax(address(i), SEND_VALUE); //hoax is a Foundry standard cheatcode (https://book.getfoundry.sh/) and crates and address and funds it (like the combination of makeAddr and vm.deal)

            //fund the contract from the address
            fundMe.fund{value: SEND_VALUE}();
        }

        uint256 startingOwnerBalance = fundMe.getOwner().balance;
        uint256 startingFundMeBalance = address(fundMe).balance;

        //Act
        vm.startPrank(fundMe.getOwner()); //vm.startprank and vm.stopprank synthax, and everything in between will be called by the prank address
        fundMe.withdraw();
        vm.stopPrank();

        //Assert
        assertEq(address(fundMe).balance, 0);
        assertEq(
            startingOwnerBalance + startingFundMeBalance,
            fundMe.getOwner().balance
        );
    }

    function testWithdrawFromMultipleFundersCheaper() public funded {
        //this function uses the cheaperWithdraw() function from fundMe.sol, which function reads the length of the funder array only once to store it in memory instrad of reading it muiltiple times form storage, saving a loto gas this way
        //Arrange
        uint160 numberOfFunders = 10;
        uint160 startingFunderIndex = 1; //we can crate an address with an index like: address(0). However, the index has to be a uint160, which has the same size as an address-type variable
        for (uint160 i = startingFunderIndex; i < numberOfFunders; i++) {
            hoax(address(i), SEND_VALUE); //hoax is a Foundry standard cheatcode (https://book.getfoundry.sh/) and crates and address and funds it (like the combination of makeAddr and vm.deal)

            //fund the contract from the address
            fundMe.fund{value: SEND_VALUE}();
        }

        uint256 startingOwnerBalance = fundMe.getOwner().balance;
        uint256 startingFundMeBalance = address(fundMe).balance;

        //Act
        vm.startPrank(fundMe.getOwner()); //vm.startprank and vm.stopprank synthax, and everything in between will be called by the prank address
        fundMe.cheaperWithdraw();
        vm.stopPrank();

        //Assert
        assertEq(address(fundMe).balance, 0);
        assertEq(
            startingOwnerBalance + startingFundMeBalance,
            fundMe.getOwner().balance
        );
    }
}
