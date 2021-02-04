//SPDX-License-Identifier: MIT
pragma solidity ^0.7.4;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/math/SafeMath.sol";

library QuadraticDistribution {
    using SafeMath for uint256;
    
    function calcUnweightedAlloc(uint256[] memory _contributions) internal pure returns (uint256) {
        uint256 unweightedAlloc = 0;

        for (uint256 i = 0; i < _contributions.length; i++) {
            unweightedAlloc = unweightedAlloc.add(sqrt(_contributions[i]));
        }

        return unweightedAlloc.mul(unweightedAlloc);
    }

    function calcWeights(uint256[] memory _unweightedAllocs) internal pure returns (uint256[] memory) {
        uint256 allocSum = 0;
        uint256[] memory weights = new uint256[](_unweightedAllocs.length);

        for (uint256 i = 0; i < _unweightedAllocs.length; i++) {
            allocSum = allocSum.add(_unweightedAllocs[i]);
        }

        allocSum = allocSum.div(1000000); //extra zeroes after 100 represent digits after do in percentages

        for (uint256 i = 0; i < _unweightedAllocs.length; i++) {
            weights[i] = _unweightedAllocs[i].div(allocSum);
        }

        return weights;
    }

    function calcWeightedAlloc(uint256 _funds, uint256[] memory _weights) internal pure returns (uint256[] memory) {
        uint256 fundsAdj = _funds.div(1000000);
        uint256[] memory weightedAlloc = new uint256[](_weights.length);

        for (uint256 i = 0; i < _weights.length; i++) {
            weightedAlloc[i] = fundsAdj.mul(_weights[i]);
        }

        return weightedAlloc;
    }

    function sqrt(uint y) internal pure returns (uint z) {
        if (y > 3) {
            z = y;
            uint x = y / 2 + 1;
            while (x < z) {
                z = x;
                x = (y / x + x) / 2;
            }
        } else if (y != 0) {
            z = 1;
        }
    }
}