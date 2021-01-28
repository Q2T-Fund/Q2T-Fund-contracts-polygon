//SPDX-License-Identifier: MIT
pragma solidity ^0.7.4;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

//import "./gsn/BaseRelayRecipient.sol";

import "./IAToken.sol";
import './IProtocolDataProvider.sol';
import './ICreditDelegationToken.sol';
import "./ILendingPool.sol";
//import {ILendingPoolAddressesProvider} from './ILendingPoolAddressesProvider.sol';

import "./ITreasuryDao.sol";
import "./ICommunityTreasury.sol";

contract TreasuryDao is ITreasuryDao, Ownable {
    using SafeMath for uint256;

    mapping (uint256 => address) public communityTeasuries;
    mapping (address => bool) public isTreasuryActive;
    uint256 public totalCommunities;
    mapping(string => address) public depositableCurrenciesContracts;
    mapping (address => mapping (address => uint256)) depositorATokens; //address is underlying asset;
    IProtocolDataProvider public aaveProtocolDataProvider;
    DataTypes.CommunityTemplate public template;

    mapping (address => uint256) public depositors;
    uint256 public totalDeposited;

    constructor(DataTypes.CommunityTemplate _template, address _aaveDataProvider, address _dai, address _usdc) {
        require(_aaveDataProvider != address(0), "Aave data provider cannot be 0");

        depositableCurrenciesContracts["DAI"] = _dai;
        depositableCurrenciesContracts["USDC"] = _usdc;
        template = _template;
        aaveProtocolDataProvider = IProtocolDataProvider(_aaveDataProvider);
    }

    function linkCommunity(address _treasuryAddress) public override onlyOwner {
        ICommunityTreasury communityTreasury = ICommunityTreasury(_treasuryAddress);

        require(communityTreasury.template() == template, "template mismatch");
        require(address(communityTreasury.dao()) == address(this), "dao mismatch");

        communityTeasuries[totalCommunities] = _treasuryAddress;
        isTreasuryActive[_treasuryAddress] = true;
        communityTreasury.setId(totalCommunities);
        totalCommunities = totalCommunities.add(1);
    }

    function thresholdReached(uint256 _id) public override {
        require(msg.sender == communityTeasuries[_id], "wrong id");
        require(isTreasuryActive[msg.sender], "treasury is not active");

        //should be quadratic distribution first and delegation to different communities
        _delegate(msg.sender, depositableCurrenciesContracts["DAI"], type(uint256).max);
        _delegate(msg.sender, depositableCurrenciesContracts["USDC"], type(uint256).max);
    }

    function deposit(string memory _currency, uint256 _amount) public override {
        require(totalCommunities > 0, "no communy treasury added");
        address currencyAddress = address(
            depositableCurrenciesContracts[_currency]
        );
        require(
            currencyAddress != address(0),
            "The currency passed as an argument is not enabled, sorry!"
        );
        IERC20 currency = IERC20(currencyAddress);
        uint256 amount = _amount.mul(1e18);
        require(
            currency.balanceOf(_msgSender()) >= amount,
            "You don't have enough funds to invest."
        );
        
        ILendingPool lendingPool = ILendingPool(aaveProtocolDataProvider.ADDRESSES_PROVIDER().getLendingPool());
        (address aTokenAddress,,) = aaveProtocolDataProvider.getReserveTokensAddresses(currencyAddress);
        IAToken aToken = IAToken(aTokenAddress);
        
        uint256 aBalanceBefore = aToken.balanceOf(address(this));
        currency.transferFrom(msg.sender, address(this), amount);
        currency.approve(address(lendingPool), amount);
        lendingPool.deposit(currencyAddress, amount, address(this), 0);
        uint256 aBalanceAfter = aToken.balanceOf(address(this));
        depositorATokens[msg.sender][currencyAddress].add(aBalanceAfter.sub(aBalanceBefore));
        depositors[msg.sender].add(amount);
        totalDeposited.add(amount);
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