/* Identified Invarients:
 * 1. The minted DSC should always be less than the collateral ed.
 * 2. Our view/pure functions should never revert
 */

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Test, console} from "forge-std/Test.sol";
import {StdInvariant} from "forge-std/StdInvariant.sol";
import {DecentralizedStableCoin} from "../../src/DecentralizedStableCoin.sol";
import {DSCEngine} from "../../src/DSCEngine.sol";
import {DeployDSC} from "../../script/DeployDSC.s.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/ERC20Mock.sol";
import {Handler} from "./Handler.t.sol";

contract InvariantsTest is StdInvariant, Test {
    DecentralizedStableCoin dsc;
    DSCEngine dscEngine;
    HelperConfig helperConfig;
    address wEth;
    address wBtc;
    Handler handler;

    function setUp() external {
        DeployDSC deployer = new DeployDSC();
        (dsc, dscEngine, helperConfig) = deployer.run();
        (, , wEth, wBtc, ) = helperConfig.activeNetworkConfig();

        handler = new Handler(dsc, dscEngine);
        targetContract(address(handler));
    }

    function invariant_protocolMustAlwaysHaveMoreCollateralValueThanMintedDSCValue()
        public
        view
    {
        uint256 totalDscSupply = dsc.totalSupply();
        uint256 ethBalance = ERC20Mock(wEth).balanceOf(address(dscEngine));
        uint256 btcBalance = ERC20Mock(wBtc).balanceOf(address(dscEngine));

        uint256 totalCollateralValue = dscEngine.getUsdValue(wEth, ethBalance) +
            dscEngine.getUsdValue(wBtc, btcBalance);

        console.log("Total DSC Supply: ", totalDscSupply);
        console.log("Total Collateral value: ", totalCollateralValue);
        console.log("Mint calls: ", handler.mintDscCalls());
        assert(totalDscSupply <= totalCollateralValue);
    }

    function invariant_gettersShouldNotRevert() public {
        dscEngine.getCollateralTokens();
        dscEngine.getPrecision();
        dscEngine.getPriceFeedAddresses();
        // dscEngine.getTokenAmountFromUsd();
        // dscEngine.getUsdValue();
    }
}
