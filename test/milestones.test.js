const { ethers } = require("hardhat");
const { use, expect } = require("chai");
const { solidity } = require("ethereum-waffle");

use(solidity);

describe("Milestones", function () {

  let skillWalletInstance;
  let communityInstance;
  let milestonesInstance;
  let provider;
  let accounts;
  let memberAccount1;
  let memberAccount2;
  let memberTokenId1;
  let memberTokenId2;
  let projectId;
  let communityAddress;

  before(async function () {
    accounts = await ethers.getSigners();
    account0 = accounts[0];
    account1 = accounts[1];
    memberAccount1 = accounts[2];
    memberAccount2 = accounts[3];

    // Deploy instances
    const DistributedTownFactory = await ethers.getContractFactory("DistributedTown");
    const ProjectFactory = await ethers.getContractFactory("Projects");
    const SkillWalletFactory = await ethers.getContractFactory("SkillWallet");
    const CommunityFactory = await ethers.getContractFactory("Community");
    const MilestonesFactory = await ethers.getContractFactory("Milestones");

    skillWalletInstance = await SkillWalletFactory.deploy();
    await skillWalletInstance.deployed();

    provider = skillWalletInstance.provider;

    let blockNumber = await provider.getBlockNumber();
    console.log("Current block number", blockNumber);

    distributedTownInstance = await DistributedTownFactory.deploy('http://someurl.co', skillWalletInstance.address);
    await distributedTownInstance.deployed();
    await distributedTownInstance.deployGenesisCommunities();

    const communityAddresses = await distributedTownInstance.getCommunities();
    communityAddress = communityAddresses[0];
    communityInstance = await CommunityFactory.attach(communityAddresses[0]);
    const memberTx1 = await communityInstance.joinNewMember(memberAccount1.address, 1, 1, 2, 2, 3, 3, 'http://someuri.co', 2006);
    const txReceipt1 = await memberTx1.wait();

    const memberAddedEvent1 = txReceipt1.events.find(txReceiptEvent => txReceiptEvent.event === 'MemberAdded');
    memberTokenId1 = memberAddedEvent1.args[1];
    console.log('member joined', memberTokenId1);

    const memberTx2 = await communityInstance.joinNewMember(memberAccount2.address, 1, 1, 2, 2, 3, 3, 'http://someuri.co', 2006);
    const txReceipt2 = await memberTx2.wait();

    const memberAddedEvent2 = txReceipt2.events.find(txReceiptEvent => txReceiptEvent.event === 'MemberAdded');
    memberTokenId2 = memberAddedEvent2.args[1];
    console.log('member joined', memberTokenId2);

    await skillWalletInstance.activateSkillWallet(memberTokenId1);
    await skillWalletInstance.activateSkillWallet(memberTokenId2);

    projectsInstance = await ProjectFactory.deploy(skillWalletInstance.address);
    await projectsInstance.deployed();
    const metadataUrl = "https://hub.textile.io/thread/bafkwfcy3l745x57c7vy3z2ss6ndokatjllz5iftciq4kpr4ez2pqg3i/buckets/bafzbeiaorr5jomvdpeqnqwfbmn72kdu7vgigxvseenjgwshoij22vopice";
    const projectTx = await projectsInstance.createProject(
      metadataUrl,
      communityAddresses[0],
      memberAccount1.address
    );

    const projectTxReceipt = await projectTx.wait();

    const projectCreatedEvent = projectTxReceipt.events.find(txReceiptEvent => txReceiptEvent.event === 'ProjectCreated');
    projectId = projectCreatedEvent.args[0];

    milestonesInstance = await MilestonesFactory.deploy(communityAddresses[0], projectsInstance.address);
    await milestonesInstance.deployed();

  })
  describe.only("Milestones", function () {

    describe("createMilestone()", async function () {
      it("Should create a milestone", async function () {
        const metadataUrl = "https://hub.textile.io/thread/bafkwfcy3l745x57c7vy3z2ss6ndokatjllz5iftciq4kpr4ez2pqg3i/buckets/bafzbeiaorr5jomvdpeqnqwfbmn72kdu7vgigxvseenjgwshoij22vopice";

        const tx = await milestonesInstance.createMilestone(
          memberAccount1.address,
          6,
          metadataUrl,
          projectId
        );

        const txReceipt = await tx.wait();
        const milestoneCreatedEvent = txReceipt.events.find(txReceiptEvent => txReceiptEvent.event === 'MilestoneCreated');
        const creator = milestoneCreatedEvent.args[0];
        const tokenId = milestoneCreatedEvent.args[1];

        const uri = await milestonesInstance.tokenURI(tokenId);
        const owner = await milestonesInstance.ownerOf(tokenId);

        expect(uri).to.eq(metadataUrl);
        expect(owner).to.eq(creator);
        expect(owner).to.eq(memberAccount1.address);
      });

      it("Should take a milestone", async function () {
        const metadataUrl = "https://hub.textile.io/thread/bafkwfcy3l745x57c7vy3z2ss6ndokatjllz5iftciq4kpr4ez2pqg3i/buckets/bafzbeiaorr5jomvdpeqnqwfbmn72kdu7vgigxvseenjgwshoij22vopice";

        let tx = await milestonesInstance.createMilestone(
          memberAccount1.address,
          6,
          metadataUrl,
          projectId
        );

        let txReceipt = await tx.wait();
        const milestoneCreatedEvent = txReceipt.events.find(txReceiptEvent => txReceiptEvent.event === 'MilestoneCreated');
        const creator = milestoneCreatedEvent.args[0];
        const tokenId = milestoneCreatedEvent.args[1];

        await milestonesInstance.validate(tokenId);

        tx = await milestonesInstance.takeMilestone(
          tokenId,
          memberAccount2.address
        );

        txReceipt = await tx.wait();
        const milestoneTakenEvents = txReceipt.events.find(txReceiptEvent => txReceiptEvent.event === 'MilestoneTaken');
        const milestone = await milestonesInstance.milestones(tokenId);

        expect(milestone.taker).to.eq(memberAccount2.address);
        expect(milestone.creator).to.eq(memberAccount1.address);
        expect(milestone.status).to.eq(1);
        expect(milestoneTakenEvents).to.not.null;
      });

      it("Should submit a milestone", async function () {
        const metadataUrl = "https://hub.textile.io/thread/bafkwfcy3l745x57c7vy3z2ss6ndokatjllz5iftciq4kpr4ez2pqg3i/buckets/bafzbeiaorr5jomvdpeqnqwfbmn72kdu7vgigxvseenjgwshoij22vopice";

        let tx = await milestonesInstance.createMilestone(
          memberAccount1.address,
          6,
          metadataUrl,
          projectId
        );

        let txReceipt = await tx.wait();
        const milestoneCreatedEvent = txReceipt.events.find(txReceiptEvent => txReceiptEvent.event === 'MilestoneCreated');
        const creator = milestoneCreatedEvent.args[0];
        const tokenId = milestoneCreatedEvent.args[1];

        await milestonesInstance.validate(tokenId);

        tx = await milestonesInstance.takeMilestone(
          tokenId,
          memberAccount2.address
        );

        txReceipt = await tx.wait();
        const milestoneTakenEvents = txReceipt.events.find(txReceiptEvent => txReceiptEvent.event === 'MilestoneTaken');
        expect(milestoneTakenEvents).to.not.null;

        await milestonesInstance.validate(tokenId);

        tx = await milestonesInstance.submitMilestone(
          tokenId,
          memberAccount2.address
        );

        txReceipt = await tx.wait();
        const milestoneSubmittedEvents = txReceipt.events.find(txReceiptEvent => txReceiptEvent.event === 'MilestoneSubmitted');
        expect(milestoneSubmittedEvents).to.not.null;

        const milestone = await milestonesInstance.milestones(tokenId);
        expect(milestone.taker).to.eq(memberAccount2.address);
        expect(milestone.creator).to.eq(memberAccount1.address);
        expect(milestone.status).to.eq(2);

      });


      it("Should complete a milestone", async function () {
        const metadataUrl = "https://hub.textile.io/thread/bafkwfcy3l745x57c7vy3z2ss6ndokatjllz5iftciq4kpr4ez2pqg3i/buckets/bafzbeiaorr5jomvdpeqnqwfbmn72kdu7vgigxvseenjgwshoij22vopice";

        let tx = await milestonesInstance.createMilestone(
          memberAccount1.address,
          6,
          metadataUrl,
          projectId
        );

        let txReceipt = await tx.wait();
        const milestoneCreatedEvent = txReceipt.events.find(txReceiptEvent => txReceiptEvent.event === 'MilestoneCreated');
        const creator = milestoneCreatedEvent.args[0];
        const tokenId = milestoneCreatedEvent.args[1];

        await milestonesInstance.validate(tokenId);

        tx = await milestonesInstance.takeMilestone(
          tokenId,
          memberAccount2.address
        );

        txReceipt = await tx.wait();
        const milestoneTakenEvents = txReceipt.events.find(txReceiptEvent => txReceiptEvent.event === 'MilestoneTaken');
        expect(milestoneTakenEvents).to.not.null;

        await milestonesInstance.validate(tokenId);

        tx = await milestonesInstance.submitMilestone(
          tokenId,
          memberAccount2.address
        );

        txReceipt = await tx.wait();
        const milestoneSubmittedEvents = txReceipt.events.find(txReceiptEvent => txReceiptEvent.event === 'MilestoneSubmitted');
        expect(milestoneSubmittedEvents).to.not.null;

        let milestone = await milestonesInstance.milestones(tokenId);
        expect(milestone.taker).to.eq(memberAccount2.address);
        expect(milestone.creator).to.eq(memberAccount1.address);
        expect(milestone.status).to.eq(2);

        await milestonesInstance.validate(tokenId);

        tx = await milestonesInstance.completeMilestone(
          tokenId,
          memberAccount1.address
        );
        txReceipt = await tx.wait();
        milestone = await milestonesInstance.milestones(tokenId);
        const milestoneCompletedEvents = txReceipt.events.find(txReceiptEvent => txReceiptEvent.event === 'MilestoneCompleted');
        expect(milestoneCompletedEvents).to.not.null;
        expect(milestone.status).to.eq(3);

      });

      it("Should transfer the credits after validation", async function () {
        const metadataUrl = "https://hub.textile.io/thread/bafkwfcy3l745x57c7vy3z2ss6ndokatjllz5iftciq4kpr4ez2pqg3i/buckets/bafzbeiaorr5jomvdpeqnqwfbmn72kdu7vgigxvseenjgwshoij22vopice";

        let tx = await milestonesInstance.createMilestone(
          memberAccount1.address,
          6,
          metadataUrl,
          projectId
        );

        let txReceipt = await tx.wait();
        const milestoneCreatedEvent = txReceipt.events.find(txReceiptEvent => txReceiptEvent.event === 'MilestoneCreated');
        const creator = milestoneCreatedEvent.args[0];
        const tokenId = milestoneCreatedEvent.args[1];

        await milestonesInstance.validate(tokenId);

        tx = await milestonesInstance.takeMilestone(
          tokenId,
          memberAccount2.address
        );

        txReceipt = await tx.wait();
        const milestoneTakenEvents = txReceipt.events.find(txReceiptEvent => txReceiptEvent.event === 'MilestoneTaken');
        expect(milestoneTakenEvents).to.not.null;

        await milestonesInstance.validate(tokenId);

        tx = await milestonesInstance.submitMilestone(
          tokenId,
          memberAccount2.address
        );

        txReceipt = await tx.wait();
        const milestoneSubmittedEvents = txReceipt.events.find(txReceiptEvent => txReceiptEvent.event === 'MilestoneSubmitted');
        expect(milestoneSubmittedEvents).to.not.null;

        let milestone = await milestonesInstance.milestones(tokenId);
        expect(milestone.taker).to.eq(memberAccount2.address);
        expect(milestone.creator).to.eq(memberAccount1.address);
        expect(milestone.status).to.eq(2);

        await milestonesInstance.validate(tokenId);

        tx = await milestonesInstance.completeMilestone(
          tokenId,
          memberAccount1.address
        );

        txReceipt = await tx.wait();
        const milestoneCompletedEvents = txReceipt.events.find(txReceiptEvent => txReceiptEvent.event === 'MilestoneCompleted');
        expect(milestoneCompletedEvents).to.not.null;
        milestone = await milestonesInstance.milestones(tokenId);
        expect(milestone.status).to.eq(3);

        const validationTx = await milestonesInstance.validate(tokenId);
        const validationTxReceipt = await validationTx.wait();
        const milestoneValidatedEvents = validationTxReceipt.events.find(txReceiptEvent => txReceiptEvent.event === 'MilestoneValidated');

        expect(milestoneValidatedEvents).to.not.null;
        expect(milestoneValidatedEvents.args[0]).to.eq(tokenId);
        expect(milestoneValidatedEvents.args[1]).to.eq(true);
        expect(milestoneValidatedEvents.args[2].toString()).to.eq('6');
        expect(milestoneValidatedEvents).to.not.null;
        expect(milestone.status).to.eq(3);


      });

    })
  });
});
