// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {Test, console} from "forge-std/Test.sol";
import {DeployDSC} from "../../script/DeployDSC.s.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {DecentralizedStableCoin} from "../../src/DecentralizedStableCoin.sol";
import {DSCEngine} from "../../src/DSCEngine.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/ERC20Mock.sol";
import {MockV3Aggregator} from "../mocks/MockV3Aggregator.sol";

contract DSCEngineInterationTest is Test {

    DecentralizedStableCoin dsc;
    DSCEngine dscEngine;
    HelperConfig helperConfig;
    address wEth;
    address wethUsdPriceFeed;
    address public user = makeAddr('user');
    uint256 public collateralAmount = 1 ether;
    uint256 public mintAmount = 1000 ether;
    int256 public newEthUsdValue = 100e8;
    uint256 public finalCollateralAmount = 2 ether;
    

    function setUp() public {
        DeployDSC deployer = new DeployDSC();
        (dsc, dscEngine, helperConfig) = deployer.run();
        (wethUsdPriceFeed,,wEth,,) = helperConfig.activeNetworkConfig();
    }

    /*
     * @title testIfUserAssetSafeGuarded
     * @author Shivendra Singh
     * @notice This test will check if the user is safeguarded incase of a fall in underlying asset price.
     * Eg:
     * Collateral Deposited: 1 ETH @ $2000
     * Minted DSC to safeguard his ETH: $2000/2 = $1000 = 1000 DSC
     * Current state: User Minted DSC = 1000 DSC, User collateral balance = 1 ETH @ $2000
     * 
     * !!!MARKET CRASHES!!! ETH (collateral) price drops drastically $2000 -> $100
     * Now since user minted value = collateral value after price drop, user decides to exit the protocol
     * Redeems all minted DSC for collateral (ETH) = 1000 DSC = $1000 DSC / $100 ETH = 10 ETH
     * He gets back totally 10 ETH @ $100/ETH, while he deposited 1ETH @ $2000/ETH. 
     * The beauty? Even after the ETH price dropped to $100, the user ends up getting 10 ETH holding total asset value of 10 ETH * $100 = $1000.
     * If he hadnt deposited in stablecoin, his current asset value would have been 1 ETH = $100
    */

    function testIfUserAssetSafeGuarded() external {
        vm.startPrank(user);

        // Arrange
        ERC20Mock(wEth).mint( user, collateralAmount);
        ERC20Mock(wEth).approve(address(dscEngine), collateralAmount);

        dscEngine.depositCollateralAndMintDSC(wEth, collateralAmount, mintAmount);
        dsc.approve(address(dscEngine), mintAmount);

        MockV3Aggregator ethUsdPriceFeed = MockV3Aggregator(wethUsdPriceFeed);
        ethUsdPriceFeed.updateAnswer(newEthUsdValue); // $2000 -> $100 
        // USER IS UNDER-COLLATERISED

        // ACT
        // redeeming all DSC as ETH
        // uint256 allMintedDSCValueAsEthTokensAfterCrash = dscEngine.getTokenAmountFromUsd(wEth, mintAmount); // $1000 DSC = $1000/$100 = 10 ETH @ $100/ETH
        // dscEngine.redeemCollateralForDSC(mintAmount, allMintedDSCValueAsEthTokensAfterCrash, wEth);
        // console.log('User balance after redeeming DSC:', ERC20Mock(wEth).balanceOf(user));
        
        // redeeming balance collateral if any
        // uint256 balCollateral = dscEngine.getCollateralDeposited(wEth);
        // if(balCollateral > 0) {
        //     dscEngine.redeemCollateral(wEth, balCollateral);
        // }
        // console.log('Final User balance:', ERC20Mock(wEth).balanceOf(user));

        dscEngine.redeemCollateralForDSC(mintAmount, collateralAmount, wEth);
        vm.stopPrank();

        // Assert
        assertEq(ERC20Mock(wEth).balanceOf(user), collateralAmount);
    }
}