//SPDX-License-Identifier: MIT
pragma solidity ^0.7.4;

import "./CommunityTreasury.sol";
import {DataTypes} from './DataTypes.sol';
import "./AddressesProvider.sol";

contract CommunityTreasuryFactory {
    function deployTreasury(
        DataTypes.CommunityTemplate _template, 
        address _token,
        address _dao, 
        address _addressesProvider
    ) public returns (address) {
        CommunityTreasury communityTreasury = new CommunityTreasury(
            _template, 
            _token,
            _dao,
            AddressesProvider(_addressesProvider).currenciesAddresses("DAI"),
            AddressesProvider(_addressesProvider).currenciesAddresses("USDC"),
            AddressesProvider(_addressesProvider).lendingPoolAP()
        );
        communityTreasury.transferOwnership(msg.sender);

        return address(communityTreasury);
    }
}