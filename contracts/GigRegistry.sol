//SPDX-License-Identifier: MIT
pragma solidity ^0.7.4;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

import "./Community.sol";
import {DataTypes} from './DataTypes.sol';

// WIP
contract GigsRegistry is Ownable {
    using SafeMath for uint256;

    event MilestoneCreated(uint256 _id, address _project);
    event GigCreated(uint256 _id, address _creator, bytes32 _gigIPFSHash);
    event GigCompleted(
        address _creator,
        address _gigCompleter,
        bytes32 _gigIPFSHash
    );

    mapping(uint256 => DataTypes.Gig) public gigs;
    uint256 public nextId;
    //mapping(address => uint256[]) createdGigs;
    mapping(uint256 => address) gigProjects;
    address public community;

    constructor() {
        community = msg.sender;
    }

    function createGig(bytes32 _gigHash) public {
        DataTypes.Gig memory gig = DataTypes.Gig(
            msg.sender,
            DataTypes.GigStatus.CREATED,
            false,
            _gigHash
        );
        gigs[nextId] = gig;
        //createdGigs[msg.sender].push(nextId);
        emit GigCreated(nextId, msg.sender, _gigHash);

        nextId = nextId.add(1);
    }

    function createMilestone(bytes32 _gigHash, address _project) public {
        require(_project != address(0), "milestone project address cannot be 0");

        DataTypes.Gig memory gig = DataTypes.Gig(
            msg.sender,
            DataTypes.GigStatus.CREATED,
            true,
            _gigHash
        );
        gigs[nextId] = gig;
        gigProjects[nextId] = _project;
        //createdGigs[msg.sender].push(nextId);
        emit GigCreated(nextId, msg.sender, _gigHash);
        emit MilestoneCreated(nextId, _project);

        nextId = nextId.add(1);
    }

    function completeGig(uint256 _id, address _gigCreator, bytes32 _gigHash, uint256 _amount) public {
        DataTypes.Gig memory gig = gigs[_id];
        require(gig.status == DataTypes.GigStatus.CREATED, "wrong gig status");
        require(gig.creator == _gigCreator, "wrong creator");
        require(gig.gigHash == _gigHash, "wrong hash");

        address project = gig.isMilestone ? gigProjects[_id] : address(0);

        gigs[_id].status = DataTypes.GigStatus.COMPLETED;
        
        Community(community).completeGig(_amount, project);
    }

    function gigIdLookup(address _gigCreator, bytes32 _gigHash) public view returns(uint256, bool) {
        if (nextId == 0) {
            return (0, false);
        }
        uint32 i = 0;

        while (
            i < nextId &&
            gigs[i].gigHash != _gigHash
        ) {
            i = i + 1;
        }

        if (gigs[i].creator == _gigCreator && gigs[i].gigHash == _gigHash) {
            return (i, true);
        }

        return (0, false);
    }
}
