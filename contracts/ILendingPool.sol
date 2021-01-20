//SPDX-License-Identifier: MIT
pragma solidity >=0.6.10 <0.8.0;

/**
@title ILendingPool interface
@notice provides the interface to fetch the LendingPool address
 */

abstract contract ILendingPool {
    function deposit(
        address,
        uint256,
        uint16
    ) external virtual payable;

    function getReserveData(address _reserve)
        external
        virtual
        view
        returns (
            uint256 totalLiquidity,
            uint256 availableLiquidity,
            uint256 totalBorrowsStable,
            uint256 totalBorrowsVariable,
            uint256 liquidityRate,
            uint256 variableBorrowRate,
            uint256 stableBorrowRate,
            uint256 averageStableBorrowRate,
            uint256 utilizationRate,
            uint256 liquidityIndex,
            uint256 variableBorrowIndex,
            address aTokenAddress,
            uint40 lastUpdateTimestamp
        );
}
