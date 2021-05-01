//SPDX-License-Identifier: MIT
pragma solidity ^0.7.4;
pragma experimental ABIEncoderV2;

/**
 * @title Q2T Milestones interface
 *
 * @dev Interface to the Milestones contract in scope of Q2T project
 * @author DistributedTown/Q2T
 */

interface IMilestones {
    function getAllContributions() external view returns (uint256[] memory);
    function projectsNum() external view returns (uint256);
}