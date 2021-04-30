//SPDX-License-Identifier: MIT
pragma solidity ^0.7.4;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/utils/Counters.sol";
import "./dito-contracts/Community.sol";
import "./dito-contracts/Projects.sol";

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

    enum MilestoneStatus {Open, Taken, Submitted, Completed}

    Counters.Counter milestoneId;

    struct Milestone {
        address creator;
        address taker;
        uint256 ditoCredits;
        MilestoneStatus status;
    }

    address public communityAddress;

    mapping(uint256 => Milestone) public milestones;
    mapping(uint256 => uint256[]) public projectMilestones;
    mapping(uint256 => bool) isValidated;
    Community community;
    Projects projects;

    constructor(address _communityAddress, address _projects)
        ERC721("Milestones", "MLST")
    {
        community = Community(_communityAddress);
        projects = Projects(_projects);
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
            creator,
            address(0),
            _ditoCredits,
            MilestoneStatus.Open
        );

        projectMilestones[_projectId].push(newMilestoneId);

        isValidated[newMilestoneId] = false;
        milestoneId.increment();

        emit MilestoneCreated(creator, newMilestoneId);
    }

    function takeMilestone(uint256 _milestoneId, address taker) public {
        require(
            milestones[_milestoneId].status == MilestoneStatus.Open,
            "This milestone is not open for being taken."
        );
        require(
            isValidated[_milestoneId],
            "Milestone creation not yet validated."
        );
        require(
            ownerOf(_milestoneId) != taker,
            "The creator can't take the gig"
        );
        require(
            community.isMember(taker),
            "The taker should be a community member."
        );

        milestones[_milestoneId].taker = taker;
        milestones[_milestoneId].status = MilestoneStatus.Taken;

        isValidated[_milestoneId] = false;

        emit MilestoneTaken(_milestoneId);
    }

    function submitMilestone(uint256 _milestoneId, address submitter) public {
        require(
            milestones[_milestoneId].status == MilestoneStatus.Taken,
            "This milestone is not yet taken."
        );
        require(
            isValidated[_milestoneId],
            "Milestone taken not yet validated."
        );
        require(
            milestones[_milestoneId].taker == submitter,
            "Only the taker can submit the gig!"
        );

        milestones[_milestoneId].status = MilestoneStatus.Submitted;

        isValidated[_milestoneId] = false;

        emit MilestoneSubmitted(_milestoneId);
    }

    function completeMilestone(uint256 _milestoneId, address completor) public {
        require(
            milestones[_milestoneId].status == MilestoneStatus.Submitted,
            "This milestone is not yet submitted."
        );
        require(
            isValidated[_milestoneId],
            "Milestone submission not yet validated."
        );
        require(
            milestones[_milestoneId].creator == completor,
            "Can be complete only by the creator."
        );

        milestones[_milestoneId].status = MilestoneStatus.Completed;
        isValidated[_milestoneId] = false;

        emit MilestoneCompleted(_milestoneId);
    }

    function validate(uint256 _milestoneId) public {
        // Chainlink validate hash
        isValidated[_milestoneId] = true;

        if (milestones[_milestoneId].status == MilestoneStatus.Completed) {
            community.transferToTreasury(milestones[_milestoneId].ditoCredits);
            emit MilestoneValidated(
                _milestoneId,
                true,
                milestones[_milestoneId].ditoCredits
            );
        } else {
            emit MilestoneValidated(_milestoneId, false, 0);
        }
    }

    function getMilestonesCount() public view returns (uint256) {
        return milestoneId.current();
    }
}
