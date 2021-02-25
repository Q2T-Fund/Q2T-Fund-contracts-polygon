//SPDX-License-Identifier: MIT
pragma solidity ^0.7.4;

interface IGigValidator {  
    function isValid() external view returns (bool);
    function isFulfilled() external view returns (bool);
    function isRequested() external view returns (bool);
    function gigHash() external view returns (bytes32);
    function communityIdHash() external view returns (bytes32);
    
    function requestIsGigValid(string memory _community, bytes32 _hash, string memory _mockIsValid) external returns (bytes32 requestId);
}