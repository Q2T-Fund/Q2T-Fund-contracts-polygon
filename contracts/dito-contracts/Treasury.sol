//SPDX-License-Identifier: MIT
pragma solidity ^0.7.4;

import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";

import "./DITOCredit.sol";

/**
 * @title DistributedTown Community
 *
 * @dev Implementation of the Community concept in the scope of the DistributedTown project
 * @author DistributedTown
 */

contract Treasury is IERC721Receiver {
    DITOCredit private ditoCredits;
    address private communityAddress;

    constructor(address ditoCreditsAddress) {
        ditoCredits = DITOCredit(ditoCreditsAddress);
        communityAddress = msg.sender;
    }

    function returnCreditsIfThresholdReached() public {
        uint256 balance = ditoCredits.balanceOf(address(this));
        uint256 threshold = 3840 * 1e18;
        if (balance >= threshold) {
            ditoCredits.transfer(communityAddress, balance - 2006 * 1e18);
        }
    }

    /**
     * @dev See {IERC721Receiver-onERC721Received}.
     *
     * Always returns `IERC721Receiver.onERC721Received.selector`.
     */
    function onERC721Received(
        address,
        address,
        uint256,
        bytes memory
    ) public virtual override returns (bytes4) {
        return this.onERC721Received.selector;
    }
}
