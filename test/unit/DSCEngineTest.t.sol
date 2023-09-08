// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {Test} from "forge-std/Test.sol";
import {DecentralizedStableCoin} from "../../src/DecentralizedStableCoin.sol";
import {DSCEngine} from "../../src/DSCEngine.sol";
import {DeployDSC} from "../../script/DeployDSC.s.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/ERC20Mock.sol";
import {MockFailedTransferFrom} from "../mocks/MockFailedTransferFrom.sol";
import {MockFailedMintDSC} from "../mocks/MockFailedMintDSC.sol";
import {MockFailedTransfer} from "../mocks/MockFailedTransfer.sol";
import {MockV3Aggregator} from "../mocks/MockV3Aggregator.sol";

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
    uint256 mintAmount = 100 ether;
    uint256 collateralToRedeem = 2 ether;
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

    /* @devs this test requires its own setup as the token deposited * as collateral should cause the failure, for which we'll be  *    using a MockFailedTransferFrom token.
     */
    function testRevertIfTransferFailed() public {
        // Arrange - SETUP
        address owner = msg.sender;
        vm.prank(owner);
        MockFailedTransferFrom mockDsc = new MockFailedTransferFrom();
        mockDsc.mint(USER, COLLATERAL_AMOUNT); // will be used to transfer as collateral to the protocol

        tokenAddresses = [address(mockDsc)]; // approving the mockDSC token as a valid collateral token
        tokenPriceFeedAddresses = [wethUsdPriceFeed];
        vm.prank(owner);
        DSCEngine mockDscEngine = new DSCEngine(
            tokenAddresses,
            tokenPriceFeedAddresses,
            address(mockDsc)
        );

        vm.prank(owner);
        mockDsc.transferOwnership(address(mockDscEngine));

        // Arrange - For transfer. USER will come into picture and deposit collateral
        vm.startPrank(USER);
        ERC20Mock(address(mockDsc)).approve(
            address(mockDscEngine),
            COLLATERAL_AMOUNT
        );

        // Act / Assert
        vm.expectRevert(DSCEngine.DSCEngine__TransferFailed.selector);
        mockDscEngine.depositCollateral(address(mockDsc), COLLATERAL_AMOUNT);
        vm.stopPrank();
    }

    /////////////////////
    /// mintDsc() Test ///
    //////////////////////

    // This test will require it's own setup
    function testRevertIfMintingFails() public {
        // Arrange - SETUP
        address owner = msg.sender;
        vm.startPrank(owner);
        MockFailedMintDSC mockDsc = new MockFailedMintDSC();
        tokenAddresses = [weth];
        tokenPriceFeedAddresses = [wethUsdPriceFeed];

        DSCEngine mockDscEngine = new DSCEngine(
            tokenAddresses,
            tokenPriceFeedAddresses,
            address(mockDsc)
        );
        mockDsc.transferOwnership(address(mockDscEngine));
        vm.stopPrank();

        // Arrange - USER
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(mockDscEngine), COLLATERAL_AMOUNT);

        // Act / Revert
        vm.expectRevert(DSCEngine.DSCEngine__MintFailed.selector);
        mockDscEngine.depositCollateralAndMintDSC(
            weth,
            COLLATERAL_AMOUNT,
            mintAmount
        );
        vm.stopPrank();
    }

    function testRevertIfMintDscAmountIsZero() public {
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(dscEngine), COLLATERAL_AMOUNT);
        vm.expectRevert(DSCEngine.DSCEngine__NeedsMoreThanZero.selector);
        dscEngine.mintDSC(0);
        vm.stopPrank();
    }

    function testRevertIfMintingAmountBreaksHealthFactor()
        public
        depositedCollateral
    {
        // Arrange
        // Mint the same amount of DSC as deposited as collateral
        (, int256 price, , , ) = MockV3Aggregator(wethUsdPriceFeed)
            .latestRoundData();

        mintAmount =
            (COLLATERAL_AMOUNT *
                (uint256(price) * dscEngine.getAdditionalFeedPrecision())) /
            dscEngine.getPrecision();

        vm.startPrank(USER);
        uint256 expectedHealthFactor = dscEngine.calculateHealthFactor(
            mintAmount,
            dscEngine.getUsdValue(weth, COLLATERAL_AMOUNT)
        );

        vm.expectRevert(
            abi.encodeWithSelector(
                DSCEngine.DSCEngine__BreaksHealthFactor.selector,
                expectedHealthFactor
            )
        );
        dscEngine.mintDSC(mintAmount);
        vm.stopPrank();
    }

    function testDscMinted() public depositedCollateral {
        vm.prank(USER);
        dscEngine.mintDSC(mintAmount);

        uint256 userDscBalance = dsc.balanceOf(USER);
        assertEq(userDscBalance, mintAmount);
    }

    ////////////////////////////////
    /// redeemCollateral() tests ///
    ////////////////////////////////

    function testRevertIfRedeemCollateralAmtIsZero() public {
        vm.startPrank(USER);
        vm.expectRevert(DSCEngine.DSCEngine__NeedsMoreThanZero.selector);
        dscEngine.redeemCollateral(weth, 0);
        vm.stopPrank();
    }

    function testRevertIfHealthCheckIsBrokenOnRedeemtion()
        public
        depositedCollateral
    {
        vm.startPrank(USER);
        // mint dsc
        dscEngine.mintDSC(mintAmount);

        // try to redeem all the collateral
        uint256 healthFactorOnFullCollateralRedeemtion = dscEngine
            .calculateHealthFactor(mintAmount, 0);

        vm.expectRevert(
            abi.encodeWithSelector(
                DSCEngine.DSCEngine__BreaksHealthFactor.selector,
                healthFactorOnFullCollateralRedeemtion
            )
        );
        dscEngine.redeemCollateral(weth, COLLATERAL_AMOUNT);
        vm.stopPrank();
    }

    function testRedeemCollateral() public depositedCollateral {
        // Arrange
        vm.startPrank(USER);
        dscEngine.mintDSC(mintAmount);

        // Deposited Collateral: 100 ETH = 100 * $2000/ETH = $200,000
        // Minted DSC worth: $100
        // Attempt to redeem collateral (collateralToRedeem): $200 / 2000 = 0.1 ETH = 0.1e

        // ACT
        dscEngine.redeemCollateral(weth, collateralToRedeem);
        uint256 usersBalanceAfterCollateralDepositAndRedeemtion = STARTING_USER_BALANCE -
                COLLATERAL_AMOUNT +
                collateralToRedeem;

        assertEq(
            ERC20Mock(weth).balanceOf(USER),
            usersBalanceAfterCollateralDepositAndRedeemtion
        );
        vm.stopPrank();
    }

    function testRevertIfRedeemCollateralTransferFailed() public {
        // Arrange - Setup
        address owner = msg.sender;
        vm.startPrank(owner);
        MockFailedTransfer mdsc = new MockFailedTransfer();
        tokenAddresses = [address(mdsc)];
        tokenPriceFeedAddresses = [wethUsdPriceFeed];

        DSCEngine mDSCEngine = new DSCEngine(
            tokenAddresses,
            tokenPriceFeedAddresses,
            address(mdsc)
        );
        mdsc.mint(USER, STARTING_USER_BALANCE);
        mdsc.transferOwnership(address(mDSCEngine));
        vm.stopPrank();

        // Arrange- USER
        vm.startPrank(USER);
        MockFailedTransfer(mdsc).approve(
            address(mDSCEngine),
            COLLATERAL_AMOUNT
        );

        mDSCEngine.depositCollateral(address(mdsc), COLLATERAL_AMOUNT);

        // ACT / Assert
        vm.expectRevert(DSCEngine.DSCEngine__TransferFailed.selector);
        mDSCEngine.redeemCollateral(address(mdsc), collateralToRedeem);
        vm.stopPrank();
    }
}
