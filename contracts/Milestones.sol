//SPDX-License-Identifier: MIT
pragma solidity ^0.7.4;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Metadata.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "./ICommunity.sol";
import "./MilestoneStatuses.sol";
import "./IQ2TTrigger.sol";

// TODO: figure out rates.
// TODO: transfer tokens.
// TODO: 1 milestones instance per community
contract Milestones is IERC721Metadata, ERC721 {
    using Counters for Counters.Counter;

    event MilestoneCreated(address _creator, uint256 _milestoneId);
    event MilestoneCompleted(uint256 _milestoneId);
    event MilestoneTaken(uint256 _milestoneId);
    event MilestoneSubmitted(uint256 _milestoneId);
    event MilestoneValidated(
        uint256 _milestoneId,
        bool transferedCredits,
        uint256 creditsTransfered
    );
    event DistributionTriggered(uint256 _milestoneId, uint256 _projectId);

    Counters.Counter milestoneId;

    struct Milestone {
        uint256 projectId;
        address creator;
        address taker;
        uint256 ditoCredits;
        MilestoneStatuses.MilestoneStatus status;
    }

    address public communityAddress;

    mapping(uint256 => Milestone) public milestones;
    mapping(uint256 => uint256[]) public projectMilestones;
    mapping(uint256 => bool) public isValidated;

    mapping(uint256 => uint256[]) contributionsPerProject;
    uint256[] public contributedProjects;
    uint256[] public totalContributions;
    address public q2t;
    bool public distributionInProgress;

    ICommunity community;

    constructor(address _communityAddress)
        ERC721("Milestones", "MLST")
    {
        //TODO: community and projects addresses checks
        community = ICommunity(_communityAddress);
        q2t = msg.sender;
        distributionInProgress = false;
    }

    function setQ2T(address _q2t) public {
        require(msg.sender == q2t, "Caller not Q2T");

        q2t = _q2t;
    }

    // in the metadata uri - skills, title, description
    function createMilestone(
        address creator,
        uint256 _ditoCredits,
        string memory _metadataUrl,
        uint256 _projectId
    ) public {
        // TODO: verify identity chainlink!
        require(
            community.isMember(creator),
            "The creator of the milestone should be a member of the community."
        );
        // TODO: Calculate credits with chainlink
        require(
            _ditoCredits >= 6 && _ditoCredits <= 720,
            "Invalid credits amount."
        );
        // TODO: check if project belongs to the same community

        uint256 newMilestoneId = milestoneId.current();

        _mint(creator, newMilestoneId);
        _setTokenURI(newMilestoneId, _metadataUrl);
        milestones[newMilestoneId] = Milestone(
            _projectId,
            creator,
            address(0),
            _ditoCredits,
            MilestoneStatuses.MilestoneStatus.Open
        );

        projectMilestones[_projectId].push(newMilestoneId);

        isValidated[newMilestoneId] = false;
        milestoneId.increment();

        emit MilestoneCreated(creator, newMilestoneId);
    }

    function takeMilestone(uint256 _milestoneId, address taker) public {
        require(
            ownerOf(_milestoneId) != taker,
            "The creator can't take the gig"
        );
        require(
            community.isMember(taker),
            "The taker should be a community member."
        );

        _changeStatus(_milestoneId, milestones[_milestoneId].status, MilestoneStatuses.MilestoneStatus.Taken);

        milestones[_milestoneId].taker = taker;

        emit MilestoneTaken(_milestoneId);
    }

    function submitMilestone(uint256 _milestoneId, address submitter) public {
        require(
            milestones[_milestoneId].taker == submitter,
            "Only the taker can submit the gig!"
        );

        _changeStatus(_milestoneId, milestones[_milestoneId].status, MilestoneStatuses.MilestoneStatus.Submitted);

        emit MilestoneSubmitted(_milestoneId);
    }

    function completeMilestone(uint256 _milestoneId, address completor) public {
        require(!distributionInProgress, "Distribution is in progress");

        require(
            milestones[_milestoneId].creator == completor,
            "Can be complete only by the creator."
        );

        _changeStatus(_milestoneId, milestones[_milestoneId].status, MilestoneStatuses.MilestoneStatus.Completed);

        emit MilestoneCompleted(_milestoneId);
    }

    function validate(uint256 _milestoneId) public {
        // Chainlink validate hash
        isValidated[_milestoneId] = true;
        Milestone memory milestone = milestones[_milestoneId];

        if (milestone.status == MilestoneStatuses.MilestoneStatus.Completed) {
            community.transferToTreasury(milestone.ditoCredits);
            uint256 treasuryBalance = community.getTreasuryBalance();
            if (treasuryBalance > 2000) {
                if (contributionsPerProject[milestone.projectId].length == 0) {
                    contributedProjects.push(milestone.projectId);
                }
                contributionsPerProject[milestone.projectId].push(milestone.ditoCredits);
                totalContributions.push(milestone.ditoCredits);
            } else {
                IQ2TTrigger(q2t).thresholdReached();
                distributionInProgress = true;

                emit DistributionTriggered(_milestoneId, milestone.projectId);
            }
            emit MilestoneValidated(
                _milestoneId,
                true,
                milestone.ditoCredits
            );
        } else {
            emit MilestoneValidated(_milestoneId, false, 0);
        }
    }

    // TODO: called only by Q2T?
    function popContributionsPerProject(uint256 projectId) public returns(uint256[] memory) {
        require(msg.sender == q2t, "Caller not Q2T");

        uint256[] memory contributions = contributionsPerProject[projectId];
        delete contributionsPerProject[projectId];
        return contributions;
    }

    function popTotalCommunityContributions() public returns(uint256[] memory) {
        require(msg.sender == q2t, "Caller not Q2T");

        uint256[] memory contributions = totalContributions;
        delete totalContributions;
        return contributions;
    }

    function popContributedProjects() public returns (uint256[] memory) {
        uint256[] memory prjcts = contributedProjects;
        delete contributedProjects;
        distributionInProgress = false;

        return prjcts;
    }

    function projectsNum() public view returns (uint256) {
        return contributedProjects.length;
    }

    function _changeStatus(
        uint256 _milestoneId,
        MilestoneStatuses.MilestoneStatus _from, 
        MilestoneStatuses.MilestoneStatus _to
    ) private {
        require (
            MilestoneStatuses.isTransitionAllowed(_from, _to), 
            "Status change not allowed"
        );

        require(
            isValidated[_milestoneId],
            "Milestone creation not yet validated."
        );

        milestones[_milestoneId].status = MilestoneStatuses.MilestoneStatus.Completed;
        isValidated[_milestoneId] = false;
    }

    function getCommunity() public view returns (address) {
        return address(community);
    }
}
