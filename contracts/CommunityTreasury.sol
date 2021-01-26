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
    using SafeMath for uint256;

    uint256 public constant THRESHOLD = 3840;

    mapping(string => address) public depositableCurrenciesContracts;
    DataTypes.CommunityType public communityType;
    address public community;
    ITreasuryDao public override dao;
    IDITOToken public token;
    mapping (address => uint256) public depositors;
    uint256 public totalDeposited;

    constructor(uint256 _type, address _token) {
        communityType = DataTypes.CommunityType(_type);
        token = IDITOToken(_token);

        //kovan
        depositableCurrenciesContracts["DAI"] = address(
            0xFf795577d9AC8bD7D90Ee22b6C1703490b6512FD
        );

        depositableCurrenciesContracts["USDC"] = address(
            0xe22da380ee6B445bb8273C81944ADEB6E8450422
        );
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

        if (balance >= THRESHOLD.mul(1e18)) {
            token.transfer(community, SafeMath.mul(2000, 1e18));
            dao.thresholdReached(balance, community, communityType); 
        }
    }

    function deposit(string memory _currency, uint256 _amount) public override {
        require(address(dao) != address(0), "Treasury DAO is not set");
        
        address currencyAddress = address(
            depositableCurrenciesContracts[_currency]
        );
        require(
            currencyAddress != address(0),
            "The currency passed as an argument is not enabled, sorry!"
        );
        IERC20 currency = IERC20(currencyAddress);
        require(
            currency.balanceOf(_msgSender()) >= _amount,
            "You don't have enough funds to invest."
        );
        
        uint256 amount = _amount.mul(1e18);
        currency.transferFrom(_msgSender(), address(this), amount);
        currency.approve(address(dao), amount);
        dao.deposit(currencyAddress, amount, communityType);

        depositors[_msgSender()].add(amount);
        totalDeposited.add(amount);
    }

    function withdraw(address _currency, uint256 _amount) public override {

    }
}
