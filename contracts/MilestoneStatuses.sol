//SPDX-License-Identifier: MIT
pragma solidity ^0.7.4;

library MilestoneStatuses {
    enum MilestoneStatus {Open, Taken, Submitted, Completed}

    function isTransitionAllowed(MilestoneStatus _from, MilestoneStatus _to) public pure returns (bool) {
        if (_from == MilestoneStatus.Completed || _to == MilestoneStatus.Open) {
            return false;
        }

        return ((uint8(_from) + 1) == uint8(_to)); 
    }
}