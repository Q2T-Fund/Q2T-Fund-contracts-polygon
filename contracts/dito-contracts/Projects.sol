//SPDX-License-Identifier: MIT

pragma solidity ^0.7.4;

pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/token/ERC721/IERC721Metadata.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "./ProjectTreasury.sol";
import "./Community.sol";
import "./ISkillWallet.sol";

contract Projects is IERC721Metadata, ERC721 {
    event ProjectCreated(
        uint256 projectId,
        uint256 template,
        address communityAddress
    );

    using Counters for Counters.Counter;

    Counters.Counter private projectId;

    mapping(address => uint256[]) communityToTokenId;
    mapping(uint256 => uint256[]) templateProjects;
    mapping(uint256 => uint256[]) members;

    ProjectTreasury projectTreasury;
    ISkillWallet skillWallet;
    

    constructor(address _skillWalletAddress)
        ERC721("DiToProject", 'DITOPRJ')
    {
        projectTreasury = new ProjectTreasury();
        skillWallet = ISkillWallet(_skillWalletAddress);
    }

    function createProject(string memory _props, address _communityAddress, address creator) public {

        Community community = Community(_communityAddress);
        bool isRegistered = skillWallet.isSkillWalletRegistered(creator);
        require(isRegistered, 'Only a registered skill wallet can create a project.');

        uint256 skillWalletId = skillWallet.getSkillWalletIdByOwner(creator);
        bool isActive = skillWallet.isSkillWalletActivated(skillWalletId);
        require(isActive, 'Only an active skill wallet can create a project.');

        bool isMember = community.isMember(creator);
        require(isMember, 'Only a member of the community can create a project.');

        uint256 template = community.getTemplate();

        uint256 newProjectId = projectId.current();
        projectId.increment();

        _mint(creator, newProjectId);
        _setTokenURI(newProjectId, _props);

        communityToTokenId[_communityAddress].push(newProjectId);
        templateProjects[template].push(newProjectId);

        emit ProjectCreated(newProjectId, template, _communityAddress);
    }

    function getProjectTreasuryAddress() public view returns(address) {
        return address(projectTreasury);
    }

    function getCommunityProjects(address communityAddress) public view returns(uint256[] memory projectIds) {
        return communityToTokenId[communityAddress];
    }
}
