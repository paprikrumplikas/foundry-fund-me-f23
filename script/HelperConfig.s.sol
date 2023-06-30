// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

//Purpose:
//1. Deploy mock when we are on a local anvil chain
//2. Keep track of contract addresses accss of different chains
//Sepolia ETH/USD
//Mainnet ETH/USD

import {Script} from "forge-std/Script.sol";
import {MockV3Aggregator} from "../test/mocks/Mockv3Aggregator.sol";

contract HelperConfig is
    Script /*needs to be a Script so we can use the vm keyword down below*/
{
    //if we are on a local anvil, we deploy mocks
    //otherwise, grab the existing address from the live network

    struct NetworkConfig {
        //new type, useful if we want more things than priceffed address, like gas, etc
        address priceFeed;
    }

    NetworkConfig public activeNetworkConfig;

    uint8 public constant DECIMALS = 8; //this is used instead of "magic numbers" in a function the purpose of which we would forget. So better define it as a const var
    int public constant INITIAL_ANSWER = 2000e8;

    constructor() {
        //chainid will come from the fork url: forge test --fork-url $MAINNET_RPC_URL
        if (block.chainid == 11155111) {
            //chain ID of Sepolia
            activeNetworkConfig = getSepoliaEthConfig();
        } else if (block.chainid == 1) {
            //chain ID of Mainnet
            activeNetworkConfig = getMainnetConfig();
        } else {
            activeNetworkConfig = getOrCreateAnvilEthConfig();
        }
    }

    function getSepoliaEthConfig() public pure returns (NetworkConfig memory) {
        //price feed address
        //vrl address
        //gas price
        NetworkConfig memory sepoliaConfig = NetworkConfig({
            priceFeed: 0x694AA1769357215DE4FAC081bf1f309aDC325306
        });
        return sepoliaConfig;
    }

    function getMainnetConfig() public pure returns (NetworkConfig memory) {
        NetworkConfig memory mainnetConfig = NetworkConfig({
            priceFeed: 0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419
        });
        return mainnetConfig;
    }

    function getOrCreateAnvilEthConfig() public returns (NetworkConfig memory) {
        if (activeNetworkConfig.priceFeed != address(0)) {
            return activeNetworkConfig;
        } //reason we need this if statement: without this, we would deploy a new mock contract every time we run the script, which would be a waste of gas

        //price feed address. Things to do:
        //1. deploy the mocks. With this mock we will be able to run the script locally on Anvil, without specifying an RPC_URL.
        //Without a mock there would be pricefeed address (chainlink is not monitoring our local nw), and the script would fail.
        //2. return the mock address

        vm.startBroadcast(); //this way we can deploy the mock contracts to the anvil chain we are working with
        MockV3Aggregator mockPriceFeed = new MockV3Aggregator(
            DECIMALS,
            INITIAL_ANSWER
        ); //the constuctor of this takes the number of decimals and an itial answer
        vm.stopBroadcast();

        NetworkConfig memory anvilConfig = NetworkConfig({
            priceFeed: address(mockPriceFeed)
        });

        return anvilConfig;
    }
}
