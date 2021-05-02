//SPDX-License-Identifier: MIT
pragma solidity ^0.7.4;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

import "./ILendingPoolAddressesProvider.sol";
import "./ILendingPool.sol";
import "./ICreditDelegationToken.sol";
import "./IMilestones.sol";
import {DataTypes} from "./DataTypes.sol";

import "./AddressesProvider.sol";

import "./QuadraticDistribution.sol";

contract CommunityTreasury is Ownable {
    using SafeMath for uint256;

    event Borrowed(string _currency, uint256 _amount);
    event Distributed(string _currency, uint256 _amount, address _project);

    bytes4 public constant IDENTITY = 0xf114c7dc;

    //uint256 public constant THRESHOLD = 3840;
    //uint256 public constant MINAMOUNT = 2000;

    address public addressesProvider;
    address public milestones;
    address public q2t;
    mapping (address => uint256) public projectAllocation;
    mapping (uint256 => address) public projects;
    mapping (address => mapping (address => uint256)) public funds;
    mapping (address => uint256) public totalFunded;

    constructor(
        address _q2t,
        address _milestones, 
        address _addressesProvider 
    ) {
        milestones = _milestones;
        q2t = _q2t;
        addressesProvider = _addressesProvider;
    }

    function sendAllocation(uint256 _amount, address _project) public {
        require(projectAllocation[_project] >= _amount, "< allocation");

        IERC20 asset = IERC20(AddressesProvider(addressesProvider).currenciesAddresses("USDC"));  

        require(asset.balanceOf(address(this)) >= _amount, "< balance");

        projectAllocation[_project] = projectAllocation[_project].sub(_amount);
        asset.transfer(_project, _amount);

        emit Distributed("USDC", _amount, _project);
    }

    function allocateDelegated() public {
        ILendingPool lendingPool = ILendingPool(
            ILendingPoolAddressesProvider(
                AddressesProvider(addressesProvider).lendingPoolAP()).getLendingPool());
        address asset = AddressesProvider(addressesProvider).currenciesAddresses("USDC");
        address debtTokenAddress = lendingPool.getReserveData(asset).variableDebtTokenAddress;
        
        uint256 amount = ICreditDelegationToken(debtTokenAddress).borrowAllowance(address(q2t), address(this));
        require(amount > 0, "nothing to allocate");

        lendingPool.borrow(asset, amount, 2, 0, address(q2t));
        _distribute(amount);

        emit Borrowed("USDC", amount);
    }

    function _distribute(uint256 _fund) internal {
        uint256[] memory contributedProjects = IMilestones(milestones).popContributedProjects();
        uint256[] memory unweigted = new uint256[](contributedProjects.length);
        uint256[] memory projectContributions;

        //get unweighted allocations
        for (uint i = 0; i < contributedProjects.length; i++) {
            projectContributions = IMilestones(milestones).popContributionsPerProject(contributedProjects[i]);
            unweigted[i] = QuadraticDistribution.calcUnweightedAlloc(projectContributions);            
        }

        //get weights
        uint256[] memory weights = QuadraticDistribution.calcWeights(unweigted, contributedProjects.length);

        //get weighted allocations
        uint256[] memory weighted = QuadraticDistribution.calcWeightedAlloc(_fund, weights);

        //distribute funds
        for (uint i = 0; i < contributedProjects.length; i++) {
            projectAllocation[projects[contributedProjects[i]]] = projectAllocation[projects[contributedProjects[i]]].add(weighted[i]);
        }
    }
}
