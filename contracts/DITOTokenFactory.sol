//SPDX-License-Identifier: MIT
pragma solidity >=0.6.10 <0.8.0;

import "./DITOToken.sol";

contract DITOTokenFactory {
    function deployToken(uint256 _initTokens) public returns (address) {
        DITOToken newToken = new DITOToken(_initTokens, msg.sender);
        newToken.transferOwnership(msg.sender);

        return address(newToken);
    }
}