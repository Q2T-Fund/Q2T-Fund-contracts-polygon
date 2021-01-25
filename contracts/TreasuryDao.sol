//SPDX-License-Identifier: MIT
pragma solidity ^0.7.4;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

import "./gsn/BaseRelayRecipient.sol";

import './IProtocolDataProvider.sol';
import './ICreditDelegationToken.sol';
import "./ILendingPool.sol";
import {ILendingPoolAddressesProvider} from './ILendingPoolAddressesProvider.sol';

import "./ITreasuryDao.sol";

contract TreasuryDao is ITreasuryDao, Ownable {
    using SafeMath for uint256;

    address[] public communities;
    IProtocolDataProvider public aaveProtocolDataProvider;
    IERC20 public constant DAI = IERC20(0xFf795577d9AC8bD7D90Ee22b6C1703490b6512FD); //kovan

    constructor(address _aaveDataProvider) public {
        require(_aaveDataProvider != address(0), "Aave data provider cannot be 0");

        communities = new address[](3);
        aaveProtocolDataProvider = IProtocolDataProvider(_aaveDataProvider);
    }

    function setCommunityTreasury(address _communityTreasury, DataTypes.CommunityType _type) public override onlyOwner {
        communities[uint256(_type)]=_communityTreasury;
    }

    function thresholdReached(uint256 _amount, DataTypes.CommunityType _type) public override {
        require(msg.sender == communities[uint256(_type)]);

        //should be quadratic distribution first and delegation to different communities
        _delegate(msg.sender, address(DAI), 99999999999999999999);
    }

    function deposit(address _currency, uint256 _amount, DataTypes.CommunityType _type) public override {
        require(msg.sender == communities[uint256(_type)]);

        IERC20 currency = IERC20(_currency);
        ILendingPool lendingPool = ILendingPool(aaveProtocolDataProvider.ADDRESSES_PROVIDER().getLendingPool());

        currency.transferFrom(msg.sender,address(this), _amount);
        currency.approve(address(lendingPool), _amount);
        lendingPool.deposit(address(DAI), _amount, msg.sender, 0);
    }

    function withdraw(address _currency, uint256 _amount) public override {

    }

    function delegate(address _currency, uint256 _amount, address _deligatee) public override {

    }

    function undelegate(address _currency, address _deligatee, bool _force) public override {

    }
    
    function getDeligateeCount(address _currency) public override returns (uint256) {

    }

    function getDeligatee(address _currency, uint256 _id) public override returns (address) {

    }

    function getDeligateeBorrowedAmount(address _currency, address _deligatee) public override returns (uint256){

    }
    
    function getTreasuryBalance(address _currency) public override returns (uint256){

    }

    function getTreasuryBorrowedBalance(address _currency) public override returns (uint256) {

    }

    function getBalance(address _currency, address _member) public override returns (uint256) {

    }

    function _delegate (address _community, address _currency, uint256 _amount) internal {
        (, address stableDebtTokenAddress,) = aaveProtocolDataProvider.getReserveTokensAddresses(_currency);
        ICreditDelegationToken(stableDebtTokenAddress).approveDelegation(_community, _amount);
    }
}