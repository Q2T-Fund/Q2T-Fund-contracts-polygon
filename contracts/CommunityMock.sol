//SPDX-License-Identifier: MIT
pragma solidity ^0.7.4;
pragma experimental ABIEncoderV2;

/**
 * @title Mock of DistributedTown Community
 *
 * @dev Implementation of the Community concept in the scope of the DistributedTown project
 * @author DistributedTown
 */

contract CommunityMock {  
    uint256 treasury = 2000;
    mapping (uint256 => address) projects;

    function metadataUri() public view returns(string memory) {
        string memory metadataUrl = "https://hub.textile.io/thread/bafkwfcy3l745x57c7vy3z2ss6ndokatjllz5iftciq4kpr4ez2pqg3i/buckets/bafzbeiaorr5jomvdpeqnqwfbmn72kdu7vgigxvseenjgwshoij22vopice";

        return metadataUrl;
    }

    function ownerId() public view returns(uint256) {
        return 0;
    }

    function activeMembersCount() public view returns(uint16) {
        return 1;
    }

    function isMember(address _member) public view returns(bool) {
        return true;
    }

    function milestones() public view returns(address) {
        return address(0);
    }

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
    ) public {}

    function join(uint256 skillWalletTokenId, uint256 credits) public {}

    function leave(address memberAddress) public {}

    function addProjectAddress(uint256 _projectId, address _projectAddress) public {
        projects[_projectId] = _projectAddress;
    }

    function getMembers() public view returns (uint256[] memory) {
        uint256[] memory members;

        return members;
    }

    function transferToTreasury(uint256 amount) public {
        treasury+=amount;

        if (treasury >= 3840) {
            treasury = 2000;
        }
    }

    function getTreasuryBalance() public view returns (uint256) {
        return treasury;
    }

    function getProjectTreasuryAddress(uint256 projectId) public view returns(address) {
        address projectAddress = projects[projectId];
        if (projectAddress == address(0)) {
            projectAddress = address(this);
        }
        return projectAddress;
    }
}
