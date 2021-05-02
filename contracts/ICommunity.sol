//SPDX-License-Identifier: MIT
pragma solidity ^0.7.4;
pragma experimental ABIEncoderV2;

/**
 * @title DistributedTown Community
 *
 * @dev Implementation of the Community concept in the scope of the DistributedTown project
 * @author DistributedTown
 */

interface ICommunity {    
    function metadataUri() external view returns(string memory);
    function ownerId() external view returns(uint256);
    function activeMembersCount() external view returns(uint16);
    function isMember(address _member) external view returns(bool);
    function milestones() external view returns(address);

    // check if it's called only from deployer.
    function joinNewMember(
        address newMemberAddress,
        uint64 displayStringId1,
        uint8 level1,
        uint64 displayStringId2,
        uint8 level2,
        uint64 displayStringId3,
        uint8 level3,
        string calldata uri,
        uint256 credits
    ) external;

    function join(uint256 skillWalletTokenId, uint256 credits) external;

    function leave(address memberAddress) external;

    function getMembers() external view returns (uint256[] memory);

    function transferToTreasury(uint256 amount) external;

    function getTreasuryBalance() external view returns (uint256);

    function getProjectTreasuryAddress(uint256 projectId) external view returns(address);
}
