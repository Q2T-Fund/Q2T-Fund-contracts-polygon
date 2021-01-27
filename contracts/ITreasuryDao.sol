//SPDX-License-Identifier: MIT
pragma solidity ^0.7.4;

import {DataTypes} from './DataTypes.sol';

interface ITreasuryDao {
    function setCommunityTreasury(address _communityTreasury, DataTypes.CommunityType _type) external;
    function thresholdReached(DataTypes.CommunityType _type) external;

    function deposit(address _currency, uint256 _amount, DataTypes.CommunityType _type) external;
    function withdraw(address _currency, uint256 _amount) external;
    function delegate(address _currency, uint256 _amount, address _deligatee) external;
    function undelegate(address _currency, address _deligatee, bool _force) external; //_force to undelegate even if there is outstanding borrowed amt
    
    function getDeligateeCount(address _currency) external returns (uint256);
    function getDeligatee(address _currency, uint256 _id) external returns (address);
    function getDeligateeBorrowedAmount(address _currency, address _deligatee) external returns (uint256);
    
    function getTreasuryBalance(address _currency) external returns (uint256);
    function getTreasuryBorrowedBalance(address _currency) external returns (uint256);
    function getBalance(address _currency, address _member) external returns (uint256);
}