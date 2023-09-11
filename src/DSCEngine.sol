// SPDX-License-Identifier: MIT

// Layout of Contract:
// version
// imports
// errors
// interfaces, libraries, contracts
// Type declarations
// State variables
// Events
// Modifiers
// Functions

// Layout of Functions:
// constructor
// receive function (if exists)
// fallback function (if exists)
// external
// public
// internal
// private
// view & pure functions

pragma solidity ^0.8.18;

/*
 * @title DSCEngine
 * @author Shivendra Singh
 *
 * The system is designed to be as minimal as possible, and have the tokens maintain a 1 token == $1 peg at all times.
 * This is a stablecoin with the properties:
 * - Exogenously Collateralized
 * - Dollar Pegged
 * - Algorithmically Stable
 *
 * It is similar to DAI if DAI had no governance, no fees, and was backed by only WETH and WBTC.
 *
 * Our DSC should always be "overcollateratised". At no point, our DSC >= collateral.

 * @notice This contract is the core of the Decentralized Stablecoin system. It handles all the logic
 * for minting and redeeming DSC, as well as depositing and withdrawing collateral.
 * @notice This contract is based on the MakerDAO DSS system
 */

import {DecentralizedStableCoin} from "./DecentralizedStableCoin.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

contract DSCEngine is ReentrancyGuard {
    //////////////////////
    ////// ERRORS ////////
    /////////////////////
    error DSCEngine__NeedsMoreThanZero();
    error DSCEngine__TokenAddressesAndPriceFeedAddressesLengthDontMatch();
    error DSCEngine__TokenNotAllowed(address token);
    error DSCEngine__TransferFailed();
    error DSCEngine__BreaksHealthFactor(uint256 userHealthFactor);
    error DSCEngine__MintFailed();
    error DSCEngine__NotEnoughDSCToBurn(address user, uint256 amountToBurn);
    error DSCEngine__HealthFactorOk(address user);
    error DSCEngine__HealthFactorNotImproved(address user);
    ///////////////////
    // State Variables
    ///////////////////
    DecentralizedStableCoin private immutable i_dsc;
    mapping(address collateralToken => address priceFeed) private s_priceFeeds;
    mapping(address user => mapping(address token => uint256 amount))
        private s_collateralDeposited;
    mapping(address user => uint256 dscMinted) private s_DSCMinted;
    uint256 public constant MIN_HEALTH_FACTOR = 1e18;
    uint256 public constant ADDITIONAL_FEED_PRECISION = 1e10;
    uint256 public constant PRECISION = 1e18;
    uint256 public constant LIQUIDATION_THRESHOLD = 50;
    uint256 public constant LIQUIDATION_BONUS = 10;
    address[] private s_collateralTokens;

    ///////////////////
    //// Events //////
    ///////////////////

    event CollateralDeposited(
        address indexed user,
        address indexed token,
        uint256 indexed amount
    );

    event CollateralRedeemed(
        address indexed redeemedFrom,
        address indexed redeemedTo,
        address collateralToken,
        uint256 redeemedAmount
    );

    event DSCBurnt(address indexed user, uint256 indexed dscBurnt);

    //////////////////////
    //// MODIFIERS //////
    /////////////////////
    modifier moreThanZero(uint256 amount) {
        if (amount <= 0) {
            revert DSCEngine__NeedsMoreThanZero();
        }
        _;
    }

    modifier isAllowedToken(address token) {
        if (s_priceFeeds[token] == address(0)) {
            revert DSCEngine__TokenNotAllowed(token);
        }
        _;
    }

    ///////////////////////////
    /// External Functions ///
    //////////////////////////

    constructor(
        address[] memory tokenAddresses,
        address[] memory priceFeedAddresses,
        address dscAddress
    ) {
        if (tokenAddresses.length != priceFeedAddresses.length) {
            revert DSCEngine__TokenAddressesAndPriceFeedAddressesLengthDontMatch();
        }

        for (uint256 i = 0; i < tokenAddresses.length; i++) {
            s_priceFeeds[tokenAddresses[i]] = priceFeedAddresses[i];
            s_collateralTokens.push(tokenAddresses[i]);
        }

        i_dsc = DecentralizedStableCoin(dscAddress);
    }

    /*
     * @param tokenCollateralAddress: The ERC20 token address of the collateral you're depositing
     * @param amountCollateral: The amount of collateral you're depositing
     * @param amountDscToMint: The amount of DSC you want to mint
     * @notice This function will deposit your collateral and mint DSC in one transaction
     */

    function depositCollateralAndMintDSC(
        address tokenCollateralAddress,
        uint256 amountCollateral,
        uint256 amountDscToMint
    ) external {
        depositCollateral(tokenCollateralAddress, amountCollateral);
        mintDSC(amountDscToMint);
    }

    /*
     * @param amountDscToBurn The amount of decentralised stablecoin to burn
     * @param amountCollateralToRedeem The amount of collateral to redeem
     * @param collateralToken The type of token to redeem
     * This function burns DSC and redeems collateral in a single transaction
     */
    function redeemCollateralForDSC(
        uint256 amountDscToBurn,
        uint256 amountCollateralToRedeem,
        address collateralToken
    ) external {
        burnDSC(amountDscToBurn);
        redeemCollateral(collateralToken, amountCollateralToRedeem);
    }

    function depositCollateral(
        address tokenCollateralAddress,
        uint256 amountCollateral
    )
        public
        moreThanZero(amountCollateral)
        isAllowedToken(tokenCollateralAddress)
        nonReentrant
    {
        // update mapping for internal record keeping
        s_collateralDeposited[msg.sender][
            tokenCollateralAddress
        ] += amountCollateral;

        // emit event
        emit CollateralDeposited(
            msg.sender,
            tokenCollateralAddress,
            amountCollateral
        );

        // make the transfer
        bool success = IERC20(tokenCollateralAddress).transferFrom(
            msg.sender,
            address(this),
            amountCollateral
        );
        if (!success) {
            revert DSCEngine__TransferFailed();
        }
    }

    /*
     * In order to redeem collateral, the user's health factor should be 1 or more, AFTER collateral pulled, otherwise it will revert.
     * CEI: Check, Effect, Interactions
     */
    function redeemCollateral(
        address collateralToken,
        uint256 collateralAmount
    ) public moreThanZero(collateralAmount) nonReentrant {
        _redeemCollateral(
            collateralToken,
            collateralAmount,
            msg.sender,
            msg.sender
        );
        _revertIfHealthCheckIsBroken(msg.sender);
    }

    function mintDSC(
        uint256 amountDscToMint
    ) public moreThanZero(amountDscToMint) {
        s_DSCMinted[msg.sender] += amountDscToMint;

        // Check if Collateral value is more than DSC value
        /*
         * Function call chain:
         * mintDSC(amountDscToMint)
         * revertIfHealthCheckIsBroken(msg.sender)
         * _healthFactor(user)
         * getAccountCollateralValueInUsd(user)
         * getUsdValue(address token, uint256 amount)
         */
        _revertIfHealthCheckIsBroken(msg.sender);

        // its time to mint now!
        bool minted = i_dsc.mint(msg.sender, amountDscToMint);
        if (!minted) {
            revert DSCEngine__MintFailed();
        }
    }

    function burnDSC(uint256 amountToBurn) public moreThanZero(amountToBurn) {
        _burnDSC(amountToBurn, msg.sender);
    }

    /*
     * @param collateralToken The token the liquidator wants to avail by liquidating from the bad user
     * @param user The bad user who failed to maintain their Health Factor.
     * Eg:
     * Asset borrowed: $100DSC
     * Collateral requirement (200%): $200 ETH
     * Current collateral value: $150 ETH
     * @debtToCover The amount of debt the liquidator wants to burn in order to improve the bad user's health factor.
     * The liquidator will be allowed to cover partial debt of the bad user.
     * The liquidator will earn a 10% collateral bonus as an incentive for covering the bad user's debt.
     * The protocol will benefit from the balance of the collateral that is bad user had depositted with the protocol while borrowing DSC. This balance collateral will continue to keep the protocol over-collateralised.
     */
    function liquidate(
        address collateralToken,
        address user,
        uint256 debtToCover
    ) external {
        uint256 startingHealthFactor = _healthFactor(user);

        if (startingHealthFactor >= MIN_HEALTH_FACTOR) {
            revert DSCEngine__HealthFactorOk(user);
        }

        // Convert the debtToCover amount (USDs) into collateral token amount (wEth/ wBtc)
        uint256 tokenAmountFromDebtCovered = getTokenAmountFromUsd(
            collateralToken,
            debtToCover
        );

        // Add collateralBonus of 10%
        uint256 totalRedeemableCollateral = tokenAmountFromDebtCovered +
            ((tokenAmountFromDebtCovered * LIQUIDATION_BONUS) / 100);

        // redeem collateral (by liquidator)
        _redeemCollateral(
            collateralToken,
            totalRedeemableCollateral,
            user,
            msg.sender
        );

        /* burning DSC will reduce the DSCs in circulation, hence the collateral requirement value will also reduce. 
        
        * Example:
        * Borrowed DSC = $100
        * Collateral Deposited (200% of the borrowed amt) = $200 ( $200/(ETH Value is 2000$) = 0.1 ETH tokens)
        * Collateral value drops to: $150
        * Liquidator comes into picture. Offers to settle the whole $100 debt (debtToCover = $100 DSC)
        * He gets back collateral worth $100 DSC + collateral bonus. 
        * totalRedeemableCollateral = 0.05 + 0.005 = 0.055 ETH
        * Collateral left with protocol = Collateral Deposited - totalRedeemableCollateral = 0.1 ETH - 0.05ETH = 0.045 ETH
        * At the end, the borrower is thrown out of the protocol as his collateral is dissolved to the liquidator and the protocol itself and his assets (DSC) are burnt.
        */
        _burnDSC(debtToCover, user);

        uint256 endingHealthFactor = _healthFactor(user);
        if (endingHealthFactor <= startingHealthFactor) {
            revert DSCEngine__HealthFactorNotImproved(user);
        }

        _revertIfHealthCheckIsBroken(msg.sender);
    }

    //////////////////////////
    /// Public Functions  ////
    //////////////////////////

    /*
    @param amountToMint The amount of DSC you plan to mint
    @param collateralToDeposit The amount of Collateral you plan to deposit
    This function returns the stimulated health factor with various collateral & minting values sent as params.
    */
    function calculateHealthFactor(
        uint256 mintedAmount,
        uint256 collateralDepositInUsd
    ) public pure returns (uint256) {
        if (mintedAmount == 0) {
            return type(uint256).max;
        }

        uint256 dscMintingThreshold = (collateralDepositInUsd *
            LIQUIDATION_THRESHOLD) / 100;

        return ((dscMintingThreshold * PRECISION) / mintedAmount);
    }

    function getUserHealthFactor(
        address user
    ) public view returns (uint256 userHealthFactor) {
        userHealthFactor = _healthFactor(user);
    }

    function getTokenAmountFromUsd(
        address collateralToken,
        uint256 debtToCover
    ) public view returns (uint256) {
        // get USD value of the token
        AggregatorV3Interface priceFeed = AggregatorV3Interface(
            s_priceFeeds[collateralToken]
        );
        (, int256 price, , , ) = priceFeed.latestRoundData();

        // debtToCover / USD value per token
        return ((debtToCover * PRECISION) /
            (uint256(price) * ADDITIONAL_FEED_PRECISION));
    }

    function getUsdValue(
        address token,
        uint256 amount
    ) public view returns (uint256) {
        AggregatorV3Interface tokenPriceFeed = AggregatorV3Interface(
            s_priceFeeds[token]
        );
        (, int256 price, , , ) = tokenPriceFeed.latestRoundData();
        return
            (amount * (uint256(price) * ADDITIONAL_FEED_PRECISION)) / PRECISION;
    }

    function getAccountInformation(
        address user
    )
        public
        view
        returns (uint256 dscMinted, uint256 collateralDepositedValue)
    {
        (dscMinted, collateralDepositedValue) = _getAccountInformation(user);

        return (dscMinted, collateralDepositedValue);
    }

    function getAccountCollateralValueInUsd(
        address user
    ) public view returns (uint256) {
        address token;
        uint256 amountOfTokenDeposited;
        uint256 totalCollateralValueInUsd;
        for (uint256 i = 0; i < s_collateralTokens.length; i++) {
            token = s_collateralTokens[i];
            amountOfTokenDeposited = s_collateralDeposited[user][token];

            totalCollateralValueInUsd += getUsdValue(
                token,
                amountOfTokenDeposited
            );
        }
        return totalCollateralValueInUsd;
    }

    //////////////////////////
    /// Internal Functions ///
    //////////////////////////

    function _burnDSC(uint256 amountToBurn, address user) private {
        if (s_DSCMinted[user] < amountToBurn) {
            revert DSCEngine__NotEnoughDSCToBurn(user, amountToBurn);
        }
        s_DSCMinted[user] -= amountToBurn;

        bool success = i_dsc.transferFrom(user, address(this), amountToBurn);
        if (!success) {
            revert DSCEngine__TransferFailed();
        }
        i_dsc.burn(amountToBurn);
        emit DSCBurnt(user, amountToBurn);
    }

    function _redeemCollateral(
        address collateralToken,
        uint256 collateralAmount,
        address from,
        address to
    ) internal {
        s_collateralDeposited[from][collateralToken] -= collateralAmount;
        emit CollateralRedeemed(from, to, collateralToken, collateralAmount);
        bool success = IERC20(collateralToken).transfer(to, collateralAmount);

        if (!success) {
            revert DSCEngine__TransferFailed();
        }
    }

    function _revertIfHealthCheckIsBroken(address user) private view {
        uint256 userHealthFactor = _healthFactor(user);
        if (userHealthFactor < MIN_HEALTH_FACTOR) {
            revert DSCEngine__BreaksHealthFactor(userHealthFactor);
        }
    }

    function _healthFactor(address user) private view returns (uint256) {
        uint256 totalCollateralValueInUsd = getAccountCollateralValueInUsd(
            user
        );

        /*
         * @notice: The totalCollateralValueInUsd should always remain double of the amoutDscToMint
         * ie. every token holder should be 200% overcollateralised.
         */
        return
            calculateHealthFactor(s_DSCMinted[user], totalCollateralValueInUsd);
    }

    function _getAccountInformation(
        address user
    )
        private
        view
        returns (uint256 dscMinted, uint256 collateralDepositedValue)
    {
        dscMinted = s_DSCMinted[user];
        collateralDepositedValue = getAccountCollateralValueInUsd(user);
        return (dscMinted, collateralDepositedValue);
    }

    //////////////////////
    // GETTER FUNCTIONS //
    //////////////////////
    function getAdditionalFeedPrecision() public pure returns (uint256) {
        return ADDITIONAL_FEED_PRECISION;
    }

    function getPrecision() public pure returns (uint256) {
        return PRECISION;
    }
}
