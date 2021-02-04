//SPDX-License-Identifier: MIT
pragma solidity ^0.7.4;

interface IGigValidator {  
    function isValid() external returns (bool);
    function isFulfilled() external returns (bool);
    function gigHash() external returns (bytes32);
    
    /**
     * Create a Chainlink request to retrieve API response, find the target
     * data, then multiply by 1000000000000000000 (to remove decimal places from data).
     */
    function requestIsGigValid(string memory _community, bytes32 _hash, string memory _mockIsValid) external returns (bytes32 requestId);
}