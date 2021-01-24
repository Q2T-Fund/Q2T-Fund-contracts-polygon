//SPDX-License-Identifier: MIT
pragma solidity ^0.7.4;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

import "./gsn/BaseRelayRecipient.sol";

import "./ILendingPoolAddressesProvider.sol";
import "./ILendingPool.sol";
import "./IAToken.sol";
import {DataTypes} from './DataTypes.sol';

import "./IDITOToken.sol";
import "./ICommunityTreasury.sol";
import "./ITreasuryDao.sol";

contract CommunityTreasury is ICommunityTreasury, Ownable {
    uint256 public constant THRESHOLD = 3840;
    
    DataTypes.CommunityType public communityType;
    address public community;
    ITreasuryDao public dao;
    IDITOToken public token;

    constructor(uint256 _type, address _token) {
        communityType = DataTypes.CommunityType(_type);
        token = IDITOToken(token);
    }
    
    function setTreasuryDAO(address _dao) public override onlyOwner {
        dao = ITreasuryDao(_dao);
    }
    
    function setCommunity(address _community) public override onlyOwner {
        community = _community;
    }

    function completeGig(uint256 _amount) public override {
        require(_msgSender() == community, "Gig can only be completed by community");

        uint256 balance = token.balanceOf(address(this));

        if (balance >= THRESHOLD) {
            token.transfer(community, SafeMath.mul(2000, 1e18));
            dao.thresholdReached(balance, communityType); 
        }
    }

    function deposit(address _currency, uint256 _amount) public override {

    }

    function withdraw(address _currency, uint256 _amount) public override {

    }
}
