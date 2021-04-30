//SPDX-License-Identifier: MIT
pragma solidity ^0.7.4;

import "@openzeppelin/contracts/utils/Counters.sol";
import "./IProject.sol";
import "./ICommunity.sol";

// TODO: figure out rates.
// TODO: transfer tokens.
// TODO: 1 milestones instance per community
contract Milestones {
    using Counters for Counters.Counter;

    event MilestoneCreated(address _creator, uint256 _milestoneId);
    event MilestoneCompleted(address _creator, address _milestoneCompleter, uint256 _milestoneId);
    event MilestoneTaken(address _creator, address _taker, uint256 _milestoneTaker);
    event MilestoneSubmitted(address _creator, address _milestoneSubmitter, uint256 _milestoneId);
    event MilestoneValidated(uint256 _milestoneId, address _creator, string _milestoneHash);

    enum MilestoneStatus {Open, Taken, Submitted, Completed}

    Counters.Counter milestoneId;

    struct Milestone {
        address owner;
        address taker;
        string milestoneHash;
        uint256 ditoCredits;
        MilestoneStatus status;
        uint16 rate;
    }

    address public community;
    address public projects;

    mapping(uint256 => Milestone) public milestones;
    mapping(address => uint256[]) ownersToMilestones;
    mapping(address => uint256[]) completedMilestones;
    mapping(uint256 => bool) isValidated;

    constructor (address _community, address _projects) {
        //TODO: check identities
        require(ICommunity(_community).milestones() == address(0), "Community already has milestones");
        community = _community;
        projects = _projects;
    }


    function createMilestone(uint256 ditoCredits) public {
        uint256 newMilestoneId = milestoneId.current();
        milestones[milestoneId.current()] = Milestone(
            msg.sender,
            address(0),
            "",
            ditoCredits,
            MilestoneStatus.Open,
            0
        );

        ownersToMilestones[msg.sender].push(
            newMilestoneId
        );
        isValidated[newMilestoneId] = false;
        milestoneId.increment();

        emit MilestoneCreated(msg.sender, newMilestoneId);
    }

    function takeMilestone(uint256 _milestoneId) public {
        require(
            milestones[_milestoneId].status == MilestoneStatus.Open,
            "This milestone is not open for being taken."
        );
        require(isValidated[_milestoneId], "Milestone creation not yet validated.");

        milestones[_milestoneId].taker = msg.sender;
        milestones[_milestoneId].status = MilestoneStatus.Taken;

        isValidated[_milestoneId] = false;

        emit MilestoneTaken(milestones[_milestoneId].owner, msg.sender, _milestoneId);
    }

    function submitMilestone(uint256 _milestoneId) public {
        require(
            milestones[_milestoneId].status == MilestoneStatus.Taken,
            "This milestone is not yet taken."
        );
        require(isValidated[_milestoneId], "Milestone taken not yet validated.");

        milestones[_milestoneId].status = MilestoneStatus.Submitted;

        isValidated[_milestoneId] = false;

        emit MilestoneSubmitted(milestones[_milestoneId].owner, msg.sender, _milestoneId);
    }

    function completeMilestone(uint256 _milestoneId, uint16 rate) public {
        require(
            milestones[_milestoneId].status == MilestoneStatus.Submitted,
            "This milestone is not yet submitted."
        );
        require(isValidated[_milestoneId], "Milestone submission not yet validated.");

        milestones[_milestoneId].status = MilestoneStatus.Completed;
        milestones[_milestoneId].rate = rate;

        completedMilestones[msg.sender].push(
            _milestoneId
        );

        isValidated[_milestoneId] = false;

        emit MilestoneCompleted(milestones[_milestoneId].owner, msg.sender, _milestoneId);
    }

    function validate(uint256 _milestoneId, string calldata _milestoneHash)
        public
    {
        // Chainlink validate hash
        isValidated[_milestoneId] = true;
        milestones[_milestoneId].milestoneHash = _milestoneHash;

        emit MilestoneValidated(_milestoneId, milestones[_milestoneId].owner, _milestoneHash);
    }

    function getOwnedMilestones(address owner) public view returns (uint256[] memory) {
        return ownersToMilestones[owner];
    }

    function getCompletedMilestones(address taker) public view returns (uint256[] memory) {
        return completedMilestones[taker];
    }
}
