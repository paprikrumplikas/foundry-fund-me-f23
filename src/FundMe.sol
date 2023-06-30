// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

//for simplified commands, see Makefile

//Funcionalities we want
//get funds from users
//withdraw funds
//set a mimimum funding value in USD

//this is a refactored version of our codebase: it has no hardcoded addresses annd, hence, can be used not only on sepolia

//importing our custom-made library
//libraries cannot have state vars and all funcs have to be internal
import {PriceConverter} from "./PriceConverter.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

//this custom error saves a loto gas if we use it in an IF + REVERT statement instead of giving a string error message to a REQUIRE statement
//obs the naming converntion. Helps to identifiy which contract the error is coming from
error FundMe__NotOwner();

contract FundMe {
    //to attach the functions in our PriceConverter library to all uint256s:
    using PriceConverter for uint256;

    //if a var is set once outside a function and not changed later, it can be a constant. Saves gas!
    uint256 public constant MINIMUM_USD = 5e18; //e18 to account for the fact that our functions return values with 18 decimal places

    address[] private s_funders; //private vars are more gas efficient than public ones, but then we need to create a getter function for them
    mapping(address funder => uint256 AmountFunded)
        private s_addresstoAmountFunded;

    //if a var is set only once, but not on the same line it is declared (and then not changed), it can be set as immutable. Saves gas
    address private immutable i_owner;
    AggregatorV3Interface private s_priceFeed;

    constructor(address priceFeed) {
        //input param for refactoring
        //this is needed so that only the owner (deployer) of the contract can withdraw funds
        i_owner = msg.sender;
        s_priceFeed = AggregatorV3Interface(priceFeed);
    }

    function fund() public payable {
        //if this require is not fulfilled, the transaction will be reverted.
        //Revert means that whatever happened in that transaction previously will be undone.
        //msg.value returns a value with 18 decimal places
        //After we created a lib and imported it, we can use the line below. The trick here is that msg.value is basically íthe input param
        require(
            msg.value.getConversionRate(s_priceFeed) >= MINIMUM_USD,
            "Didnt send enough ETH"
        ); // 1e18 = 1 ETH

        s_funders.push(msg.sender);
        //This tells us the amount the current sender funded us with.
        //it is equal to the funds he had sent earlier PLUS the funds he sent now
        s_addresstoAmountFunded[msg.sender] += msg.value;
    }

    function cheaperWithdraw() public onlyOwner {
        uint256 fundersLength = s_funders.length; //this is for gas optim. THis way we read this value from storage only once

        for (
            uint256 funderIndex = 0;
            funderIndex < fundersLength;
            funderIndex++
        ) {
            address funder = s_funders[funderIndex];
            s_addresstoAmountFunded[funder] = 0;
        }

        s_funders = new address[](0);

        (bool callSuccess, ) = payable(msg.sender).call{
            value: address(this).balance
        }("");
        require(callSuccess, "Call failed");
    }

    function withdraw() public onlyOwner {
        require(msg.sender == i_owner, "Must be the owner");

        for (
            uint256 funderIndex = 0;
            funderIndex < s_funders.length; //s_funders.length is stored in storage, and we read from storage several times in this loop. This is very expensive.
            funderIndex++
        ) {
            address funder = s_funders[funderIndex];
            s_addresstoAmountFunded[funder] = 0;
        }

        //reset the array
        s_funders = new address[](0);

        //withdraw funds. 3 ways

        //msg.sender IS an address. This has to be tpyecasted as follows
        //payable msg.sender IS a payable address

        //1. transfer. Easiest. Automatically reverts
        /*payable(msg.sender).transfer(address(this).balance);*/

        //2. send. If it is not successful, we would not get our money back unless we revert by adding thequire statement
        /*bool sendSuccess = payable(msg.sender).send(address(this).balance);
            require(sendSuccess, "Send failed");*/

        //3. call. Recommended way. Lower level command..
        //in te quotes, we could call a function. But here we do not want to
        //instead, we want to use this as a transaction.
        //call func returns 2 vars, but we care only about the first, so on the LHS:
        (bool callSuccess, ) = payable(msg.sender).call{
            value: address(this).balance
        }("");
        require(callSuccess, "Call failed");
    }

    function getVersion() public view returns (uint256) {
        /*AggregatorV3Interface priceFeed = AggregatorV3Interface(
            //this is the address for the Sepolia ETH-USD chainlink price feed contract
            0x694AA1769357215DE4FAC081bf1f309aDC325306
        );
        return priceFeed.version();*/ //this was used before refactoring
        return s_priceFeed.version();
    }

    modifier onlyOwner() {
        // require(msg.sender == i_owner, "Not the owner!"); //this is the old way of doing it, but strings cost a loto gas
        if (msg.sender != i_owner) {
            revert FundMe__NotOwner();
        }
        //_; signifies the rest of the code, so the rest of the code will be executed after the line above
        _;
    }

    //What happens if someone sends money to this contract without using the fund function?
    //we can automatically revert them to our fund() function using the special functions receive and fallback
    receive() external payable {
        fund();
    }

    fallback() external payable {
        fund();
    }

    /*
    view / pure functions (getters)
    */

    function getAddressToAmountFunded(
        address fundingAddress
    ) external view returns (uint256) {
        return s_addresstoAmountFunded[fundingAddress];
    }

    function getFunder(uint256 index) external view returns (address) {
        return s_funders[index];
    }

    function getOwner() external view returns (address) {
        return i_owner;
    }
}
