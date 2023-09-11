// Will control the flow of functions
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;
import {Test} from "forge-std/Test.sol";
import {DecentralizedStableCoin} from "../../src/DecentralizedStableCoin.sol";
import {DSCEngine} from "../../src/DSCEngine.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/ERC20Mock.sol";

contract Handler is Test {
    DecentralizedStableCoin dsc;
    DSCEngine dscEngine;
    address wEth;
    address wBtc;
    uint256 MAX_DEPOSIT_SIZE = type(uint96).max; // uint96 because if we used uint256 max, then we would not be able to deposit more collateral for other tests as type(uint256).max + anything would then throw an error

    constructor(DecentralizedStableCoin _dsc, DSCEngine _dscEngine) {
        dsc = _dsc;
        dscEngine = _dscEngine;
        address[] memory collateralTokens = dscEngine.getCollateralTokens();
        wEth = collateralTokens[0];
        wBtc = collateralTokens[1];
    }

    function depositCollateral(
        uint256 collateralSeed,
        uint256 collateralAmount
    ) public {
        // Arrange
        address collateralToken = _getCollateralFromSeed(collateralSeed); // restricting collateral tokens to be one of the two allowed
        collateralAmount = bound(collateralAmount, 1, MAX_DEPOSIT_SIZE); // restricting collateralAmount to be more than zero

        // minting collateral tokens
        vm.startPrank(msg.sender);
        ERC20Mock(collateralToken).mint(msg.sender, collateralAmount);

        // giving approve to dscEngine to deposit tokens as collateral
        ERC20Mock(collateralToken).approve(
            address(dscEngine),
            collateralAmount
        );

        dscEngine.depositCollateral(collateralToken, collateralAmount);
        vm.stopPrank();
    }

    function mintDsc(uint256 mintAmount) public {
        // Arrange
        // mintAmount should not be 0 and should not be more than (half the collateral value deposited - dscMinted)
        (uint256 dscMinted, uint256 collateralDepositedValue) = dscEngine
            .getAccountInformation(msg.sender);

        int256 maxMintAmount = (int256(collateralDepositedValue) / 2) -
            int256(dscMinted);
        if (maxMintAmount < 0) {
            // this can happen if the collateral value drops after a token crash
            return;
        }

        mintAmount = bound(mintAmount, 0, uint256(maxMintAmount));
        if (mintAmount == 0) {
            // can be 0 if no collateral is deposited
            return;
        }

        vm.startPrank(msg.sender);
        dscEngine.mintDSC(mintAmount);
        vm.stopPrank();
    }

    function redeemCollateral(
        uint256 collateralSeed,
        uint256 redeemAmount
    ) public {
        // Arrange
        // choose the collateral token to redeem
        address collateralToken = _getCollateralFromSeed(collateralSeed);

        // redeemAmount should always be more than zero but less than the total collateral deposited

        uint256 maxRedeemableCollateral = dscEngine.getCollateralDeposited(
            collateralToken
        );

        redeemAmount = bound(redeemAmount, 0, maxRedeemableCollateral);
        if (redeemAmount == 0) {
            return;
        }

        // I feel while redeeming the collateral, we need to also consider the dsc minted along with the collateral deposited in order to keep the healthFactor > =1

        /**
        (uint256 dscMinted, uint256 collateralDepositedValue) = dscEngine
            .getAccountInformation(msg.sender);
        uint256 collateralValueThatCannotBeWithdrawn = dscMinted * 2;
        
        uint256 maxRedeemableCollateral = collateralDepositedValue -
            dscEngine.getTokenAmountFromUsd(
                collateralToken,
                collateralValueThatCannotBeWithdrawn
            );

        redeemAmount = bound(redeemAmount, 0, maxRedeemableCollateral); // maxRedeemableCollateral can be zero incase no collateral deposited, hence starting bound value has to be zero. Secondly, the redeemAmount can be more than the token chosen to be deposited.

        if (
            redeemAmount == 0 ||
            redeemAmount > dscEngine.getCollateralDeposited(collateralToken)
        ) {
            // to skip the test with redeemAmount = 0
            return;
        }
         */

        dscEngine.redeemCollateral(collateralToken, redeemAmount);
    }

    function _getCollateralFromSeed(
        uint256 collateralSeed
    ) public view returns (address) {
        if (collateralSeed % 2 == 0) {
            return wEth;
        } else {
            return wBtc;
        }
    }
}
