//SPDX-License-Identifier: MIT
pragma solidity ^0.7.4;

import "./CommunityTreasury.sol";

contract CommunityTreasuryFactory {
    function deployTreasury(
        address _q2t,
        address _milestones, 
        address _addressesProvider 
    ) public returns (address) {
        CommunityTreasury communityTreasury = new CommunityTreasury(
            _q2t,
            _milestones, 
            _addressesProvider 
        );
        communityTreasury.transferOwnership(msg.sender);

        return address(communityTreasury);
    }
}