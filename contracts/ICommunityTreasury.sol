//SPDX-License-Identifier: MIT
pragma solidity ^0.7.4;

import "./ITreasuryDao.sol";
import {DataTypes} from './DataTypes.sol';

interface ICommunityTreasury {
    event TreasuryDaoSet(address _dao);
    event CommunitySet(address _community);
    event IdSet(uint256 _id);
    event MilesoteComplete(uint256 _amount, address _project);
    event ThersholdReached(uint256 _amount);
    event Borrowed(string _currency, uint256 _amount);

    function dao() external view returns (ITreasuryDao);
    function template() external view returns (DataTypes.CommunityTemplate);
    function community() external view returns(address);

    function setTreasuryDAO(address _dao) external;
    function setCommunity(address _community) external;
    function setId(uint256 _id) external;
    function approveCommunity() external;
    function completeMilestone(uint256 _amount, address _project) external;
    function getDitoBalance() external view returns (uint256);
    function borrowDelegated(string memory _currency, uint256 _amount) external;

    function addTimelock() external;
    function activateTimelock() external;
    function fund(string memory _currency, uint256 _amount) external;
    function withdrawFunding(address _currency, uint256 _amount) external;
}