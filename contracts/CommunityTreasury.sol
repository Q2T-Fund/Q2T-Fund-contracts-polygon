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
    address public constant LENDING_POOL_AP=0x88757f2f99175387aB4C6a4b3067c77A695b0349; //kovan

    mapping(string => address) public depositableCurrenciesContracts;
    DataTypes.CommunityType public communityType;
    address public community;
    ITreasuryDao public override dao;
    IDITOToken public token;
    mapping (address => uint256) public depositors;
    uint256 public totalDeposited;
    uint256 public totalGigsCompleted;
    uint256 public totalTokensReceived;

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
        token.approve(community, type(uint256).max);
    }

    function completeGig(uint256 _amount) public override {
        require(_msgSender() == community, "Gig can only be completed by community");

        token.transferFrom(_msgSender(), address(this), _amount.mul(1e18));        
        uint256 balance = token.balanceOf(address(this));

        totalGigsCompleted.add(1);
        totalTokensReceived.add(_amount);
        if (balance >= THRESHOLD.mul(1e18)) {
            dao.thresholdReached(communityType); 
            token.transfer(community, SENDBACK.mul(1e18));
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
        uint256 amount = _amount.mul(1e18);
        require(
            currency.balanceOf(_msgSender()) >= _amount,
            "You don't have enough funds to invest."
        );
        
        currency.transferFrom(_msgSender(), address(this), amount);
        currency.approve(address(dao), amount);
        dao.deposit(currencyAddress, amount, communityType);

        depositors[_msgSender()].add(amount);
        totalDeposited.add(amount);
    }

    function withdraw(address _currency, uint256 _amount) public override {

    }

    function borrowDelegated(uint256 _amount) public {
        // Retrieve LendingPool address provide
        ILendingPoolAddressesProvider provider = ILendingPoolAddressesProvider(
            address(LENDING_POOL_AP)
        ); // Ropsten address, for other addresses: https://docs.aave.com/developers/developing-on-aave/deployed-contract-instances
        ILendingPool lendingPool = ILendingPool(provider.getLendingPool());
        address asset = address(depositableCurrenciesContracts["DAI"]);

        lendingPool.borrow(asset, _amount, 1, 0, address(dao));
        //add distribute function
    }

    function getDitoBalance() public view returns (uint256) {
        return token.balanceOf(address(this));
    }
}
