// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {Test} from "forge-std/Test.sol";
import {DSCEngine} from "../../src/DSCEngine.sol";
import {DeployDSC} from "../../script/DeployDSC.s.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";

contract DSCEngineTest is Test {
    DSCEngine dscEngine;
    HelperConfig config;
    address weth;
    address USER = makeAddr("user");

    function setUp() external {
        DeployDSC deployer = new DeployDSC();
        (, dscEngine, config) = deployer.run();
        (, , weth, , ) = config.activeNetworkConfig();
    }

    //////////////////
    /// Price Test ///
    //////////////////

    function testGetUSDValue() external view {
        uint256 amount = 15e18;
        // 15e18 * 2000 USD/ETH (2000 comes from what we fed into MockV3Aggregator contract. Check file: HelperConfig.s.sol) = 30,000e18
        uint256 expectedUSD = 30000e18;
        uint256 actualUSD = dscEngine.getUsdValue(weth, amount);

        assert(expectedUSD == actualUSD);
    }

    ///////////////////////////////
    /// Deposit Collateral Test ///
    ///////////////////////////////

    function testRevertsIfCollateralZero() public {
        vm.startPrank(USER);
        // ERC20Mock(weth).approve(address(dsce), amountCollateral);

        vm.expectRevert(DSCEngine.DSCEngine__NeedsMoreThanZero.selector);
        dscEngine.depositCollateral(weth, 0);
        vm.stopPrank();
    }
}
