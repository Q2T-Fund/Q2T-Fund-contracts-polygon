const { expect } = require("chai");
const addresses = require("../addresses");
const hre = require("hardhat");
const { ethers } = require("hardhat");
require('dotenv').config();

const network = hre.network.name;
const e18 = "000000000000000000";
const MAX_UINT = "115792089237316195423570985008687907853269984665640564039457584007913129639935";

let signer;
let token;
let communityTreasury;
let community;
let gigsRegistry;
let timelock;
let gigValidator;
let ditoTokenFactory;
let milestones;
let communityTreasuryFactory;
let milestonesFactory;
let communityMocks = [];
let q2t;
let templatesTreasuries;
let templatesReapayersTreasuries;
let addressesProvider;

const memberAccount1 = {
    address: "0x1111111111111111111111111111111111111111"
};
const memberAccount2 = {
    address: "0x2222222222222222222222222222222222222222"
};
const projectIds = [0];

const forwarder_address = addresses[network].forwarder;
const dai = addresses[network].dai;
const adai = addresses[network].adai;
const stableDebtDai = addresses[network].stableDebtDai;
const usdc = addresses[network].usdc;
const stableDebtUsdc = addresses[network].stableDebtUsdc;
const variableDebtUsdc = addresses[network].variableDebtUsdc;
const landingPoolAP = addresses[network].landingPoolAP;
const chainlink = addresses[network].chainlink;

const gigHashIncompl = "0xB3B3886F389F27BC1F2A41F0ADD45A84453F0D2A877FCD1225F13CD95953A86";
const gigProject = "0x111111111111111111111111111111111111111f";

describe("Deposit and borrow happy flow", function() {
    describe("Deployment", function () {
        /*it("Should deploy gig validator (oracle)", async function () {
            const GigValidator = await ethers.getContractFactory("GigValidator");
            gigValidator = await GigValidator.deploy(chainlink.address, ethers.utils.toUtf8Bytes(chainlink.jobId));
            await gigValidator.deployed();
    
            expect(gigValidator.address).not.to.be.undefined;
        });*/
        it("Should deploy contract factories", async function() {
            const CommunityTreasuryFactory = await ethers.getContractFactory("CommunityTreasuryFactory");
            communityTreasuryFactory = await CommunityTreasuryFactory.deploy();
            await communityTreasuryFactory.deployed();

            const MilestonesLib = await ethers.getContractFactory("MilestoneStatuses");
            const milestonesLib = await MilestonesLib.deploy();
            await milestonesLib.deployed();
            
            const MilestonesFactory = await ethers.getContractFactory("MilestonesFactory", {
                libraries: {
                    MilestoneStatuses: milestonesLib.address
                }
            });
            milestonesFactory = await MilestonesFactory.deploy();
            await milestonesFactory.deployed();

            expect(milestonesFactory.address).not.to.be.undefined;
            expect(communityTreasuryFactory.address).not.to.be.undefined;
        });
        it("Should deploy addresses provider and communities registry", async function() {
            const AddressesProvider = await ethers.getContractFactory("AddressesProvider");
            addressesProvider = await AddressesProvider.deploy(
                dai,
                usdc,
                milestonesFactory.address,
                communityTreasuryFactory.address,
                landingPoolAP,
            );
            await addressesProvider.deployed();

            expect(addressesProvider.address).not.to.be.undefined;
            expect((await addressesProvider.currenciesAddresses("DAI")).toLowerCase()).to.equal(dai);
            expect((await addressesProvider.currenciesAddresses("USDC")).toLowerCase()).to.equal(usdc);
        });
        it("Should deploy Q2T contract", async function() {
            const Q2T = await ethers.getContractFactory("Q2T");
            q2t = await Q2T.deploy(addressesProvider.address);
            await q2t.deployed();
            
            expect(q2t.address).not.to.be.undefined;
        });
        it("Should have deployed Template Treasuries along with Q2T", async function() {
            templatesTreasuries = await q2t.templatesTreasuries();
            templatesReapayersTreasuries = await q2t.templatesReapayersTreasuries();

            expect(templatesTreasuries).not.to.equal("0x0000000000000000000000000000000000000000");
            expect(templatesReapayersTreasuries).not.to.equal("0x0000000000000000000000000000000000000000");
            expect(templatesTreasuries).not.to.equal(templatesReapayersTreasuries);

        });
    });
    describe("Milestones contract creation", function () {
        before(async function() {
            //deploy some mock communities
            const CommunityMock =  await ethers.getContractFactory("CommunityMock");
            for (let i = 0; i < 3 ; i++) {
                const communityMock = await CommunityMock.deploy();
                await communityMock.deployed();

                communityMocks.push(communityMock.address);
            }
        });
        it("Should deploy new milestones and community treasury", async function() {
            const createMilestonesTx = await q2t.deployMilestones(1, communityMocks[0]);
            const events = (await createMilestonesTx.wait()).events?.filter((e) => {
                return e.event == "MilestonesDeployed"
            });
          
            milestones = await ethers.getContractAt("Milestones", events[0].args._milestones);

            expect(await q2t.milestonesTreasuries(milestones.address)).not.to.equal("0x0000000000000000000000000000000000000000");
            expect(await q2t.temapltesMilestones(1, 0)).to.equal(milestones.address);
            expect(await q2t.communitiesMilestones(communityMocks[0])).to.equal(milestones.address);

            expect(await q2t.getMilestonesPerTemplate(1)).to.equal("1");
            expect(await q2t.getMilestonesPerTemplate(2)).to.equal("0");
            expect(await q2t.getMilestonesPerTemplate(3)).to.equal("0");
        });
        it("Should not allow to deploy more than one milestones contract per community", async function() {
            expect(q2t.deployMilestones(1, communityMocks[0])).to.be.revertedWith("Milestones already deployed");
        });
        it("Should not allow to deploy milestone with template 0 (NONE)", async function() {
            expect(q2t.deployMilestones(0, communityMocks[1])).to.be.revertedWith("Template not specified");
        });
        it("Should deploy more than one milestones contract treasury for the same template", async function() {
            const createMilestonesTx = await q2t.deployMilestones(1, communityMocks[1]);
            const events = (await createMilestonesTx.wait()).events?.filter((e) => {
                return e.event == "MilestonesDeployed"
            });

            const milestones2 = events[0].args._milestones;

            expect(await q2t.temapltesMilestones(1, 1)).to.equal(milestones2);
            expect(await q2t.temapltesMilestones(1, 0)).to.equal(milestones.address);
            expect(await q2t.communitiesMilestones(communityMocks[1])).to.equal(milestones2);

            expect(await q2t.getMilestonesPerTemplate(1)).to.equal("2");
            expect(await q2t.getMilestonesPerTemplate(2)).to.equal("0");
            expect(await q2t.getMilestonesPerTemplate(3)).to.equal("0");
        });
        it("Should deploy milestones contract treasury for another template", async function() {
            const createMilestonesTx = await q2t.deployMilestones(3, communityMocks[2]);

            const events = (await createMilestonesTx.wait()).events?.filter((e) => {
                return e.event == "MilestonesDeployed"
            });

            const milestones2 = events[0].args._milestones;

            expect(await q2t.temapltesMilestones(3, 0)).to.equal(milestones2);
            expect(await q2t.temapltesMilestones(1, 0)).to.equal(milestones.address);
            expect(await q2t.communitiesMilestones(communityMocks[2])).to.equal(milestones2);

            expect(await q2t.getMilestonesPerTemplate(1)).to.equal("2");
            expect(await q2t.getMilestonesPerTemplate(2)).to.equal("0");
            expect(await q2t.getMilestonesPerTemplate(3)).to.equal("1");
        });
    });
    describe("Basic flow", function() {
        before(async function() {
            //need to send some gas funds to impersonated acc
            const [ , sender ]  = await ethers.getSigners(); 
            await sender.sendTransaction({
                to: process.env.IMPERSONATE, 
                value: ethers.utils.parseEther("10.0")
            });
        })
        it("Should deposit DAI through Q2T dao to aave for template 1", async function() {
            await hre.network.provider.request({
                method: "hardhat_impersonateAccount",
                params: [process.env.IMPERSONATE]
            });
    
            signer = await ethers.provider.getSigner(process.env.IMPERSONATE);
    
            /*const Erc20 = await ethers.getContractFactory("ERC20", signer);
            const daiToken = Erc20.attach(dai);
            const adaiToken = Erc20.attach(adai);*/

            const daiToken = await ethers.getContractAt("IERC20", dai, signer);
            const adaiToken = await ethers.getContractAt("IERC20", adai, signer);
    
            const Q2T = await ethers.getContractFactory("Q2T", signer);
            const q2tImp = Q2T.attach(q2t.address);
    
            await daiToken.approve(q2tImp.address, "1000".concat(e18));
            await q2tImp.deposit(1, "1000".concat(e18), 30);
    
            expect(await adaiToken.balanceOf(q2tImp.address)).to.equal("700".concat(e18));
            expect(await daiToken.balanceOf(q2tImp.address)).to.equal("300".concat(e18));
        });
        it("Should have issued treasury NFT for template 1 and assigned funds to it", async function() {
            const templatesTreasuriesAddress = await q2t.templatesTreasuries();
            const templatesTreasuries = await ethers.getContractAt("TemplatesTreasuriesWithReserves", templatesTreasuriesAddress);
            const templatesReapayersTreasuriesAddress = await q2t.templatesReapayersTreasuries();
            const templatesReapayersTreasuries = await ethers.getContractAt("TemplatesTreasuries", templatesReapayersTreasuriesAddress);

            expect(await templatesTreasuries.balanceOf(q2t.address, 1)).to.equal("1");
            expect(await templatesTreasuries.balanceOf(q2t.address, 2)).to.equal("0");
            expect(await templatesTreasuries.balanceOf(q2t.address, 3)).to.equal("0");
            expect(await templatesTreasuries.getCurrentFund(1)).to.equal("700".concat(e18)); 
            expect(await templatesTreasuries.getCurrentFund(2)).to.equal("0");
            expect(await templatesTreasuries.getCurrentFund(3)).to.equal("0");
           
            expect(await templatesTreasuries.balanceOf(q2t.address, 4)).to.equal("0");
            expect(await templatesTreasuries.balanceOf(q2t.address, 5)).to.equal("0");
            expect(await templatesTreasuries.balanceOf(q2t.address, 6)).to.equal("0");
            expect(await templatesTreasuries.getCurrentReserve(1)).to.equal("0");
            expect(await templatesTreasuries.getCurrentReserve(2)).to.equal("0");
            expect(await templatesTreasuries.getCurrentReserve(3)).to.equal("0");

            expect(await templatesReapayersTreasuries.balanceOf(q2t.address, 1)).to.equal("1");
            expect(await templatesReapayersTreasuries.balanceOf(q2t.address, 2)).to.equal("0");
            expect(await templatesReapayersTreasuries.balanceOf(q2t.address, 3)).to.equal("0");
            expect(await templatesReapayersTreasuries.getCurrentFund(1)).to.equal("300".concat(e18));
            expect(await templatesReapayersTreasuries.getCurrentFund(2)).to.equal("0");
            expect(await templatesReapayersTreasuries.getCurrentFund(3)).to.equal("0");
        });
        it("Should deposit more DAI through Q2T dao to aave for template 1", async function() {
            await hre.network.provider.request({
                method: "hardhat_impersonateAccount",
                params: [process.env.IMPERSONATE]
            });
    
            signer = await ethers.provider.getSigner(process.env.IMPERSONATE);
    
            /*const Erc20 = await ethers.getContractFactory("ERC20", signer);
            const daiToken = Erc20.attach(dai);
            const adaiToken = Erc20.attach(adai);*/

            const daiToken = await ethers.getContractAt("IERC20", dai, signer);
            const adaiToken = await ethers.getContractAt("IERC20", adai, signer);
    
            const Q2T = await ethers.getContractFactory("Q2T", signer);
            const q2tImp = Q2T.attach(q2t.address);
    
            await daiToken.approve(q2tImp.address, "600".concat(e18));
            await q2tImp.deposit(1, "600".concat(e18), 50);

            expect(String(await adaiToken.balanceOf(q2tImp.address)).slice(0,4)).to.equal("1000");
            expect(await daiToken.balanceOf(q2tImp.address)).to.equal("600".concat(e18));
        });
        it("Should NOT have issued  newtreasury NFT for template 1 and used existing one", async function() {
            const templatesTreasuriesAddress = await q2t.templatesTreasuries();
            const templatesTreasuries = await ethers.getContractAt("TemplatesTreasuriesWithReserves", templatesTreasuriesAddress);
            const templatesReapayersTreasuriesAddress = await q2t.templatesReapayersTreasuries();
            const templatesReapayersTreasuries = await ethers.getContractAt("TemplatesTreasuries", templatesReapayersTreasuriesAddress);

            expect(await templatesTreasuries.balanceOf(q2t.address, 1)).to.equal("1");
            expect(await templatesTreasuries.balanceOf(q2t.address, 2)).to.equal("0");
            expect(await templatesTreasuries.balanceOf(q2t.address, 3)).to.equal("0");
            expect(String(await templatesTreasuries.getCurrentFund(1)).slice(0, 4)).to.equal("1000"); 
            expect(await templatesTreasuries.getCurrentFund(2)).to.equal("0");
            expect(await templatesTreasuries.getCurrentFund(3)).to.equal("0");
           
            expect(await templatesTreasuries.balanceOf(q2t.address, 4)).to.equal("0");
            expect(await templatesTreasuries.balanceOf(q2t.address, 5)).to.equal("0");
            expect(await templatesTreasuries.balanceOf(q2t.address, 6)).to.equal("0");
            expect(await templatesTreasuries.getCurrentReserve(1)).to.equal("0");
            expect(await templatesTreasuries.getCurrentReserve(2)).to.equal("0");
            expect(await templatesTreasuries.getCurrentReserve(3)).to.equal("0");

            expect(await templatesReapayersTreasuries.balanceOf(q2t.address, 1)).to.equal("1");
            expect(await templatesReapayersTreasuries.balanceOf(q2t.address, 2)).to.equal("0");
            expect(await templatesReapayersTreasuries.balanceOf(q2t.address, 3)).to.equal("0");
            expect(await templatesReapayersTreasuries.getCurrentFund(1)).to.equal("600".concat(e18));
            expect(await templatesReapayersTreasuries.getCurrentFund(2)).to.equal("0");
            expect(await templatesReapayersTreasuries.getCurrentFund(3)).to.equal("0");
        });
        it("Should deposit DAI through Q2T dao to aave for template 3", async function() {
            await hre.network.provider.request({
                method: "hardhat_impersonateAccount",
                params: [process.env.IMPERSONATE]
            });
    
            signer = await ethers.provider.getSigner(process.env.IMPERSONATE);
    
            /*const Erc20 = await ethers.getContractFactory("ERC20", signer);
            const daiToken = Erc20.attach(dai);
            const adaiToken = Erc20.attach(adai);*/

            const daiToken = await ethers.getContractAt("IERC20", dai, signer);
            const adaiToken = await ethers.getContractAt("IERC20", adai, signer);
    
            const Q2T = await ethers.getContractFactory("Q2T", signer);
            const q2tImp = Q2T.attach(q2t.address);
    
            await daiToken.approve(q2tImp.address, "100".concat(e18));
            await q2tImp.deposit(3, "100".concat(e18), 30);
    
            expect(String(await adaiToken.balanceOf(q2tImp.address)).slice(0,4)).to.equal("1070");
            expect(await daiToken.balanceOf(q2tImp.address)).to.equal("630".concat(e18));
        });
        it("Should have issued treasury NFT for template 3 and assigned funds to it", async function() {
            const templatesTreasuriesAddress = await q2t.templatesTreasuries();
            const templatesTreasuries = await ethers.getContractAt("TemplatesTreasuriesWithReserves", templatesTreasuriesAddress);
            const templatesReapayersTreasuriesAddress = await q2t.templatesReapayersTreasuries();
            const templatesReapayersTreasuries = await ethers.getContractAt("TemplatesTreasuries", templatesReapayersTreasuriesAddress);

            expect(await templatesTreasuries.balanceOf(q2t.address, 1)).to.equal("1");
            expect(await templatesTreasuries.balanceOf(q2t.address, 2)).to.equal("0");
            expect(await templatesTreasuries.balanceOf(q2t.address, 3)).to.equal("1");
            expect(String(await templatesTreasuries.getCurrentFund(1)).slice(0, 4)).to.equal("1000"); 
            expect(await templatesTreasuries.getCurrentFund(2)).to.equal("0");
            expect(String(await templatesTreasuries.getCurrentFund(3)).slice(0, 4)).to.equal("7000");
           
            expect(await templatesTreasuries.balanceOf(q2t.address, 4)).to.equal("0");
            expect(await templatesTreasuries.balanceOf(q2t.address, 5)).to.equal("0");
            expect(await templatesTreasuries.balanceOf(q2t.address, 6)).to.equal("0");
            expect(await templatesTreasuries.getCurrentReserve(1)).to.equal("0");
            expect(await templatesTreasuries.getCurrentReserve(2)).to.equal("0");
            expect(await templatesTreasuries.getCurrentReserve(3)).to.equal("0");

            expect(await templatesReapayersTreasuries.balanceOf(q2t.address, 1)).to.equal("1");
            expect(await templatesReapayersTreasuries.balanceOf(q2t.address, 2)).to.equal("0");
            expect(await templatesReapayersTreasuries.balanceOf(q2t.address, 3)).to.equal("1");
            expect(await templatesReapayersTreasuries.getCurrentFund(1)).to.equal("600".concat(e18));
            expect(await templatesReapayersTreasuries.getCurrentFund(2)).to.equal("0");
            expect(await templatesReapayersTreasuries.getCurrentFund(3)).to.equal("30".concat(e18));
        });

        it("Should create a milestone", async function () {
            const metadataUrl = "https://hub.textile.io/thread/bafkwfcy3l745x57c7vy3z2ss6ndokatjllz5iftciq4kpr4ez2pqg3i/buckets/bafzbeiaorr5jomvdpeqnqwfbmn72kdu7vgigxvseenjgwshoij22vopice";
    
            const tx = await milestones.createMilestone(
              memberAccount1.address,
              6,
              metadataUrl,
              projectIds[0]
            );
    
            const txReceipt = await tx.wait();
            const milestoneCreatedEvent = txReceipt.events.find(txReceiptEvent => txReceiptEvent.event === 'MilestoneCreated');
            const creator = milestoneCreatedEvent.args[0];
            const tokenId = milestoneCreatedEvent.args[1];
    
            const uri = await milestones.tokenURI(tokenId);
            const owner = await milestones.ownerOf(tokenId);
    
            expect(uri).to.eq(metadataUrl);
            expect(owner).to.eq(creator);
            expect(owner).to.eq(memberAccount1.address);
          });
    
          it("Should take a milestone", async function () {
            const metadataUrl = "https://hub.textile.io/thread/bafkwfcy3l745x57c7vy3z2ss6ndokatjllz5iftciq4kpr4ez2pqg3i/buckets/bafzbeiaorr5jomvdpeqnqwfbmn72kdu7vgigxvseenjgwshoij22vopice";
    
            let tx = await milestones.createMilestone(
              memberAccount1.address,
              6,
              metadataUrl,
              projectIds[0]
            );
    
            let txReceipt = await tx.wait();
            const milestoneCreatedEvent = txReceipt.events.find(txReceiptEvent => txReceiptEvent.event === 'MilestoneCreated');
            const creator = milestoneCreatedEvent.args[0];
            const tokenId = milestoneCreatedEvent.args[1];
    
            await milestones.validate(tokenId);
    
            tx = await milestones.takeMilestone(
              tokenId,
              memberAccount2.address
            );
    
            txReceipt = await tx.wait();
            const milestoneTakenEvents = txReceipt.events.find(txReceiptEvent => txReceiptEvent.event === 'MilestoneTaken');
            const milestone = await milestones.milestones(tokenId);
    
            expect(milestone.taker).to.eq(memberAccount2.address);
            expect(milestone.creator).to.eq(memberAccount1.address);
            expect(milestone.status).to.eq(1);
            expect(milestoneTakenEvents).to.not.null;
          });
    
          it("Should submit a milestone", async function () {
            const metadataUrl = "https://hub.textile.io/thread/bafkwfcy3l745x57c7vy3z2ss6ndokatjllz5iftciq4kpr4ez2pqg3i/buckets/bafzbeiaorr5jomvdpeqnqwfbmn72kdu7vgigxvseenjgwshoij22vopice";
    
            let tx = await milestones.createMilestone(
              memberAccount1.address,
              6,
              metadataUrl,
              projectIds[0]
            );
    
            let txReceipt = await tx.wait();
            const milestoneCreatedEvent = txReceipt.events.find(txReceiptEvent => txReceiptEvent.event === 'MilestoneCreated');
            const creator = milestoneCreatedEvent.args[0];
            const tokenId = milestoneCreatedEvent.args[1];
    
            await milestones.validate(tokenId);
    
            tx = await milestones.takeMilestone(
              tokenId,
              memberAccount2.address
            );
    
            txReceipt = await tx.wait();
            const milestoneTakenEvents = txReceipt.events.find(txReceiptEvent => txReceiptEvent.event === 'MilestoneTaken');
            expect(milestoneTakenEvents).to.not.null;
    
            await milestones.validate(tokenId);
    
            tx = await milestones.submitMilestone(
              tokenId,
              memberAccount2.address
            );
    
            txReceipt = await tx.wait();
            const milestoneSubmittedEvents = txReceipt.events.find(txReceiptEvent => txReceiptEvent.event === 'MilestoneSubmitted');
            expect(milestoneSubmittedEvents).to.not.null;
    
            const milestone = await milestones.milestones(tokenId);
            expect(milestone.taker).to.eq(memberAccount2.address);
            expect(milestone.creator).to.eq(memberAccount1.address);
            expect(milestone.status).to.eq(2);
    
          });
    
    
          it("Should complete a milestone", async function () {
            const metadataUrl = "https://hub.textile.io/thread/bafkwfcy3l745x57c7vy3z2ss6ndokatjllz5iftciq4kpr4ez2pqg3i/buckets/bafzbeiaorr5jomvdpeqnqwfbmn72kdu7vgigxvseenjgwshoij22vopice";
    
            let tx = await milestones.createMilestone(
              memberAccount1.address,
              6,
              metadataUrl,
              projectIds[0]
            );
    
            let txReceipt = await tx.wait();
            const milestoneCreatedEvent = txReceipt.events.find(txReceiptEvent => txReceiptEvent.event === 'MilestoneCreated');
            const creator = milestoneCreatedEvent.args[0];
            const tokenId = milestoneCreatedEvent.args[1];
    
            await milestones.validate(tokenId);
    
            tx = await milestones.takeMilestone(
              tokenId,
              memberAccount2.address
            );
    
            txReceipt = await tx.wait();
            const milestoneTakenEvents = txReceipt.events.find(txReceiptEvent => txReceiptEvent.event === 'MilestoneTaken');
            expect(milestoneTakenEvents).to.not.null;
    
            await milestones.validate(tokenId);
    
            tx = await milestones.submitMilestone(
              tokenId,
              memberAccount2.address
            );
    
            txReceipt = await tx.wait();
            const milestoneSubmittedEvents = txReceipt.events.find(txReceiptEvent => txReceiptEvent.event === 'MilestoneSubmitted');
            expect(milestoneSubmittedEvents).to.not.null;
    
            let milestone = await milestones.milestones(tokenId);
            expect(milestone.taker).to.eq(memberAccount2.address);
            expect(milestone.creator).to.eq(memberAccount1.address);
            expect(milestone.status).to.eq(2);
    
            await milestones.validate(tokenId);
    
            tx = await milestones.completeMilestone(
              tokenId,
              memberAccount1.address
            );
            txReceipt = await tx.wait();
            milestone = await milestones.milestones(tokenId);
            const milestoneCompletedEvents = txReceipt.events.find(txReceiptEvent => txReceiptEvent.event === 'MilestoneCompleted');
            expect(milestoneCompletedEvents).to.not.null;
            expect(milestone.status).to.eq(3);
    
          });
    })
    
});