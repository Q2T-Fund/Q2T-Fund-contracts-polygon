//SPDX-License-Identifier: MIT
pragma solidity ^0.7.4;

import "./CommunityTreasury.sol";
import {DataTypes} from './DataTypes.sol';

contract CommunityTreasuryFactory {
    function deployTreasury(
        DataTypes.CommunityTemplate _template, 
        address _token,
        address _dao, 
        address _dai, 
        address _usdc, 
        address _lendingPoolAP
    ) public returns (address) {
        CommunityTreasury communityTreasury = new CommunityTreasury(
            _template, 
            _token,
            _dao,
            _dai,
            _usdc,
            _lendingPoolAP
        );
        communityTreasury.transferOwnership(msg.sender);

        return address(communityTreasury);
    }
}