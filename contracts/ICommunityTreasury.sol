//SPDX-License-Identifier: MIT
pragma solidity ^0.7.4;

import "./ITreasuryDao.sol";

interface ICommunityTreasury {
    function dao() external view returns (ITreasuryDao);

    function setTreasuryDAO(address _dao) external;
    function setCommunity(address _community) external;
    function setId(uint256 _id) external;
    function approveCommunity() external;
    function completeGig(uint256 _amount) external;

    function deposit(string memory _currency, uint256 _amount) external;
    function withdraw(address _currency, uint256 _amount) external;
}