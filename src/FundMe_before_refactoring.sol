// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

//Funcionalities we want
//get funds from users
//withdraw funds
//set a mimimum funding value in USD

//importing our custom-made library
//libraries cannot have state vars and all funcs have to be internal
import {PriceConverter} from "./PriceConverter_before_refactoring.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

//this custom error saves a loto gas if we use it in an IF + REVERT statement instead of giving a string error message to a REQUIRE statement
//obs the naming converntion. Helps to identifiy which contract the error is coming from
error FundMe__NotOwner();

contract FundMe {
    //to attach the functions in our PriceConverter library to all uint256s:
    using PriceConverter for uint256;

    //if a var is set once outside a function and not changed later, it can be a constant. Saves gas!
    uint256 public constant MINIMUM_USD = 5e18; //e18 to account for the fact that our functions return values with 18 decimal places

    address[] public funders;
    mapping(address funder => uint256 AmountFunded)
        public addresstoAmountFunded;

    //if a var is set only once, but not on the same line it is declared (and then not changed), it can be set as immutable. Saves gas
    address public immutable i_owner;

    constructor() {
        //this is needed so that only the owner (deployer) of the contract can withdraw funds
        i_owner = msg.sender;
    }

    function fund() public payable {
        //if this require is not fulfilled, the transaction will be reverted.
        //Revert means that whatever happened in that transaction previously will be undone.
        //msg.value returns a value with 18 decimal places
        //After we created a lib and imported it, we can use the line below. The trick here is that msg.value is basically íthe input param
        require(
            msg.value.getConversionRate() >= MINIMUM_USD,
            "Didnt send enough ETH"
        ); // 1e18 = 1 ETH

        funders.push(msg.sender);
        //This tells us the amount the current sender funded us with.
        //it is equal to the funds he had sent earlier PLUS the funds he sent now
        addresstoAmountFunded[msg.sender] += msg.value;
    }

    function withdraw() public onlyOwner {
        require(msg.sender == i_owner, "Must be the owner");

        for (
            uint256 funderIndex = 0;
            funderIndex < funders.length;
            funderIndex++
        ) {
            address funder = funders[funderIndex];
            addresstoAmountFunded[funder] = 0;

            //reset the array
            funders = new address[](0);

            //withdraw funds. 3 ways

            //msg.sender IS an address. This has to be tpyecasted as follows
            //payable msg.sender IS a payable address

            //transfer. Easiest. Automatically reverts
            payable(msg.sender).transfer(address(this).balance);

            //send. If it is not successful, we would not get our money back unless we revert by adding thequire statement
            bool sendSuccess = payable(msg.sender).send(address(this).balance);
            require(sendSuccess, "Send failed");

            //call. Recommended way. Lower level command..
            //in te quotes, we could call a function. But here we do not want to
            //instead, we want to use this as a transaction.
            //call func returns 2 vars, but we care only about the first, so on the LHS:
            (bool callSuccess, ) = payable(msg.sender).call{
                value: address(this).balance
            }("");
            require(callSuccess, "Call failed");
        }
    }

    function getVersion() public view returns (uint256) {
        AggregatorV3Interface priceFeed = AggregatorV3Interface(
            //this is the address for the Sepolia ETH-USD chainlink price feed contract
            0x694AA1769357215DE4FAC081bf1f309aDC325306
        );
        return priceFeed.version();
    }

    modifier onlyOwner() {
        // require(msg.sender == i_owner, "Not the owner!");
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
}
