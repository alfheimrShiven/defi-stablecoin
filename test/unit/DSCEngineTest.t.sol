// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {Test} from "forge-std/Test.sol";
import {DecentralizedStableCoin} from "../../src/DecentralizedStableCoin.sol";
import {DSCEngine} from "../../src/DSCEngine.sol";
import {DeployDSC} from "../../script/DeployDSC.s.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/ERC20Mock.sol";

contract DSCEngineTest is Test {
    //////////////////////////////////////////////////////
    /// State variables (Stored in storage by default) ///
    //////////////////////////////////////////////////////
    DecentralizedStableCoin public dsc = new DecentralizedStableCoin();
    DSCEngine public dscEngine;
    HelperConfig public config;
    address public weth;
    address public wbtc;
    address public wethUsdPriceFeed;
    address public USER = makeAddr("user");
    uint256 public constant COLLATERAL_AMOUNT = 10 ether;
    uint256 public constant STARTING_USER_BALANCE = 100 ether;
    address[] public tokenAddresses;
    address[] public tokenPriceFeedAddresses;

    function setUp() external {
        DeployDSC deployer = new DeployDSC();
        (dsc, dscEngine, config) = deployer.run();
        (wethUsdPriceFeed, , weth, wbtc, ) = config.activeNetworkConfig();
        vm.deal(USER, STARTING_USER_BALANCE);
        ERC20Mock(weth).mint(USER, STARTING_USER_BALANCE);
    }

    //////////////////
    /// Events ///
    /////////////////
    event CollateralDeposited(
        address indexed user,
        address indexed tokenAddress,
        uint256 indexed amountCollateral
    );

    //////////////////
    /// Modifiers ///
    /////////////////

    modifier depositedCollateral() {
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(dscEngine), COLLATERAL_AMOUNT);
        dscEngine.depositCollateral(weth, COLLATERAL_AMOUNT);
        vm.stopPrank();
        _;
    }

    /////////////////////////
    /// Constructor Test ///
    ////////////////////////

    function testRevertsIfTokenAndPriceFeedArraysLengthsDontMatch() public {
        tokenAddresses.push(weth);
        tokenAddresses.push(wbtc);
        tokenPriceFeedAddresses.push(wethUsdPriceFeed);

        vm.expectRevert(
            DSCEngine
                .DSCEngine__TokenAddressesAndPriceFeedAddressesLengthDontMatch
                .selector
        );

        new DSCEngine(tokenAddresses, tokenPriceFeedAddresses, address(dsc));
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

    function testGetTokenAmountFromUsd() public {
        uint256 usdAmount = 100 ether; // 100e18 cuz expected value is also mentioned in ether and not decimals
        // $2000/Ether, $100 = 100/2000 = 0.05 ether
        uint256 expectedAmt = 0.05 ether;
        uint256 actualAmt = dscEngine.getTokenAmountFromUsd(weth, usdAmount);
        assertEq(expectedAmt, actualAmt);
    }

    ///////////////////////////////
    /// Deposit Collateral Test ///
    ///////////////////////////////

    function testRevertsIfCollateralZero() public {
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(dscEngine), COLLATERAL_AMOUNT);

        vm.expectRevert(DSCEngine.DSCEngine__NeedsMoreThanZero.selector);
        dscEngine.depositCollateral(weth, 0);
        vm.stopPrank();
    }

    function testRevertIfUnapprovedCollateralTokenDeposited() public {
        ERC20Mock jioToken = new ERC20Mock();
        vm.startPrank(USER);
        vm.expectRevert(
            abi.encodeWithSelector(
                DSCEngine.DSCEngine__TokenNotAllowed.selector,
                address(jioToken)
            )
        );

        dscEngine.depositCollateral(address(jioToken), COLLATERAL_AMOUNT);
        vm.stopPrank();
    }

    function testDepositCollateralAndGetAccountInfo()
        public
        depositedCollateral
    {
        (uint256 dscMinted, uint256 collateralDepositedInUSD) = dscEngine
            .getAccountInformation(USER);
        uint256 expectedDscMinted = 0;
        uint256 expectedCollateralDeposited = dscEngine.getTokenAmountFromUsd(
            weth,
            collateralDepositedInUSD
        );
        assertEq(dscMinted, expectedDscMinted);
        assertEq(expectedCollateralDeposited, COLLATERAL_AMOUNT);
    }

    function testIfTransferSucceeded() public depositedCollateral {
        uint256 collateralDeposited = ERC20Mock(weth).balanceOf(
            address(dscEngine)
        );
        uint256 expectedCollateralDeposit = COLLATERAL_AMOUNT;
        assertEq(collateralDeposited, expectedCollateralDeposit);
    }

    function testIfCollateralDepositedEventIsEmitted() public {
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(dscEngine), COLLATERAL_AMOUNT);

        vm.expectEmit(true, true, true, false, address(dscEngine));
        // we emit the event we expect to see
        emit CollateralDeposited(USER, weth, COLLATERAL_AMOUNT);
        //We perform the call that will trigger the actual event
        dscEngine.depositCollateral(weth, COLLATERAL_AMOUNT);
        vm.stopPrank();
    }
}
