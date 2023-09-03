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

    ///////////////////
    // State Variables
    ///////////////////
    DecentralizedStableCoin private immutable i_dsc;
    mapping(address collateralToken => address priceFeed) private s_priceFeeds;
    mapping(address user => mapping(address token => uint256 amount))
        private s_collateralDeposited;
    mapping(address user => uint256 dscMinted) private s_DSCMinted;
    uint256 public constant MIN_HEALTH_FACTOR = 1;
    uint256 public constant ADDITIONAL_FEED_PRECISION = 1e10;
    uint256 public constant PRECISION = 1e18;
    uint256 public constant LIQUIDATION_THRESHOLD = 50;
    address[] private s_collateralTokens;

    ///////////////////
    //// Events ////
    ///////////////////

    event CollateralDeposited(
        address indexed user,
        address indexed token,
        uint256 indexed amount
    );

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
            s_collateralTokens[i] = tokenAddresses[i];
        }

        i_dsc = DecentralizedStableCoin(dscAddress);
    }

    function depositCollateralAndMintDSC() external {}

    function redeemCollateralForDSC() external {}

    function depositCollateral(
        address tokenCollateralAddress,
        uint256 amountCollateral
    )
        external
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

    function redeemCollateral() external {}

    function mintDSC(
        uint256 amountDscToMint
    ) external moreThanZero(amountDscToMint) {
        s_DSCMinted[msg.sender] += amountDscToMint;

        // Check if Collateral value is more than DSC value
        /*
         * Function call chain:
         * mintDSC(amountDscToMint)
         * revertIfHealthCheckIsBroken(msg.sender)
         * _healthFactor(user)
         * getAccountCollateralValueInUsd(user)
         * _getUsdValue(address token, uint256 amount)
         */
        _revertIfHealthCheckIsBroken(msg.sender);

        // its time to mint now!
        bool minted = i_dsc.mint(msg.sender, amountDscToMint);
        if (!minted) {
            revert DSCEngine__MintFailed();
        }
    }

    function burnDSC() external {}

    function getHealthFactor() external view {}

    function liquidate() external {}

    //////////////////////////
    /// Public Functions  ////
    //////////////////////////
    function getAccountCollateralValueInUsd(
        address user
    ) public view returns (uint256) {
        address token;
        uint256 amountOfTokenDeposited;
        uint256 totalCollateralValueInUsd;
        for (uint256 i = 0; i < s_collateralTokens.length; i++) {
            token = s_collateralTokens[i];
            amountOfTokenDeposited = s_collateralDeposited[user][token];

            totalCollateralValueInUsd += _getUsdValue(
                token,
                amountOfTokenDeposited
            );
        }
        return totalCollateralValueInUsd;
    }

    //////////////////////////
    /// Internal Functions ///
    //////////////////////////
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
        uint256 dscMintingThreshold = (totalCollateralValueInUsd *
            LIQUIDATION_THRESHOLD) / 100;
        return (dscMintingThreshold / s_DSCMinted[user]);
    }

    function _getUsdValue(
        address token,
        uint256 amount
    ) private view returns (uint256) {
        AggregatorV3Interface tokenPriceFeed = AggregatorV3Interface(
            s_priceFeeds[token]
        );
        (, int256 price, , , ) = tokenPriceFeed.latestRoundData();
        return
            (amount * (uint256(price) * ADDITIONAL_FEED_PRECISION)) / PRECISION;
    }
}
