//SPDX-License-Identifier: MIT
pragma solidity ^0.7.4;

import "./AddressesProvider.sol";
import "./TemplateTreasury.sol";
import "./DataTypes.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./ILendingPool.sol";

contract Q2T {
    address public addressesProvider;
    address public templateRepayerTreasuryAddress;
    address public templateTreasuryAddress;
    mapping (DataTypes.Template => uint256) public templateRepayerTreasuryNFTs;
    mapping (DataTypes.Template => uint256) public templateTreasuryNFTs;
    uint256 public totalQ2TFund;
    uint256 public totalRepayerFund;

    function deposit(DataTypes.Template _template, uint256 _amount, uint256 _repayment) public override {
        address currencyAddress = AddressesProvider(addressesProvider).currenciesAddresses("DAI");
        
        IERC20 currency = IERC20(currencyAddress);
        //uint256 amount = _amount.mul(1e18);
        require(
            currency.balanceOf(msg.sender) >= _amount,
            "You don't have enough funds to invest."
        );
        
        currency.transferFrom(msg.sender, address(this), _amount);

        uint256 q2tAmount = _amount.sub(_repayment);

        if(templateTreasuryNFTs[_template] == 0) {
            templateTreasuryNFTs[_template] = TemplateTreasury(templateTreasuryAddress).mint(_amount);
        }

        if(templateRepayerTreasuryNFTs[_template] == 0) {
            templateRepayerTreasuryNFTs[_template] = TemplateTreasury(templateRepayerTreasuryAddress).mint(_repayment);
        }


        
        ILendingPool lendingPool = ILendingPool(aaveProtocolDataProvider.ADDRESSES_PROVIDER().getLendingPool());

        currency.transferFrom(msg.sender, address(this), amount);
        currency.approve(address(lendingPool), amount);
        lendingPool.deposit(currencyAddress, amount, address(this), 0);
        repayableAmount[msg.sender][currencyAddress] = repayableAmount[msg.sender][currencyAddress].add(amount.mul(_repayment).div(100));
        depositors[msg.sender] = depositors[msg.sender].add(amount);
        totalDeposited = totalDeposited.add(amount);

        emit Deposited(msg.sender, _currency, _amount);
    }
}