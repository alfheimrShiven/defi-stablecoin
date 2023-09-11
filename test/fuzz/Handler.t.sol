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
        collateralAmount = bound(collateralAmount, 1, MAX_DEPOSIT_SIZE); // restricting collateral amount to be more than zero

        // minting collateral tokens
        vm.startPrank(msg.sender);
        ERC20Mock(collateralToken).mint(msg.sender, collateralAmount);

        // giving approve to dscEngine to deposit tokens as collateral
        ERC20Mock(collateralToken).approve(
            address(dscEngine),
            collateralAmount
        );

        dscEngine.depositCollateral(collateralToken, collateralAmount);
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
