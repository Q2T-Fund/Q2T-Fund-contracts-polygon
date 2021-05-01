//SPDX-License-Identifier: MIT
pragma solidity ^0.7.4;

contract AddressesProvider {
    //address public communityTreasuryFactory;
    //address public ditoTokenFactory;
    //address public gigsRegistryFactory;
    //address public oracle;

    address public lendingPoolAP;
    mapping(string => address) public currenciesAddresses;

    constructor(
        address _dai,
        address _usdc,
        //address _communityTreasuryFactory,
        //address _ditoTokenFactory,
        //address _gigsRegistryFactory,
        //address _oracle,
        address _lendingPoolAP
    ) {
        //communityTreasuryFactory = _communityTreasuryFactory;
        //ditoTokenFactory = _ditoTokenFactory;
        //gigsRegistryFactory = _gigsRegistryFactory;
        //oracle = _oracle;
        lendingPoolAP = _lendingPoolAP;

        currenciesAddresses["DAI"] = _dai;
        currenciesAddresses["USDC"] = _usdc;
    }
}