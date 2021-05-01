//SPDX-License-Identifier: MIT
pragma solidity ^0.7.4;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC1155/ERC1155Holder.sol";
import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155MetadataURI.sol";
import "@openzeppelin/contracts/token/ERC1155/ERC1155Receiver.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "./Community.sol";
import "./ISkillWallet.sol";

/**
 * @title DistributedTown Community
 *
 * @dev Implementation of the Community concept in the scope of the DistributedTown project
 * @author DistributedTown
 */

contract DistributedTown is ERC1155, ERC1155Holder {
    event CommunityCreated(
        address communityContract,
        uint256 communityId,
        uint256 template,
        address indexed creator
    );
    using Counters for Counters.Counter;

    Counters.Counter private communityTokenIds; 

    mapping(address => uint256) public communityAddressToTokenID;
    mapping(uint256 => uint256) public communityToTemplate;
    address[] public communities;

    address private skillWalletAddress;
    ISkillWallet skillWallet;
    bool genesisCommunitiesCreated;

    // TODO Add JSON Schema base URL
    constructor(string memory _url, address _skillWalletAddress) ERC1155(_url) {
        // initialize pos values of the 3 templates;
        skillWalletAddress = _skillWalletAddress;
        skillWallet = ISkillWallet(_skillWalletAddress);
        genesisCommunitiesCreated = false;
    }

    // function createCommunity(string calldata communityMetadata, uint256 template)
    //     public
    // {

    //     bool isRegistered = skillWallet.isSkillWalletRegistered(msg.sender);
    //     require(isRegistered, 'SW not registered.');

    //     uint256 skillWalletId = skillWallet.getSkillWalletIdByOwner(msg.sender);
    //     bool isActive = skillWallet.isSkillWalletActivated(skillWalletId);
    //     require(isActive, 'SW not active.');

    //     // TODO: add check for validated skills;
    //     _mint(address(this), template, 1, "");

    //     communityTokenIds.increment();
    //     uint256 newItemId = communityTokenIds.current();

    //     // check if skill wallet is active
    //     // TODO: add skill wallet address
    //     Community community = new Community(communityMetadata, skillWalletAddress);
    //     communityAddressToTokenID[address(community)] = newItemId;
    //     communityToTemplate[newItemId] = template;
    //     communities.push(address(community));

    //     //TODO: add the creator as a community member
    //     emit CommunityCreated(
    //         address(community),
    //         newItemId,
    //         template,
    //         msg.sender
    //     );
    // }

    function transferToMember(address _to, uint256 _value) public {
        
    }

    function transferToCommunity(address _from, uint256 _value) public {
        
    }

    function safeTransferFrom(
        address _from,
        address _to,
        uint256 _id,
        uint256 _value,
        bytes calldata _data
    ) public override {
        
    }

    function safeBatchTransferFrom(
        address _from,
        address _to,
        uint256[] calldata _ids,
        uint256[] calldata _values,
        bytes calldata _data
    ) public override {
        
    }

    function balanceOf(address _owner, uint256 _id)
        public
        view
        override
        returns (uint256)
    {
    }

    function balanceOfBatch(address[] calldata _owners, uint256[] calldata _ids)
        public
        view
        override
        returns (uint256[] memory)
    {
    }

    function setApprovalForAll(address _operator, bool _approved)
        public
        override
    {
        
    }

    function isApprovedForAll(address _owner, address _operator)
        public
        view
        override
        returns (bool)
    {
        
    }

    function getCommunities() public view returns(address[] memory) {
        return communities;
    }

    function deployGenesisCommunities() public {

        require(!genesisCommunitiesCreated, 'Genesis communities already created');
        
        // check if skill wallet is active
        // TODO: add skill wallet address
        communityTokenIds.increment();
        uint256 newItemId = communityTokenIds.current();
        _mint(address(this), 0, 1, "");
        Community openSourceCommunity = new Community('', skillWalletAddress);
        communityAddressToTokenID[address(openSourceCommunity)] = newItemId;
        communityToTemplate[newItemId] = 0;
        communities.push(address(openSourceCommunity));


        communityTokenIds.increment();
        newItemId = communityTokenIds.current();
        _mint(address(this), 1, 1, "");
        Community artCommunity = new Community('', skillWalletAddress);
        communityAddressToTokenID[address(artCommunity)] = newItemId;
        communityToTemplate[newItemId] = 1;
        communities.push(address(artCommunity));


        communityTokenIds.increment();
        newItemId = communityTokenIds.current();
        _mint(address(this), 2, 1, "");
        Community localCommunity = new Community('', skillWalletAddress);
        communityAddressToTokenID[address(localCommunity)] = newItemId;
        communityToTemplate[newItemId] = 2;
        communities.push(address(localCommunity));

        genesisCommunitiesCreated = true;
        emit CommunityCreated(
            address(localCommunity),
            newItemId,
            2,
            msg.sender
        );
    }
}
