//SPDX-License-Identifier: MIT

pragma solidity ^0.7.4;

pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/token/ERC721/IERC721Metadata.sol";

interface IProject is IERC721Metadata {
    function communityToTokenId(address _community) external view returns (uint256);
    function tokenIdToCommunity(uint256 _tokenId) external view returns (address);
    function tokenIdToTemplate(uint256 _tokenId) external view returns (address);
    function members(uint256 _id) external view returns(address);

    function createProject(string memory _props, uint256 template) external;

    function joinProject() external;
}
