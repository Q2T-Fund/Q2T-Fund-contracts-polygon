//SPDX-License-Identifier: MIT
pragma solidity ^0.7.4;
pragma experimental ABIEncoderV2;

import "hardhat/console.sol";

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

//import "./gsn/BaseRelayRecipient.sol";

import "./IAToken.sol";
import './IProtocolDataProvider.sol';
import './ICreditDelegationToken.sol';
import "./ILendingPool.sol";
//import {ILendingPoolAddressesProvider} from './ILendingPoolAddressesProvider.sol';
import "./IPriceOracle.sol";

import "./ITreasuryDao.sol";
import "./ICommunityTreasury.sol";

import "./QuadraticDistribution.sol";

contract TreasuryDao is ITreasuryDao, Ownable {
    using SafeMath for uint256;

    mapping (uint256 => address) public communityTeasuries;
    mapping (address => bool) public isTreasuryActive;
    uint256 public nextId;
    mapping(string => address) public depositableCurrenciesContracts;
    //mapping (address => mapping (address => uint256)) depositorATokens; //address is underlying asset;
    mapping (address => mapping (address => uint256)) public repayableAmount; //address is underlying asset;
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

        communityTeasuries[nextId] = _treasuryAddress;
        isTreasuryActive[_treasuryAddress] = true;
        communityTreasury.setId(nextId);

        emit CommunityLinked(_treasuryAddress, communityTreasury.community(), nextId);

        nextId = nextId.add(1);
    }

    function thresholdReached(uint256 _id) public override {
        require(msg.sender == communityTeasuries[_id], "wrong id");
        require(isTreasuryActive[msg.sender], "treasury is not active");

        IPriceOracle priceOracle = IPriceOracle(aaveProtocolDataProvider.ADDRESSES_PROVIDER().getPriceOracle());
        ILendingPool lendingPool = ILendingPool(aaveProtocolDataProvider.ADDRESSES_PROVIDER().getLendingPool());

        //delegation is for usdc for now
        (,,uint256 borrowingPower,,,) = lendingPool.getUserAccountData(address(this));
        uint256 totalDeligating = borrowingPower.div(priceOracle.getAssetPrice(depositableCurrenciesContracts["USDC"]));
        totalDeligating = totalDeligating.mul(80).div(100); //lower borrowing a bit to avoid liquidations

        //quadratic distribution delegation to different communities
        _distribute(totalDeligating.mul(1e18));

        //_delegate(msg.sender, depositableCurrenciesContracts["DAI"], type(uint256).max);
        //_delegate(msg.sender, depositableCurrenciesContracts["USDC"], type(uint256).max);

        emit ThresholdReached(_id);
    }

    function deposit(string memory _currency, uint256 _amount, uint256 _repayment) public override {
        require(nextId > 0, "no communy treasury added");
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
        //(address aTokenAddress,,) = aaveProtocolDataProvider.getReserveTokensAddresses(currencyAddress);
        //IAToken aToken = IAToken(aTokenAddress);
        
        //uint256 aBalanceBefore = aToken.balanceOf(address(this));
        currency.transferFrom(msg.sender, address(this), amount);
        currency.approve(address(lendingPool), amount);
        lendingPool.deposit(currencyAddress, amount, address(this), 0);
        //uint256 aBalanceAfter = aToken.balanceOf(address(this));
        //depositorATokens[msg.sender][currencyAddress].add(aBalanceAfter.sub(aBalanceBefore));
        repayableAmount[msg.sender][currencyAddress] = repayableAmount[msg.sender][currencyAddress].add(amount.mul(_repayment).div(100));
        depositors[msg.sender] = depositors[msg.sender].add(amount);
        totalDeposited = totalDeposited.add(amount);

        emit Deposited(msg.sender, _currency, _amount);
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

    function _distribute(uint256 _fund) internal {
        address project;
        uint256 projectsNum;
        ICommunityTreasury treasury;
        uint256[] memory unweigted = new uint256[](nextId);
        bool[] memory didContribute = new bool[](nextId);
        uint256 contributedNum = 0;
        uint256 n = 0;

        //get unweighted allocations
        for (uint i = 0; i < nextId; i++) {
            didContribute[i] = false;
            treasury = ICommunityTreasury(communityTeasuries[i]);
            if (isTreasuryActive[address(treasury)]) {
                //check if community has contributed projects
                projectsNum = treasury.projectsNum();
                console.log("projectsNum", projectsNum);
                if (projectsNum > 0) {
                    unweigted[n] = QuadraticDistribution.calcUnweightedAlloc(treasury.getAllContributions());
                    n++;
                    contributedNum = contributedNum.add(1);
                    didContribute[i] = true;
                }
            }
        }

        console.log("contributedNum", contributedNum);

        //remove communities that didn't contribute
        /*uint256[] memory unweigtedClean;         
        if (contributedNum == nextId) {
            unweigtedClean = unweigted;
        } else {
            unweigtedClean = new uint256[](contributedNum);
            n = 0;
            for (uint i = 0; i < nextId; i++) {
                if (didContribute[i]) {
                    unweigtedClean[n] = unweigted[i];
                    n++;
                }
            }
        }*/

        //get weights
        //uint256[] memory weights = new uint256[](contributedNum);
        //uint256 allocSum = QuadraticDistribution.sumUnweighted(unweigted, contributedNum);
        uint256[] memory weights = QuadraticDistribution.calcWeights(unweigted, contributedNum);

        /* for (uint256 i = 0; i < contributedNum; i++) {
            weights[i] = unweigted[i].div(allocSum);
        } */

        console.log("weights len", weights.length);
        console.log("weights[0]", weights[0]);

        //get wighted allocations
        //uint256[] memory weighted = new uint256[](weights.length);
        uint256[] memory weighted = QuadraticDistribution.calcWeightedAlloc(_fund, weights);

        //and finally approve delegation
        console.log("fund", _fund);
        n = 0;
        for (uint i = 0; i < nextId; i++) {
            if (didContribute[i]) {
                console.log("treasury", communityTeasuries[i]);
                console.log("alloc", weighted[n]);
                _delegate(communityTeasuries[i], depositableCurrenciesContracts["USDC"], weighted[n].div(1e12)); //for usdc
                //TODO: call treasury reset
                n++;
            }
        }
    }
}