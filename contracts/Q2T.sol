//SPDX-License-Identifier: MIT
pragma solidity ^0.7.4;
pragma experimental ABIEncoderV2;

import "./AddressesProvider.sol";
import "./TemplatesTreasuries.sol";
import "./DataTypes.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC1155/ERC1155Holder.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "./ILendingPool.sol";
import "./IPriceOracle.sol";

contract Q2T is ERC1155Holder {
    using SafeMath for uint256;

    event ThresholdReached(uint256 _id);
    event Deposited(
        DataTypes.Template _template, 
        address _depositor, 
        string _currency, 
        uint256 _amount,
        uint256 _repaymentAmount,
        uint256 _aTokensAmount
    );
    event Delegated(
        DataTypes.Template _template,
        address _communityTreasury, 
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

    constructor(
        address _addressesProvider
    ) {
        require(_addressesProvider != address(0), "Addressess provider cannot be 0");

        addressesProvider = _addressesProvider;

        TemplatesTreasuries templatesTreasuriesContract = new TemplatesTreasuries("");
        templatesTreasuries = address(templatesTreasuriesContract);
        TemplatesTreasuries templatesReapayersTreasuriesContract = new TemplatesTreasuries("");
        templatesReapayersTreasuries = address(templatesReapayersTreasuriesContract);
    }

    function deposit(DataTypes.Template _template, uint256 _amount, uint256 _repayment) public {
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
        
        ILendingPool lendingPool = ILendingPool(
            ILendingPoolAddressesProvider(
                AddressesProvider(addressesProvider).lendingPoolAP()).getLendingPool());

        IERC20 aToken = IERC20(lendingPool.getReserveData(currencyAddress).aTokenAddress);
        uint256 aTokenBalanceBefore = aToken.balanceOf(address(this));

        currency.approve(address(lendingPool), q2tAmount);
        lendingPool.deposit(currencyAddress, q2tAmount, address(this), 0);

        uint256 aTokenReceived = aToken.balanceOf(address(this)).sub(aTokenBalanceBefore);

        if(TemplatesTreasuries(templatesTreasuries).balanceOf(address(this), uint256(_template)) == 0) {
            TemplatesTreasuries(templatesTreasuries).mint(_template, aTokenReceived);
        } else {
            TemplatesTreasuries(templatesTreasuries).addFunds(_template, aTokenReceived);
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

    function thresholdReached(uint256 _id) public override {
        require(msg.sender == communityTreasuries[_id], "wrong id");
        require(isTreasuryActive[msg.sender], "treasury is not active");

        IPriceOracle priceOracle = IPriceOracle(
            ILendingPoolAddressesProvider(
                AddressesProvider(addressesProvider).lendingPoolAP()).getPriceOracle());
        ILendingPool lendingPool = ILendingPool(
            ILendingPoolAddressesProvider(
                AddressesProvider(addressesProvider).lendingPoolAP()).getLendingPool());

        //delegation is for usdc for now
        (,,uint256 borrowingPower,,,) = lendingPool.getUserAccountData(address(this));
        uint256 totalDeligating = borrowingPower.div(
            priceOracle.getAssetPrice(
                AddressesProvider(addressesProvider).currenciesAddresses("USDC")));
        totalDeligating = totalDeligating.mul(80).div(100); //lower borrowing a bit to avoid liquidations

        //quadratic distribution delegation to different communities
        _distribute(totalDeligating.mul(1e18));

        emit ThresholdReached(_id);
    }
}