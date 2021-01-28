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
    uint256 public constant SENDBACK = 2000;

    ILendingPoolAddressesProvider public lendingPoolAP;
    mapping(string => address) public depositableCurrenciesContracts;
    uint256 public id;
    DataTypes.CommunityTemplate public template;
    address public community;
    ITreasuryDao public override dao;
    IDITOToken public token;
    uint256 public totalGigsCompleted;
    uint256 public totalTokensReceived;

    constructor(
        uint256 _id,
        DataTypes.CommunityTemplate _template, 
        address _token,
        address _dao, 
        address _dai, 
        address _usdc, 
        address _lendingPoolAP
    ) {
        community = _msgSender();
        id = _id;
        template = _template;
        token = IDITOToken(_token);
        dao = ITreasuryDao(_dao);
        lendingPoolAP = ILendingPoolAddressesProvider(_lendingPoolAP);

        depositableCurrenciesContracts["DAI"] = _dai;

        depositableCurrenciesContracts["USDC"] = _usdc;
    }
    
    function setTreasuryDAO(address _dao) public override onlyOwner {
        dao = ITreasuryDao(_dao);
    }
    
    function setCommunity(address _community) public override onlyOwner {
        community = _community;
        token.approve(community, type(uint256).max);
    }

    function approveCommunity() public override {
        token.approve(community, type(uint256).max);
    }

    function completeGig(uint256 _amount) public override {
        require(_msgSender() == community, "Gig can only be completed by community");

        token.transferFrom(_msgSender(), address(this), _amount.mul(1e18));        
        uint256 balance = token.balanceOf(address(this));

        totalGigsCompleted.add(1);
        totalTokensReceived.add(_amount);
        if (balance >= THRESHOLD.mul(1e18)) {
            dao.thresholdReached(id); 
            token.transfer(community, SENDBACK.mul(1e18));
        }
    }

    function deposit(string memory _currency, uint256 _amount) public override {
        
    }

    function withdraw(address _currency, uint256 _amount) public override {

    }

    function borrowDelegated(string memory _currency, uint256 _amount) public {
        ILendingPool lendingPool = ILendingPool(lendingPoolAP.getLendingPool());
        address asset = address(depositableCurrenciesContracts[_currency]);

        require(asset != address(0), "currency not supported");

        lendingPool.borrow(asset, _amount, 1, 0, address(dao));
        //add distribute function
    }

    function getDitoBalance() public view returns (uint256) {
        return token.balanceOf(address(this));
    }
}
