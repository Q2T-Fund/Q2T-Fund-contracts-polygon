//SPDX-License-Identifier: MIT
pragma solidity ^0.7.4;

import "./CommunityTreasuryNoAave.sol";

contract CommunityTreasuryFactoryNoAave {
    function deployTreasury(
        address _q2t,
        address _milestones, 
        address _addressesProvider 
    ) public returns (address) {
        CommunityTreasuryNoAave communityTreasury = new CommunityTreasuryNoAave(
            _q2t,
            _milestones, 
            _addressesProvider 
        );
        communityTreasury.transferOwnership(msg.sender);

        return address(communityTreasury);
    }
}