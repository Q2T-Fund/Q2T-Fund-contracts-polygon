//SPDX-License-Identifier: MIT
pragma solidity ^0.7.4;
pragma experimental ABIEncoderV2;

import "./ICommunityTreasury.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";

contract WithdrawTimelock {
    using SafeMath for uint256;

    uint256 private constant _TIMELOCK = 150 days;
    
    mapping(address => mapping(address => mapping(uint256 => uint256))) public withdrawable; //funder => asset => time => amount
    mapping(address => uint256[]) public timelocks;
    address public treasury;
    bool public active;

    constructor(address _treasury) {
        treasury = _treasury;
        ICommunityTreasury(treasury).addTimelock();
    }

    function deposit(address _funder, address _asset, uint256 _amount) public {
        uint256 lockUntil = (block.timestamp + _TIMELOCK);
        uint256 depositsNum = timelocks[_funder].length;
        uint256 lastDepostiTime;
        if (depositsNum == 0) {
            lastDepostiTime = 0;
        } else {
            lastDepostiTime = timelocks[_funder][depositsNum - 1];
        }

        //some rounding here to save storage
        if(lastDepostiTime > (lockUntil - 1 days)) {
            lockUntil = lastDepostiTime;           
        } else {
            timelocks[_funder].push(lockUntil);
        }
 
        withdrawable[_funder][_asset][lockUntil] = withdrawable[_funder][_asset][lockUntil].add(_amount);
    }

    function canWithdraw(address _funder, address _asset) public view returns (uint256) {
        uint256[] memory funderTimelocks = timelocks[_funder];
        
        if (funderTimelocks.length == 0) {
            return 0;
        }

        uint256 withdrawableAmount = 0;
        uint256 timestamp = block.timestamp;
        uint256 i = 0;

        while (
            i < funderTimelocks.length &&
            funderTimelocks[i] <= timestamp
        ) {
            withdrawableAmount = withdrawableAmount.add(
                withdrawable[_funder][_asset][funderTimelocks[i]]
            );
        }

        return withdrawableAmount;
    }

    function withdrawableByLock(address _funder, address _asset, uint256 _lock) public view returns (uint256) {
        return withdrawable[_funder][_asset][_lock];
    }

    function getTimelocksCount(address _funder) public view returns (uint256) {
        return timelocks[_funder].length;
    }
}