// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {Script} from "forge-std/Script.sol";
import {MockV3Aggregator} from "../test/mocks/MockV3Aggregator.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/ERC20Mock.sol";

contract HelperConfig is Script {
    uint8 public constant DECIMALS = 8;
    int256 public constant ETH_USD_PRICE = 2000e8;
    int256 public constant BTC_USD_PRICE = 1000e8;

    struct NetworkConfig {
        address wethUsdPriceFeed;
        address wbtcUsdPriceFeed;
        address weth;
        address wbtc;
        uint256 deployerKey;
    }

    NetworkConfig public activeNetworkConfig;

    constructor() {
        if (block.chainid == 11155111) {
            activeNetworkConfig = getSepoliaEthConfig();
        } else {
            activeNetworkConfig = getOrCreateAnvilEthConfig();
        }
    }

    function getSepoliaEthConfig() public view returns (NetworkConfig memory) {
        NetworkConfig memory sepoliaNetworkConfig = NetworkConfig({
            wethUsdPriceFeed: 0x694AA1769357215DE4FAC081bf1f309aDC325306, // ETH / USD
            wbtcUsdPriceFeed: 0x1b44F3514812d835EB1BDB0acB33d3fA3351Ee43,
            weth: 0xdd13E55209Fd76AfE204dBda4007C227904f0a81,
            wbtc: 0x8f3Cf7ad23Cd3CaDbD9735AFf958023239c6A063,
            deployerKey: vm.envUint("SEPOLIA_PRIVATE_KEY")
        });
        return sepoliaNetworkConfig;
    }

    function getOrCreateAnvilEthConfig() public returns (NetworkConfig memory) {
        vm.startBroadcast();
        // deploying Mock ETH / USD price feed contract
        MockV3Aggregator ethUsdPriceFeedMock = new MockV3Aggregator(
            DECIMALS,
            ETH_USD_PRICE
        );
        // deploying Mock BTC / USD price feed contract
        MockV3Aggregator btcUsdPriceFeedMock = new MockV3Aggregator(
            DECIMALS,
            BTC_USD_PRICE
        );
        // Creating a Mock wETH token
        ERC20Mock wEthMock = new ERC20Mock();
        // Creating a Mock wBTC token
        ERC20Mock wBtcMock = new ERC20Mock();
        vm.stopBroadcast();

        NetworkConfig memory anvilNetworkConfig = NetworkConfig({
            wethUsdPriceFeed: address(ethUsdPriceFeedMock),
            wbtcUsdPriceFeed: address(btcUsdPriceFeedMock),
            weth: address(wEthMock),
            wbtc: address(wBtcMock),
            deployerKey: vm.envUint("ANVIL_PRIVATE_KEY")
        });
        return anvilNetworkConfig;
    }
}
