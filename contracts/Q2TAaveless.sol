//SPDX-License-Identifier: MIT
pragma solidity ^0.7.4;
pragma experimental ABIEncoderV2;

import "./AddressesProvider.sol";
import "./TemplatesTreasuriesWithReserves.sol";
import "./DataTypes.sol";
import "./IMilestones.sol";
import "./MilestonesFactory.sol";
import "./CommunityTreasuryFactoryNoAave.sol";
import "./QuadraticDistribution.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC1155/ERC1155Holder.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";

contract Q2TAaveless is ERC1155Holder {
    using SafeMath for uint256;

    event ThresholdReached(DataTypes.Template _template, address _milestones);
    event Deposited(
        DataTypes.Template _template, 
        address _depositor, 
        string _currency, 
        uint256 _amount,
        uint256 _q2tAmount,
        uint256 _repaymentAmount
    );
    event Delegated(
        address _communityTreasury, 
        address _currency, 
        uint256 _amount
    );
    event MilestonesDeployed(
        DataTypes.Template _template,
        address _milestones,
        address _communityTreasury
    );
    event Borrowed(
        address _borrower,
        address _currency,
        uint256 _amount
    );

    address public addressesProvider;
    address public templatesReapayersTreasuries;
    address public templatesTreasuries;
    uint256 public totalQ2TFund;
    uint256 public totalRepayerFund;
    mapping (address => mapping (address => uint256)) public repaymentAmounts;
    mapping (address => uint256) public depositors;
    mapping (DataTypes.Template => address[]) public temapltesMilestones;
    mapping (address => DataTypes.Template) public milestonesTemplates;
    mapping (address => address) public milestonesTreasuries;
    mapping (address => address) public communitiesMilestones;
    mapping (address => mapping (address => uint256)) public delegatedCredit; //treasury => currency => amount
    mapping (address => mapping (address => uint256)) public borrowedCredit; //treasury => currency => amount


    constructor(
        address _addressesProvider
    ) {
        require(_addressesProvider != address(0), "Addressess provider cannot be 0");

        addressesProvider = _addressesProvider;

        TemplatesTreasuries templatesTreasuriesContract = new TemplatesTreasuriesWithReserves("");
        templatesTreasuries = address(templatesTreasuriesContract);
        TemplatesTreasuries templatesReapayersTreasuriesContract = new TemplatesTreasuries("");
        templatesReapayersTreasuries = address(templatesReapayersTreasuriesContract);
    }

    function deployMilestones(DataTypes.Template _template, address _communityAddress) public returns (address) {
        require (communitiesMilestones[_communityAddress] == address(0), "Milestones already deployed");
        require (_template != DataTypes.Template.NONE, "Template not specified");

        address newMilestones = MilestonesFactory(AddressesProvider(
            addressesProvider).milestonesFactory()).deployMilestones(
                _communityAddress
            );

        temapltesMilestones[_template].push(newMilestones);
        milestonesTemplates[newMilestones] = _template;

        //deploy treasury
        address newTreasury = CommunityTreasuryFactoryNoAave(AddressesProvider(
            addressesProvider).communityTreasuryFactory()).deployTreasury(
                address(this), newMilestones, addressesProvider
            );

        milestonesTreasuries[newMilestones] = newTreasury;
        communitiesMilestones[_communityAddress] = newMilestones;
        IMilestones(newMilestones).setTreasury(newTreasury);

        emit MilestonesDeployed(_template, newMilestones, newTreasury);

        return newMilestones;
    }

    function deposit(DataTypes.Template _template, uint256 _amount, uint256 _repayment) public {
        require (_template != DataTypes.Template.NONE, "Template not specified");

        address currencyAddress = AddressesProvider(addressesProvider).currenciesAddresses("DAI");
        
        IERC20 currency = IERC20(currencyAddress);
        //uint256 amount = _amount.mul(1e18);
        require(
            currency.balanceOf(msg.sender) >= _amount,
            "You don't have enough funds to invest."
        );
        
        currency.transferFrom(msg.sender, address(this), _amount);

        uint256 repaymentAmount = _amount.mul(_repayment).div(100);
        uint256 q2tAmount = _amount.sub(repaymentAmount);

        if(TemplatesTreasuriesWithReserves(templatesTreasuries).balanceOf(address(this), uint256(_template)) == 0) {
            TemplatesTreasuriesWithReserves(templatesTreasuries).mint(_template, q2tAmount);
        } else {
            TemplatesTreasuriesWithReserves(templatesTreasuries).addFunds(_template, q2tAmount);
        }

        if(TemplatesTreasuries(templatesReapayersTreasuries).balanceOf(address(this), uint256(_template)) == 0) {
            TemplatesTreasuries(templatesReapayersTreasuries).mint(_template, repaymentAmount);
        } else {
            TemplatesTreasuries(templatesReapayersTreasuries).addFunds(_template, repaymentAmount);
        }

        repaymentAmounts[msg.sender][currencyAddress] = repaymentAmounts[msg.sender][currencyAddress].add(repaymentAmount);
        depositors[msg.sender] = depositors[msg.sender].add(q2tAmount);

        emit Deposited(_template, msg.sender, "DAI", _amount, q2tAmount, repaymentAmount);
    }

    function thresholdReached() public {
        DataTypes.Template milestonesTemplate = milestonesTemplates[msg.sender];
        require(milestonesTemplate != DataTypes.Template.NONE, "Sender not milestones");

        uint256 totalDeligating;

        if (TemplatesTreasuriesWithReserves(templatesTreasuries).balanceOf(address(this), uint256(milestonesTemplate)) == 1){
            uint256 templateFunds = TemplatesTreasuriesWithReserves(templatesTreasuries).getCurrentFund(milestonesTemplate);
            TemplatesTreasuriesWithReserves(templatesTreasuries).burn(milestonesTemplate);
            totalDeligating = templateFunds.mul(50).div(100); //reduce to 50%
            TemplatesTreasuriesWithReserves(templatesTreasuries).addReserves(
                milestonesTemplate,
                templateFunds.sub(totalDeligating)
            );        
        } else {
            totalDeligating = TemplatesTreasuriesWithReserves(templatesTreasuries).useReserves(milestonesTemplate);
        }

        address currencyAddress = AddressesProvider(addressesProvider).currenciesAddresses("DAI");
        
        IERC20 currency = IERC20(currencyAddress);

        uint256 balance = currency.balanceOf(address(this));

        if(balance < totalDeligating) { //check if not exceeding balance too much, probably paranoia
            totalDeligating = balance;
        }

        //quadratic distribution delegation to different communities
        _distribute(milestonesTemplate, totalDeligating);

        emit ThresholdReached(milestonesTemplate, msg.sender);
    }

    function getMilestonesPerTemplate(DataTypes.Template _template) public view returns (uint256) {
        return temapltesMilestones[_template].length;
    }

    function borrow(address _currency) public returns (uint256) {
        uint256 amount = delegatedCredit[msg.sender][_currency];
        require(amount > 0, "nothing to borrow");

        IERC20 currency = IERC20(_currency);
        uint256 balance = currency.balanceOf(address(this));
        if (balance < amount) { //check if not exceeding balance too much, probably paranoia
            amount = balance;
        }

        delegatedCredit[msg.sender][_currency];
        borrowedCredit[msg.sender][_currency] = borrowedCredit[msg.sender][_currency].add(amount);
        currency.transfer(msg.sender, amount);

        emit Borrowed(msg.sender, _currency, amount);

        return amount;      
    }

    function _distribute(DataTypes.Template _template, uint256 _fund) internal {
        uint256 projectsNum;
        IMilestones currMilestones;
        address[] memory milestones = temapltesMilestones[_template];
        uint256 milestonesNum = milestones.length;
        uint256[] memory unweigted = new uint256[](milestonesNum);
        bool[] memory didContribute = new bool[](milestonesNum);
        uint256 contributedNum = 0;
        uint256 n = 0;

        //get unweighted allocations
        for (uint i = 0; i < milestonesNum; i++) {
            didContribute[i] = false;
            currMilestones = IMilestones(milestones[i]);
            
            //check if community has contributed projects
            projectsNum = currMilestones.projectsNum();
            uint256[] memory communityContributions = currMilestones.popTotalCommunityContributions();
            if (projectsNum > 0) {
                unweigted[n] = QuadraticDistribution.calcUnweightedAlloc(communityContributions);
                n++;
                contributedNum++;
                didContribute[i] = true;
            }            
        }

        uint256[] memory weights = QuadraticDistribution.calcWeights(unweigted, contributedNum);

        uint256[] memory weighted = QuadraticDistribution.calcWeightedAlloc(_fund, weights);

        address currency = AddressesProvider(addressesProvider).currenciesAddresses("DAI");

        //and finally approve delegation
        n = 0;
        for (uint i = 0; i < milestonesNum; i++) {
            if (didContribute[i]) {
                address treasury = milestonesTreasuries[milestones[i]];

                delegatedCredit[treasury][currency] = delegatedCredit[treasury][currency].add(weighted[n]);

                emit Delegated(treasury, currency, weighted[n]);
                n++;
            }
        }
    }
}
