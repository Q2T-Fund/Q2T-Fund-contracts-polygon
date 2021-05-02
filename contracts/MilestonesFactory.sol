//SPDX-License-Identifier: MIT
pragma solidity ^0.7.4;

import "./Milestones.sol";

contract MilestonesFactory {
    function deployMilestones(address _communityAddress) public returns (address) {
        Milestones milestones = new Milestones(_communityAddress);

        milestones.setQ2T(msg.sender);

        return address(milestones);
    }
}