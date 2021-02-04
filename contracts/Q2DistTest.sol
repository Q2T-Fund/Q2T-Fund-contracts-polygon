//SPDX-License-Identifier: MIT
pragma solidity ^0.7.4;
pragma experimental ABIEncoderV2;

import "./QuadraticDistribution.sol";

contract Q2DistTest {
    function calcUnweightedAlloc(uint256[] memory _contributions) public pure returns (uint256) {
        return QuadraticDistribution.calcUnweightedAlloc(_contributions);
    }

    function calcWeights(uint256[] memory _unweightedAllocs) public pure returns (uint256[] memory) {
        return QuadraticDistribution.calcWeights(_unweightedAllocs);
    }

    function calcWeightedAlloc(uint256 _funds, uint256[] memory _weights) public pure returns (uint256[] memory)  {
        return QuadraticDistribution.calcWeightedAlloc(_funds, _weights);
    }
}