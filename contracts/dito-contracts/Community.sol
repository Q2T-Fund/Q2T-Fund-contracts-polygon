//SPDX-License-Identifier: MIT
pragma solidity ^0.7.4;
pragma experimental ABIEncoderV2;

import "./CommonTypes.sol";
import "./DITOCredit.sol";
import "./ISkillWallet.sol";
import "./Treasury.sol";
import "./DistributedTown.sol";

/**
 * @title DistributedTown Community
 *
 * @dev Implementation of the Community concept in the scope of the DistributedTown project
 * @author DistributedTown
 */

contract Community {
    string public metadataUri;

    uint256 public ownerId;
    uint16 public activeMembersCount;
    uint256 public scarcityScore;
    mapping(address => bool) public isMember;
    uint256[] public skillWalletIds;
    uint256 public tokenId;

    DITOCredit ditoCredit;
    ISkillWallet skillWallet;
    Treasury treasury;
    DistributedTown distributedTown;

    /**
     * @dev emitted when a member is added
     * @param _member the user which just joined the community
     * @param _transferredTokens the amount of transferred dito tokens on join
     **/
    event MemberAdded(
        address indexed _member,
        uint256 _skillWalletTokenId,
        uint256 _transferredTokens
    );
    event MemberLeft(address indexed _member);

    // add JSON Schema base URL
    constructor(string memory _url, address _skillWalletAddress) {
        metadataUri = _url;

        skillWallet = ISkillWallet(_skillWalletAddress);
        ditoCredit = new DITOCredit();
        treasury = new Treasury(address(ditoCredit));
        distributedTown = DistributedTown(address(msg.sender));

        // TODO: default skills value
        // TODO: replace the community template uri with the treasury one
        joinNewMember(address(treasury), 0, 0, 0, 0, 0, 0, _url, 2006 * 1e18);
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
        string memory uri,
        uint256 credits
    ) public {
        require(
            activeMembersCount <= 24,
            "There are already 24 members, sorry!"
        );

        Types.SkillSet memory skillSet =
            Types.SkillSet(
                Types.Skill(displayStringId1, level1),
                Types.Skill(displayStringId2, level2),
                Types.Skill(displayStringId3, level3)
            );

        skillWallet.create(newMemberAddress, skillSet, uri);
        uint256 tokenId = skillWallet.getSkillWalletIdByOwner(newMemberAddress);

        // get the skills from chainlink
        ditoCredit.addToWhitelist(newMemberAddress);
        ditoCredit.transfer(newMemberAddress, credits);

        skillWalletIds.push(tokenId);
        isMember[newMemberAddress] = true;
        activeMembersCount++;

        emit MemberAdded(newMemberAddress, tokenId, credits);
    }

    function join(uint256 skillWalletTokenId, uint256 credits) public {
        require(
            activeMembersCount <= 24,
            "There are already 24 members, sorry!"
        );
        address skillWalletAddress = skillWallet.ownerOf(skillWalletTokenId);

        require(!isMember[skillWalletAddress], "You have already joined!");


        // require(
        //     msg.sender == skillWalletAddress,
        //     "Only the skill wallet owner can call this function"
        // );

        isMember[skillWalletAddress] = true;
        skillWalletIds[activeMembersCount] = skillWalletTokenId;
        skillWalletIds[1] = 123;
        activeMembersCount++;

        ditoCredit.addToWhitelist(skillWalletAddress);
        ditoCredit.transfer(skillWalletAddress, credits);

        emit MemberAdded(skillWalletAddress, skillWalletTokenId, credits);
    }

    function leave(address memberAddress) public {
        emit MemberLeft(memberAddress);
    }

    function getMembers() public view returns (uint256[] memory) {
        return skillWalletIds;
    }

    // TODO: check called only by milestones!
    function transferToTreasury(uint256 amount) public {
        ditoCredit.transfer(address(treasury), amount);
        treasury.returnCreditsIfThresholdReached();
    }

    function getTokenId() public view returns (uint256) {
        uint256 tokenId = distributedTown.communityAddressToTokenID(address(this));
        return tokenId;
    }

    function getTemplate() public view returns (uint256) {
        uint256 tokenId = distributedTown.communityAddressToTokenID(address(this));
        uint256 templateId = distributedTown.communityToTemplate(tokenId);
        return templateId;
    }
    
    function getTreasuryBalance() public view returns (uint256) {
        return ditoCredit.balanceOf(address(treasury));
    }
}
