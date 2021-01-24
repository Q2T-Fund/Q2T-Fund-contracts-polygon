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

import "./IDITOToken.sol";
import "./ICommunityTreasury.sol";
import "./ITreasuryDao.sol";

contract CommunityTreasury is ICommunityTreasury, Ownable {
    uint256 public constant THRESHOLD = 3840;
    
    address public community;
    ITreasuryDao public dao;
    IDITOToken public token;
    
    function setTreasuryDAO(address _dao) public override onlyOwner {
        dao = ITreasuryDao(_dao);
    }
    
    function setCommunity(address _community) public override onlyOwner {
        community = _community;
    }

    function completeGig(uint256 _amount) public override {
        require(_msgSender() == community, "Gig can only be completed by community");

        if(token.balanceOf(address(this)) >= THRESHOLD) {
            //return 2k to community
            //call TreasuryDAO to delegate funds
        }
    }

    function deposit(address _currency, uint256 _amount) public override {

    }

    function withdraw(address _currency, uint256 _amount) public override {

    }

    function delegate(address _currency, uint256 _amount, address _deligatee) public override {

    }

    function undelegate(address _currency, address _deligatee, bool _force) public override {

    }
    
    function getDeligateeCount(address _currency) public override returns (uint256) {
        return 0;
    }

    function getDeligatee(address _currency, uint256 _id) public override returns (address) {
        return address(0);
    }

    function getDeligateeBorrowedAmount(address _currency, address _deligatee) public override returns (uint256) {
        return 0;
    }
    
    function getTreasuryBalance(address _currency) public override returns (uint256) {
        return 0;
    }

    function getTreasuryBorrowedBalance(address _currency) public override returns (uint256) {
        return 0;
    }
     
    function getBalance(address _currency, address _member) public override returns (uint256) {
        return 0;
    }
}
