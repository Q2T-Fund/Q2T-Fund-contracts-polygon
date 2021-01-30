//SPDX-License-Identifier: MIT
pragma solidity ^0.7.4;

import "@openzeppelin/contracts/math/SafeMath.sol";

// WIP
contract GigsRegistry {
    event GigCreated(address _creator, bytes32 _gigIPFSHash);
    event GigCompleted(
        address _creator,
        address _gigCompleter,
        bytes32 _gigIPFSHash
    );

    mapping(address => bytes32[]) createdGigs;
    mapping(address => bytes32[]) completedGigs;

    function createGig(bytes32 _gigHash) public {
        createdGigs[msg.sender].push(_gigHash);
        emit GigCreated(msg.sender, _gigHash);
    }

    function completeGig(address _gigCreator, bytes32 _gigHash) public {
        uint32 i = 0;

        while (
            createdGigs[_gigCreator][i] != _gigHash &&
            i < createdGigs[_gigCreator].length
        ) {
            i = i + 1;
        }

        if (i == createdGigs[_gigCreator].length)
            revert("No gig with the passed hash");

        completedGigs[msg.sender].push(_gigHash);

        emit GigCompleted(_gigCreator, msg.sender, _gigHash);
    }
}
