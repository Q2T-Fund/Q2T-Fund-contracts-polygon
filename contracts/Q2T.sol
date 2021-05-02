//SPDX-License-Identifier: MIT
pragma solidity ^0.7.4;
pragma experimental ABIEncoderV2;

import "./AddressesProvider.sol";
import "./TemplatesTreasuriesWithReserves.sol";
import "./DataTypes.sol";
import "./IMilestones.sol";
import "./MilestonesFactory.sol";
import "./CommunityTreasuryFactory.sol";
import "./QuadraticDistribution.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC1155/ERC1155Holder.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "./ILendingPool.sol";
import "./ICreditDelegationToken.sol";
import "./IPriceOracle.sol";

contract Q2T is ERC1155Holder {
    using SafeMath for uint256;

    event ThresholdReached(DataTypes.Template _template, address _milestones);
    event Deposited(
        DataTypes.Template _template, 
        address _depositor, 
        string _currency, 
        uint256 _amount,
        uint256 _repaymentAmount,
        uint256 _aTokensAmount
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

    address public addressesProvider;
    ILendingPoolAddressesProvider ledningPoolAP;
    address public templatesReapayersTreasuries;
    address public templatesTreasuries;
    uint256 private aTokenLastBalance;
    uint256 public totalQ2TFund;
    uint256 public totalRepayerFund;
    mapping (address => mapping (address => uint256)) public repaymentAmounts;
    mapping (address => uint256) public depositors;
    mapping (DataTypes.Template => address[]) public temapltesMilestones;
    mapping (address => DataTypes.Template) public milestonesTemplates;
    mapping (address => address) public milestonesTreasuries;
    mapping (address => address) communitiesMilestones;

    constructor(
        address _addressesProvider
    ) {
        require(_addressesProvider != address(0), "Addressess provider cannot be 0");

        addressesProvider = _addressesProvider;
        ledningPoolAP = ILendingPoolAddressesProvider(
                AddressesProvider(addressesProvider).lendingPoolAP());

        TemplatesTreasuries templatesTreasuriesContract = new TemplatesTreasuriesWithReserves("");
        templatesTreasuries = address(templatesTreasuriesContract);
        TemplatesTreasuries templatesReapayersTreasuriesContract = new TemplatesTreasuries("");
        templatesReapayersTreasuries = address(templatesReapayersTreasuriesContract);
    }

    function deployMilestones(DataTypes.Template _template, address _communityAddress) public {
        require (communitiesMilestones[_communityAddress] == address(0), "Milestones already deployed");
        require (_template != DataTypes.Template.NONE, "Template not specified");
        address newMilestones = MilestonesFactory(AddressesProvider(
            addressesProvider).milestonesFactory()
        ).deployMilestones(
            _communityAddress
        );

        temapltesMilestones[_template].push(newMilestones);
        milestonesTemplates[newMilestones] = _template;
        //deploy treasury
        address newTreasury = CommunityTreasuryFactory(AddressesProvider(
            addressesProvider).communityTreasuryFactory()
        ).deployTreasury(address(this), newMilestones, addressesProvider);

        milestonesTreasuries[newMilestones] = newTreasury;
        communitiesMilestones[_communityAddress] = newMilestones;

        emit MilestonesDeployed(_template, newMilestones, newTreasury);
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
        
        ILendingPool lendingPool = ILendingPool(ledningPoolAP.getLendingPool());

        IERC20 aToken = IERC20(lendingPool.getReserveData(currencyAddress).aTokenAddress);
        uint256 aTokenBalance = aToken.balanceOf(address(this));
        uint256 aTokenYeild = aTokenBalance.sub(aTokenLastBalance);

        currency.approve(address(lendingPool), q2tAmount);
        lendingPool.deposit(currencyAddress, q2tAmount, address(this), 0);

        aTokenLastBalance = aToken.balanceOf(address(this));
        uint256 aTokenReceived = aTokenLastBalance.sub(aTokenBalance).add(aTokenYeild);

        if(TemplatesTreasuriesWithReserves(templatesTreasuries).balanceOf(address(this), uint256(_template)) == 0) {
            TemplatesTreasuriesWithReserves(templatesTreasuries).mint(_template, aTokenReceived);
        } else {
            TemplatesTreasuriesWithReserves(templatesTreasuries).addFunds(_template, aTokenReceived);
        }

        if(TemplatesTreasuries(templatesReapayersTreasuries).balanceOf(address(this), uint256(_template)) == 0) {
            TemplatesTreasuries(templatesReapayersTreasuries).mint(_template, repaymentAmount);
        } else {
            TemplatesTreasuries(templatesReapayersTreasuries).addFunds(_template, repaymentAmount);
        }

        repaymentAmounts[msg.sender][currencyAddress] = repaymentAmounts[msg.sender][currencyAddress].add(repaymentAmount);
        depositors[msg.sender] = depositors[msg.sender].add(q2tAmount);

        emit Deposited(_template, msg.sender, "DAI", _amount, repaymentAmount, aTokenReceived);
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

        IPriceOracle priceOracle = IPriceOracle(ledningPoolAP.getPriceOracle());
        ILendingPool lendingPool = ILendingPool(ledningPoolAP.getLendingPool());

        //delegation is for usdc for now
        //calculate maximum delegation contrct can afford
        (,,uint256 borrowingPower,,,) = lendingPool.getUserAccountData(address(this));
        uint256 maxDeligation = borrowingPower.div(
            priceOracle.getAssetPrice(
                AddressesProvider(addressesProvider).currenciesAddresses("USDC")));
        maxDeligation = maxDeligation.mul(50).div(100); //lower borrowing to avoid liquidations

        if(maxDeligation > totalDeligating) { //check if not deegating too much, probably paranoya
            totalDeligating = maxDeligation;
        }

        //quadratic distribution delegation to different communities
        _distribute(milestonesTemplate, totalDeligating);

        emit ThresholdReached(milestonesTemplate, msg.sender);
    }

    function _delegate (address _treasury, address _currency, uint256 _amount) internal {
        ILendingPool lendingPool = ILendingPool(ledningPoolAP.getLendingPool());
        address debtTokenAddress = lendingPool.getReserveData(_currency).variableDebtTokenAddress;
        ICreditDelegationToken(debtTokenAddress).approveDelegation(_treasury, _amount);

        emit Delegated(_treasury, _currency, _amount);
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
            if (projectsNum > 0) {
                unweigted[n] = QuadraticDistribution.calcUnweightedAlloc(currMilestones.popTotalCommunityContributions());
                n++;
                contributedNum++;
                didContribute[i] = true;
            }            
        }

        uint256[] memory weights = QuadraticDistribution.calcWeights(unweigted, contributedNum);

        uint256[] memory weighted = QuadraticDistribution.calcWeightedAlloc(_fund, weights);

        //and finally approve delegation
        n = 0;
        for (uint i = 0; i < milestonesNum; i++) {
            if (didContribute[i]) {
                _delegate(
                    milestonesTreasuries[milestones[i]], 
                    AddressesProvider(addressesProvider).currenciesAddresses("USDC"), 
                    weighted[n].div(1e12)
                ); 
                n++;
            }
        }
    }
}
