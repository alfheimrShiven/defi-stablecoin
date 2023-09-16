// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {DecentralizedStableCoin} from "./DecentralizedStableCoin.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/ERC20Mock.sol";

contract Practice {

    mapping(address collateralToken => address priceFeed) private s_priceFeed;
    mapping(address user => mapping(address collateralToken => uint256 amount)) private s_collateralDeposited;
    address[] public s_collateralTokens;

    error DSCEngine__TokenNotAllowed(address tokenAddress);
    error DSCEngine__TransferFailed(address collateralToken, uint256 collateralAmount);

    modifier checkIfTokenIsValid(address collateralToken) {
        if(s_priceFeed[collateralToken] == address(0)) {
            revert DSCEngine__TokenNotAllowed(collateralToken);
        }
        _;
    }

    event CollateralDeposited(
        address indexed sender,
        address collateralToken,
        uint256 collateralAmount
    );

    constructor(address[] memory _collateralTokens, address[] memory _priceFeeds) {
        for(uint256 t = 0; t < _collateralTokens.length; t++) {
            s_collateralTokens.push(_collateralTokens[t]);
            s_priceFeed[_collateralTokens[t]] = _priceFeeds[t];
        }
    }

    function depositCollateral(address collateralToken, uint256 collateralAmount) public checkIfTokenIsValid(collateralToken) {
        s_collateralDeposited[msg.sender][collateralToken] += collateralAmount;

        emit CollateralDeposited(msg.sender, collateralToken, collateralAmount);

        bool success = ERC20Mock(collateralToken).transfer(address(this), collateralAmount);

        if(!success) {
            revert DSCEngine__TransferFailed(collateralToken, collateralAmount);
        }
    }
}