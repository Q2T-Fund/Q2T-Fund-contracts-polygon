//SPDX-License-Identifier: MIT
pragma solidity ^0.7.4;

import "./GigsRegistry.sol";

contract GigsRegistryFactory {
    function deployGigsRegistry(string memory _communityId, address _oracle) public returns (address) {
        GigsRegistry newGigsRegistry = new GigsRegistry(
            msg.sender,
            _communityId,
            _oracle
        );

        return address(newGigsRegistry);
    }
}