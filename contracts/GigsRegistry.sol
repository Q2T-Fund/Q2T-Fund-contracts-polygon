//SPDX-License-Identifier: MIT
pragma solidity ^0.7.4;

import "@openzeppelin/contracts/math/SafeMath.sol";
//import "@openzeppelin/contracts/access/Ownable.sol";

import "./Community.sol";
import {DataTypes} from './DataTypes.sol';
import "./IGigValidator.sol";

// WIP
contract GigsRegistry {
    using SafeMath for uint256;

    bytes4 public constant IDENTITY = 0x95fe5fc1;

    event MilestoneCreated(uint256 _id, address _project);
    event GigCreated(
        uint256 _id, 
        address _creator, 
        bytes32 _gigHash
    );
    event GigTaken(
        uint256 _id,
        address _taker,
        bytes32 _gigHash
    );
    event GigCompleted(
        uint256 _id,
        address _creator,
        address _taker,
        bytes32 _gigHash
    );

    mapping(uint256 => DataTypes.Gig) public gigs;
    uint256 public nextId;
    mapping(bytes32 => bool) public hashUsed;
    mapping(uint256 => address) public gigProjects;
    address public community;
    bytes32 public communityIdHash;
    IGigValidator public oracle;
    bool private oracleDisabled; //for local tests only

    constructor(address _community, string memory _communityId, address _oracle) {
        require(_oracle != address(0), "oracle is 0");

        community = _community;
        communityIdHash = keccak256(abi.encodePacked(_communityId));
        oracle = IGigValidator(_oracle);
        oracleDisabled = false; //true for local tests only; false for kovan or mainnet 
    }

    //for testing purposes to be removed
    function setCommunityId(string memory _communityId) public {
        communityIdHash = keccak256(abi.encodePacked(_communityId));
    }

    function createGig(bytes32 _gigHash) public {
        require(!hashUsed[_gigHash], "hash used");
        if (!oracleDisabled) {
            require(oracle.isFulfilled(), "oracle request not fulfilled");
            require(
                oracle.isValid() && 
                (oracle.gigHash() == _gigHash) &&
                (oracle.communityIdHash() == communityIdHash), 
                "hash not valid");
        }
        DataTypes.Gig memory gig = DataTypes.Gig(
            msg.sender,
            address(0),
            DataTypes.GigStatus.CREATED,
            false,
            _gigHash
        );
        gigs[nextId] = gig;
        hashUsed[_gigHash] = true;
        emit GigCreated(nextId, msg.sender, _gigHash);

        nextId = nextId.add(1);
    }

    function createMilestone(bytes32 _gigHash, address _project) public {
        require(_project != address(0), "milestone project address cannot be 0");

        DataTypes.Gig memory gig = DataTypes.Gig(
            msg.sender,
            address(0),
            DataTypes.GigStatus.CREATED,
            true,
            _gigHash
        );
        gigs[nextId] = gig;
        gigProjects[nextId] = _project;
        emit GigCreated(nextId, msg.sender, _gigHash);
        emit MilestoneCreated(nextId, _project);

        nextId = nextId.add(1);
    }

    function takeGig(uint256 _id) public {
        DataTypes.Gig memory gig = gigs[_id];
        require(gig.status == DataTypes.GigStatus.CREATED, "wrong gig status");

        gigs[_id].taker = msg.sender;
        gigs[_id].status = DataTypes.GigStatus.TAKEN;

        emit GigTaken(_id, msg.sender, gig.gigHash);
    }

    function completeGig(uint256 _id, address _gigCreator, bytes32 _gigHash, uint256 _amount) public {
        DataTypes.Gig memory gig = gigs[_id];
        require(gig.status == DataTypes.GigStatus.TAKEN, "wrong gig status");
        require(gig.creator == _gigCreator, "wrong creator");
        require(gig.gigHash == _gigHash, "wrong hash");

        address project = gig.isMilestone ? gigProjects[_id] : address(0);

        gigs[_id].status = DataTypes.GigStatus.COMPLETED;
        
        Community(community).completeGig(_amount, project);

        emit GigCompleted(_id, _gigCreator, gig.taker, _gigHash);
    }

    function gigIdLookup(address _gigCreator, bytes32 _gigHash) public view returns(uint256, bool) {
        if (nextId == 0) {
            return (0, false);
        }
        uint32 i = 0;

        while (
            i < nextId &&
            (gigs[i].gigHash != _gigHash ||
            gigs[i].creator != _gigCreator)
        ) {
            i = i + 1;
        }

        if (gigs[i].creator == _gigCreator && gigs[i].gigHash == _gigHash) {
            return (i, true);
        }

        return (0, false);
    }
}
