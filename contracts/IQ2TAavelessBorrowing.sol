//SPDX-License-Identifier: MIT
pragma solidity ^0.7.4;

interface IQ2TAavelessBorrowing {
    function borrow(address _currency) external returns (uint256);
}