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
    function projectsNum() external view returns (uint256);
    function popTotalCommunityContributions() external returns(uint256[] memory);
    function popContributionsPerProject(uint256 projectId) external returns(uint256[] memory);
    function popContributedProjects() external returns (uint256[] memory);
}