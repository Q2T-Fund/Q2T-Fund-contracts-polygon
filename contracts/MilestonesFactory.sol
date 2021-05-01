//SPDX-License-Identifier: MIT
pragma solidity ^0.7.4;
pragma experimental ABIEncoderV2;

import "./Milestones.sol";

contract MilestonesFactory {
    function deployMilestones(address _communityAddress, address _projects) public returns (address) {
        Milestones milestones = new Milestones(_communityAddress, _projects);

        milestones.setQ2T(msg.sender);

        return address(milestones);
    }
}