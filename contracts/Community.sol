//SPDX-License-Identifier: MIT
pragma solidity ^0.7.4;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

import "./gsn/BaseRelayRecipient.sol";

import "./ILendingPoolAddressesProvider.sol";
import "./ILendingPool.sol";
import "./IAToken.sol";
import "./IFiatTokenV2.sol";
import "./CommunityTreasury.sol";
import "./GigsRegistry.sol";
import {DataTypes} from './DataTypes.sol';

import "./DITOToken.sol";
//import "./WadRayMath.sol";

/**
 * @title DistributedTown Community
 *
 * @dev Implementation of the Community concept in the scope of the DistributedTown project
 * @author DistributedTown
 */
contract Community is BaseRelayRecipient, Ownable {
    string public override versionRecipient = "2.0.0";

    using SafeMath for uint256;
    //using WadRayMath for uint256;

    /**
     * @dev emitted when a member is added
     * @param _member the user which just joined the community
     * @param _transferredTokens the amount of transferred dito tokens on join
     **/
    event MemberAdded(address _member, uint256 _transferredTokens);
    /**
     * @dev emitted when a member leaves the community
     * @param _member the user which just left the community
     **/
    event MemberRemoved(address _member);
    event IdSet(uint256 _id);
    event TreasurySet(address _treasury);

    uint256 public constant INIT_TOKENS = 96000;
    
    // The address of the DITOToken ERC20 contract
    DITOToken public tokens;

    uint256 public id;
    bool idSet;
    DataTypes.CommunityTemplate public template;
    mapping(address => bool) public enabledMembers;
    uint256 public numberOfMembers;
    mapping(string => address) public depositableCurrenciesContracts;
    string[] public depositableCurrencies;
    CommunityTreasury public communityTreasury;
    GigsRegistry public gigsRegistry;
    ILendingPoolAddressesProvider public lendingPoolAP;

    // Get the forwarder address for the network
    // you are using from
    // https://docs.opengsn.org/gsn-provider/networks.html
    // 0x25CEd1955423BA34332Ec1B60154967750a0297D is ropsten's one
    constructor(
        DataTypes.CommunityTemplate _template, 
        address _dai,
        address _usdc,
        address _lendingPoolAP, 
        address _forwarder
    ) {
        idSet = false;
        template = _template;
        trustedForwarder = _forwarder;
        lendingPoolAP = ILendingPoolAddressesProvider(_lendingPoolAP);

        tokens = new DITOToken(INIT_TOKENS.mul(1e18));
        communityTreasury = new CommunityTreasury(
            template, 
            address(tokens),
            msg.sender,
            _dai,
            _usdc,
            _lendingPoolAP
        );

        _join(address(communityTreasury), 2000, true);
        communityTreasury.approveCommunity();

        depositableCurrencies.push("DAI");
        depositableCurrencies.push("USDC");

        depositableCurrenciesContracts["DAI"] = _dai;
        depositableCurrenciesContracts["USDC"] = _usdc;
    }

    function setGigsRegistry(address _gigRegistry) public onlyOwner {
        require(address(gigsRegistry) == address(0), "already added");
        require(GigsRegistry(_gigRegistry).community() == address(this), "wrong community");

        gigsRegistry = GigsRegistry(_gigRegistry);
    }

    function setId(uint256 _id) public {
        require(msg.sender == address(communityTreasury), "not treasury");
        require(!idSet, "already set");

        id = _id;
        idSet = true;

        emit IdSet(_id);
    }

    function setTreasuryDAO(address _dao) public onlyOwner {
        communityTreasury.setTreasuryDAO(_dao);
    }

    /**
     * @dev makes the calling user join the community if required conditions are met
     * @param _amountOfDITOToRedeem the amount of dito tokens for which this user is eligible
     **/
     function join(uint256 _amountOfDITOToRedeem) public {
         _join(_msgSender(), _amountOfDITOToRedeem, false);
     }

    function _join(address _member, uint256 _amountOfDITOToRedeem, bool _isTreasury) internal {
        require(address(communityTreasury) != address(0), "treasury not set");
        require(numberOfMembers < 25, "community full"); //1st member is community treasure so there can actually be 25 members
        require(enabledMembers[_member] == false, "already member");

        enabledMembers[_member] = true;
        numberOfMembers = numberOfMembers.add(1);
        tokens.addToWhitelist(_member, _isTreasury);

        tokens.transfer(_member, _amountOfDITOToRedeem.mul(1e18));

        emit MemberAdded(_member, _amountOfDITOToRedeem);
    }

    /**
     * @dev makes the calling user leave the community if required conditions are met
     **/
    function leave() public {
        _leave(_msgSender(), false);
    }

    function _leave(address _member, bool _isTreasury) private {
        _onlyMember(_member);

        enabledMembers[_member] = false;
        numberOfMembers = numberOfMembers.sub(1);

        // leaving user must first give allowance
        // then can call this
        tokens.transferFrom(
            _member,
            address(this),
            tokens.balanceOf(_member)
        );

        tokens.removeFromWhitelist(_member, _isTreasury);

        emit MemberRemoved(_member);
    }



    function completeGig(uint256 _amount, address _project) public {
        require(_msgSender() == address(gigsRegistry), "not gig registry");

        if(_project != address(0)) {
            tokens.approve(address(communityTreasury), _amount.mul(1e18));
            communityTreasury.completeMilestone(_amount, _project);   
        }
    }

    function activateTreasuryTimelock() public onlyOwner {
        communityTreasury.activateTimelock();
    }
    

    function _msgSender() internal view override(Context, BaseRelayRecipient) returns (address payable) {
        return BaseRelayRecipient._msgSender();
    }

    function _msgData() internal view override(Context, BaseRelayRecipient) returns (bytes memory) {
        return BaseRelayRecipient._msgData();
    }

    function _onlyMember(address _member) internal view {
        require(
            enabledMembers[_member] == true,
            "not member"
        );
    }

    function _onlyEnabledCurrency(string memory _currency) internal view {
        require(
            depositableCurrenciesContracts[_currency] != address(0),
            "not supported currency"
        );
    }
}
