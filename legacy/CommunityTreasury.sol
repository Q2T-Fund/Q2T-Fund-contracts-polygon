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
import './ICreditDelegationToken.sol';
import {DataTypes} from './DataTypes.sol';

import "./IDITOToken.sol";
import "./ICommunityTreasury.sol";
import "./ITreasuryDao.sol";
import "./Community.sol";
import "./WithdrawTimelock.sol";
import "./AddressesProvider.sol";

import "./QuadraticDistribution.sol";

contract CommunityTreasury is ICommunityTreasury, Ownable {
    using SafeMath for uint256;

    bytes4 public constant IDENTITY = 0xf114c7dc;

    uint256 public constant THRESHOLD = 3840;
    uint256 public constant MINAMOUNT = 2000;

    address public addressesProvider;
    uint256 public id;
    bool idSet;
    DataTypes.CommunityTemplate public override template;
    address public override community;
    ITreasuryDao public override dao;
    IDITOToken public token;
    uint256 public totalGigsCompleted;
    uint256 public totalTokensReceived;
    address[] public projects;
    mapping(address => uint256[]) public projectContributions;
    mapping(address => uint256) public projectAllocation;
    WithdrawTimelock public timelock;
    bool public timelockActive;
    mapping (address => mapping (address => uint256)) public funds;
    mapping (address => uint256) public totalFunded;

    constructor(
        DataTypes.CommunityTemplate _template,
        address _community, 
        address _token,
        address _dao,
        address _addressesProvider 
    ) {
        community = _community;
        idSet = false;
        template = _template;
        addressesProvider = _addressesProvider;
        token = IDITOToken(_token);
        dao = ITreasuryDao(_dao);
    }
    
    function setId(uint256 _id) public override {
        require(msg.sender == address(dao), "only treasury dao can set id");
        require(!idSet, "treasury is already linked");
        require(community != address(0), "community is not set");

        id = _id;
        idSet = true;

        emit IdSet(_id);

        Community(community).setId(id);
    }

    function setTreasuryDAO(address _dao) public override onlyOwner {
        require(!idSet, "treasury is already linked");
        dao = ITreasuryDao(_dao);

        emit TreasuryDaoSet(_dao);
    }
    
    /*function setCommunity(address _community) public override onlyOwner {
        require(!idSet, "treasury is already linked");
        community = _community;
        token.approve(community, type(uint256).max);

        emit CommunitySet(_community);
    }*/

    function approveCommunity() public override {
        token.approve(community, type(uint256).max);
    }

    function completeMilestone(uint256 _amount, address _project) public override {
        require(_msgSender() == community, "Gig can only be completed by community");
        require(_project != address(0), "no project for milestone");
        require(_amount > 0, "amount is 0");

        token.transferFrom(_msgSender(), address(this), _amount.mul(1e18));        
        uint256 balance = token.balanceOf(address(this));
        if (projectContributions[_project].length == 0) {
            projects.push(_project);
        }
        projectContributions[_project].push(_amount.mul(1e18));
        
        totalGigsCompleted = totalGigsCompleted.add(1);
        totalTokensReceived = totalTokensReceived.add(_amount);
        if (balance >= THRESHOLD.mul(1e18)) {
            uint256 sendback = balance.sub(MINAMOUNT.mul(1e18));

            dao.thresholdReached(id);
            emit MilesoteComplete(_amount, _project);
            emit ThersholdReached(getDitoBalance());
            token.transfer(community, sendback);
        } else {
            emit MilesoteComplete(_amount, _project);
        }
    }

    function addTimelock() public override {
        require(!timelockActive, "already active");

        timelock = WithdrawTimelock(msg.sender);
    }

    function activateTimelock() public override onlyOwner {
        require(address(timelock) != address(0), "not set");

        timelockActive = true;
    }
    
    function fund(string memory _currency, uint256 _amount) public override {
        require(timelockActive, "timelock not active");
        
        address asset = AddressesProvider(addressesProvider).currenciesAddresses(_currency);
        require(asset != address(0), "currency not supported");

        uint256 amount = _amount.mul(1e18);

        require(
            IERC20(asset).balanceOf(_msgSender()) >= amount,
            "not enough own funds"
        );

        IERC20(asset).transferFrom(msg.sender, address(this), amount);
        IERC20(asset).approve(address(dao), amount);

        dao.deposit(_currency, _amount, 100);

        timelock.deposit(msg.sender,asset, amount);
        funds[msg.sender][asset] = funds[msg.sender][asset].add(amount);
        totalFunded[asset] = totalFunded[asset].add(amount);

        emit Funded(msg.sender, asset, amount); 
    }

    function withdrawFunding(address _currency, uint256 _amount) public override {

    }

    function receiveAllocation(string memory _currency, uint256 _amount, address _project) public override {
        require(projectAllocation[_project] >= _amount, "< allocation");

        IERC20 asset = IERC20(AddressesProvider(addressesProvider).currenciesAddresses(_currency));  

        require(asset.balanceOf(address(this)) >= _amount, "< balance");

        projectAllocation[_project] = projectAllocation[_project].sub(_amount);
        asset.transfer(_project, _amount);

        emit Distributed(_currency, _amount, _project);
    }

    function allocateDelegated() public {
        ILendingPool lendingPool = ILendingPool(
            ILendingPoolAddressesProvider(
                AddressesProvider(addressesProvider).lendingPoolAP()).getLendingPool());
        address asset = AddressesProvider(addressesProvider).currenciesAddresses("USDC");
        address debtTokenAddress = lendingPool.getReserveData(asset).variableDebtTokenAddress;
        
        uint256 amount = ICreditDelegationToken(debtTokenAddress).borrowAllowance(address(dao), address(this));
        require(amount > 0, "nothing to allocate");

        lendingPool.borrow(asset, amount, 2, 0, address(dao));
        _distribute(amount);
        _resetProjects();

        emit Borrowed("USDC", amount);
    }

    function getDitoBalance() public override view returns (uint256) {
        return token.balanceOf(address(this));
    }

    function getFunds(address _funder, address _asset) public view returns (uint256) {
        return funds[_funder][_asset];
    }

    function getProjects(uint256 _id) public view override returns (address) {
        return projects[_id];
    }

    function getProjectContributions(address _project) public view override returns (uint256[] memory) {
        return projectContributions[_project];
    }

    function getAllContributions() public view override returns (uint256[] memory) {
        uint256[] memory totalCreditsReceived = new uint256[](totalGigsCompleted);
        uint256 n = 0;

        for (uint i; i < projects.length; i++) {
            for (uint j; j < projectContributions[projects[i]].length; j++) {
                totalCreditsReceived[n] = projectContributions[projects[i]][j];
                n++;
            }
        }

        return totalCreditsReceived;
    }

    function projectsNum() public view override returns (uint256) {
        return projects.length;
    }

    function _resetProjects() internal {
        for (uint256 i; i < projects.length; i++) {
            delete projectContributions[projects[i]];
        }

        delete projects;
        totalGigsCompleted = 0;
    }

    function _distribute(uint256 _fund) internal {
        address[] memory contributedProjects = projects;
        uint256[] memory unweigted = new uint256[](contributedProjects.length);

        //get unweighted allocations
        for (uint i = 0; i < contributedProjects.length; i++) {
            unweigted[i] = QuadraticDistribution.calcUnweightedAlloc(projectContributions[contributedProjects[i]]);            
        }

        //get weights
        uint256[] memory weights = QuadraticDistribution.calcWeights(unweigted, contributedProjects.length);

        //get weighted allocations
        uint256[] memory weighted = QuadraticDistribution.calcWeightedAlloc(_fund, weights);

        //distribute funds
        for (uint i = 0; i < contributedProjects.length; i++) {
            projectAllocation[contributedProjects[i]] = projectAllocation[contributedProjects[i]].add(weighted[i]);
        }
    }
}
