//SPDX-License-Identifier: MIT
pragma solidity >=0.6.10 <0.8.0;

// WIP
interface IGigsRegistry {
    function IDENTITY() external view returns (bytes4);

    function confirmGig(bytes32 _gigHash) external returns (bool);
}
