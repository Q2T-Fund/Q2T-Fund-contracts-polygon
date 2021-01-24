//SPDX-License-Identifier: MIT
pragma solidity ^0.7.4;

interface ICommunityTreasury {
    function setTreasuryDAO(address _dao) external;
    function setCommunity(address _community) external;
    function completeGig(uint256 _amount) external;

    function deposit(address _currency, uint256 _amount) external;
    function withdraw(address _currency, uint256 _amount) external;
}