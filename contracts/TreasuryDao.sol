//SPDX-License-Identifier: MIT
pragma solidity ^0.7.4;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

import "./gsn/BaseRelayRecipient.sol";

import './IProtocolDataProvider.sol';
import './ICreditDelegationToken.sol';
import "./ILendingPool.sol";

import "./ITreasuryDao.sol";

contract TreasuryDao is ITreasuryDao, Ownable {
    using SafeMath for uint256;

    address[] public communities;
    IProtocolDataProvider public aaveProtocolDataProvider;
    IERC20 public constant DAI = IERC20(0x4F96Fe3b7A6Cf9725f59d353F723c1bDb64CA6Aa); //kovan

    constructor(address _aaveDataProvider) public {
        communities = new address[](3);
        aaveProtocolDataProvider = IProtocolDataProvider(_aaveDataProvider);
    }

    function setCommunityTreasury(address _communityTreasury, DataTypes.CommunityType _type) public override onlyOwner {
        communities[uint256(_type)]=_communityTreasury;
    }

    function thresholdReached(uint256 _amount, DataTypes.CommunityType _type) public override {
        require(msg.sender == communities[uint256(_type)]);

        //should be quadratic distribution first
        _delegate(msg.sender, address(DAI), _amount.mul(1e18));
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