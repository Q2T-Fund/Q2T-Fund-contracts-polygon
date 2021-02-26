//SPDX-License-Identifier: MIT
pragma solidity ^0.7.4;

import "./Community.sol";
import "./ITreasuryDao.sol";
import "./DataTypes.sol";

/**
 * @title DistributedTown CommunitiesRegistry
 *
 * @dev Implementation of the CommunitiesRegistry contract, which is a Factory and Registry of Communities
 * @author DistributedTown
 */
contract CommunitiesRegistry {
    event CommunityCreated(address _newCommunityAddress, DataTypes.CommunityTemplate _template);

    bytes4 public constant IDENTITY = 0x94635046;

    mapping (DataTypes.CommunityTemplate => address) daos;
    mapping (DataTypes.CommunityTemplate => address[]) public communities;

    address dai;
    address usdc;
    address lendingPoolAP;
    address forwarder;
    address gigValidator;

    constructor(
        address _dai,
        address _usdc,
        address _gigValidator,
        address _lendingPoolAP,
        address _forwarder
    ) {
        dai = _dai;
        usdc = _usdc;
        lendingPoolAP = _lendingPoolAP;
        gigValidator = _gigValidator;
        forwarder = _lendingPoolAP;
    }

    /**
     * @dev Creates a community
     * @return _communityAddress the newly created Community address
     **/
    function createCommunity(DataTypes.CommunityTemplate _template) public returns (address) {
        address dao = daos[_template];
        require(dao != address(0), "dao not set");

        Community newCommunity = new Community(
            _template,
            dai,
            usdc,
            lendingPoolAP,
            forwarder
        );

        address newCommunityAddress = address(newCommunity);
        //addCommunity(newCommunityAddress, _template);
        communities[_template].push(newCommunityAddress);

        newCommunity.setTreasuryDAO(dao);
        ITreasuryDao(dao).linkCommunity(address(newCommunity.communityTreasury()));
        
        emit CommunityCreated(newCommunityAddress, _template);

        return newCommunityAddress;
    }

    /**
     * @dev Adds a community to the registry
     * @param _communityAddress the address of the community to add
     **/
    /*function addCommunity(address _communityAddress, DataTypes.CommunityTemplate _template) public {
        communities[_template].push(_communityAddress);
    }*/

    /**
     * @dev Gets the current community of a user
     * @param _user the address of user to check
     * @return communityAddress the address of the community of the user if existent, else 0 address
     **/
    function currentCommunityOfUser(address _user, DataTypes.CommunityTemplate _template)
        public
        view
        returns (address communityAddress)
    {
        uint256 i = 0;
        bool userFound = false;
        address[] memory templateCommunities = communities[_template];

        while (!userFound && i < templateCommunities.length) {
            Community community = Community(templateCommunities[i]);
            userFound = community.enabledMembers(_user);

            i++;
        }

        if (!userFound) return address(0);

        return address(templateCommunities[i - 1]);
    }
}
