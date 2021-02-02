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
let treasuryDAO;
let community;
let gigsRegistry;
let timelock;

const forwarder_address = addresses[network].forwarder;
const dai = addresses[network].dai;
const adai = addresses[network].adai;
const stableDebtDai = addresses[network].stableDebtDai;
const usdc = addresses[network].usdc;
const stableDebtUsdc = addresses[network].stableDebtUsdc;
const landingPoolAP = addresses[network].landingPoolAP;

const gigHashIncompl = "0xB3B3886F389F27BC1F2A41F0ADD45A84453F0D2A877FCD1225F13CD95953A86";
const gigProject = "0x1111111111111111111111111111111111111111";

describe("Deposit and borrow happy flow", function() {
    it("Should deploy community, token and treasury", async function() {
        const Community = await ethers.getContractFactory("Community");
        community = await Community.deploy(0, dai, usdc, landingPoolAP, forwarder_address);
        await community.deployed();

        const Token = await ethers.getContractFactory("DITOToken");
        token = Token.attach(await community.tokens());
        const CommunityTreasury = await ethers.getContractFactory("CommunityTreasury");
        communityTreasury = CommunityTreasury.attach(await community.communityTreasury());
        
        expect(await token.owner()).to.equal(community.address);
        expect(await communityTreasury.owner()).to.equal(community.address);
        expect(await token.balanceOf(community.address)).to.equal("94000".concat(e18));
        expect(await token.balanceOf(communityTreasury.address)).to.equal("2000".concat(e18));
    });
    it("Should deploy gig registry", async function() {
        await community.createGigsRegistry();
        gigsRegistry = await ethers.getContractAt("GigsRegistry", community.gigsRegistry());

        expect(await gigsRegistry.community()).to.equal(community.address);
    });
    it("Should deploy and link treasury dao", async function() {
        const TreasuryDAO = await ethers.getContractFactory("TreasuryDao");
        treasuryDAO = await TreasuryDAO.deploy(0, addresses[network].aaveDataProvider, dai, usdc);
        await treasuryDAO.deployed;
        
        await community.setTreasuryDAO(treasuryDAO.address);
        await treasuryDAO.linkCommunity(communityTreasury.address);
        
        expect(await communityTreasury.id()).to.equal("0");
        expect(await treasuryDAO.nextId()).to.equal("1");
        expect(await communityTreasury.dao()).to.equal(treasuryDAO.address);
        expect(await treasuryDAO.communityTeasuries(0)).to.equal(communityTreasury.address);
    });
    it("Should deposit DAI through treasry dao to aave", async function() {
        await hre.network.provider.request({
            method: "hardhat_impersonateAccount",
            params: [process.env.IMPERSONATE]
        });

        signer = await ethers.provider.getSigner(process.env.IMPERSONATE);

        const Erc20 = await ethers.getContractFactory("ERC20", signer);
        const daiToken = Erc20.attach(dai);
        const adaiToken = Erc20.attach(adai);

        const TreasuryDao = await ethers.getContractFactory("TreasuryDao", signer);
        const treasuryDaoImp = TreasuryDao.attach(treasuryDAO.address);

        await daiToken.approve(treasuryDaoImp.address, "1000".concat(e18));
        await treasuryDaoImp.deposit("DAI", 1000, 30);

        expect(await adaiToken.balanceOf(treasuryDAO.address)).to.equal("1000".concat(e18));
    });
    it("Should create gig (without project)", async function() {
        const [deployer] = await ethers.getSigners();
        const gigHash = gigHashIncompl.concat("0");

        await gigsRegistry.createGig(gigHash);
        const [id, isFound] = await gigsRegistry.gigIdLookup(deployer.address, gigHash);
        
        expect(await gigsRegistry.nextId()).to.equal("1");
        expect(String(id)).to.equal("0");
        expect(isFound).to.equal(true);
    });
    it("Should create milestone and link it to project", async function() {
        const [deployer] = await ethers.getSigners();
        const gigHash = gigHashIncompl.concat("1");

        await gigsRegistry.createMilestone(gigHash, gigProject);
        const [id, isFound] = await gigsRegistry.gigIdLookup(deployer.address, gigHash);
        
        expect(await gigsRegistry.nextId()).to.equal("2");
        expect(String(id)).to.equal("1");
        expect(isFound).to.equal(true);
        expect(await gigsRegistry.gigProjects("1")).to.equal(gigProject);
    });
    it("Should return false when no gig found by lookup", async function() {
        const [deployer] = await ethers.getSigners();
        const gigHash = gigHashIncompl.concat("3");
        const [id, isFound] = await gigsRegistry.gigIdLookup(deployer.address, gigHash);

        expect(String(id)).to.equal("0");
        expect(isFound).to.equal(false);
    });
    it("Should not allow complete gig that is not taken", async function() {
        const [deployer] = await ethers.getSigners();
        const gigHash = gigHashIncompl.concat("1");
        expect(gigsRegistry.completeGig(1, deployer.address, gigHash, 1000)).to.be.revertedWith("wrong gig status");
    });
    it("Should allow to take a gig", async function() {
        await gigsRegistry.takeGig(1);

        expect((await gigsRegistry.gigs(1))["status"]).to.equal(2);
    })
    it("Should send DITO tokens from community to treasury upon gig completion", async function() {
        const [deployer] = await ethers.getSigners();
        const gigHash = gigHashIncompl.concat("1");
        await gigsRegistry.completeGig(1, deployer.address, gigHash, 1000);

        expect(await token.balanceOf(communityTreasury.address)).to.equal("3000".concat(e18));
        expect(await token.balanceOf(community.address)).to.equal("93000".concat(e18));
    });
    it("Should not allow complete already completed gig", async function() {
        const [deployer] = await ethers.getSigners();
        const gigHash = gigHashIncompl.concat("1");
        expect(gigsRegistry.completeGig(1, deployer.address, gigHash, 1000)).to.be.revertedWith("wrong gig status");
    });
    it("Shoud send tokens back once theshold reached", async function() {
        const [deployer] = await ethers.getSigners();
        const gigHash = gigHashIncompl.concat("4");

        await gigsRegistry.createMilestone(gigHash, gigProject);
        const [id, ] = await gigsRegistry.gigIdLookup(deployer.address, gigHash);
        await gigsRegistry.takeGig(id);
        await gigsRegistry.completeGig(id, deployer.address, gigHash, 1000);

        expect(await token.balanceOf(communityTreasury.address)).to.equal("2000".concat(e18));
        expect(await token.balanceOf(community.address)).to.equal("94000".concat(e18));
    });
    it("Shoud trigger credit delegation once DITO theshold reached", async function() {
        //Threshold was reached in previos test. This one just checks the delegation
        const stableDebtDaiToken = await ethers.getContractAt("ICreditDelegationToken", stableDebtDai);
        const stableDebtUsdcToken = await ethers.getContractAt("ICreditDelegationToken", stableDebtUsdc);

        expect(await stableDebtDaiToken.borrowAllowance(treasuryDAO.address, communityTreasury.address)).to.equal(MAX_UINT);
        expect(await stableDebtUsdcToken.borrowAllowance(treasuryDAO.address, communityTreasury.address)).to.equal(MAX_UINT);
    });
    it("Should receive delegated credit", async function() {
        await communityTreasury.borrowDelegated("USDC","10".concat("000000"));

        const usdcToken = await ethers.getContractAt("IERC20", usdc);

        expect(await usdcToken.balanceOf(communityTreasury.address)).to.equal("10".concat("000000"));
    });
});

describe("Self-fund happy flow", function() {
    before(async function() {
        //first reset the fore
        await hre.network.provider.request({
            method: "hardhat_reset",
            params: [{
              forking: {
                jsonRpcUrl: process.env.ALCHEMY_URL,
                blockNumber: Number(process.env.ALCHEMY_BLOCK)
              }
            }]
          });
        
        const Community = await ethers.getContractFactory("Community");
        community = await Community.deploy(0, dai, usdc, landingPoolAP, forwarder_address);
        await community.deployed();
  
        const Token = await ethers.getContractFactory("DITOToken");
        token = Token.attach(await community.tokens());
        const CommunityTreasury = await ethers.getContractFactory("CommunityTreasury");
        communityTreasury = CommunityTreasury.attach(await community.communityTreasury());
        const TreasuryDAO = await ethers.getContractFactory("TreasuryDao");
        treasuryDAO = await TreasuryDAO.deploy(0, addresses[network].aaveDataProvider, dai, usdc);
        await treasuryDAO.deployed;
    });
    it("Should deploy and connect timelock", async function() {
        const Timelock = await ethers.getContractFactory("WithdrawTimelock");
        timelock = await Timelock.deploy(communityTreasury.address);
        await timelock.deployed;

        await community.activateTreasuryTimelock();

        expect(await communityTreasury.timelock()).to.equal(timelock.address);
        expect(await communityTreasury.timelockActive()).to.equal(true);
        expect(await timelock.treasury()).to.equal(communityTreasury.address);
    });
    it("Should add member to community", async function() {
        await hre.network.provider.request({
            method: "hardhat_impersonateAccount",
            params: [process.env.IMPERSONATE]
        });

        signer = await ethers.provider.getSigner(process.env.IMPERSONATE);

        const Community = await ethers.getContractFactory("Community", signer);
        const communityImp = Community.attach(community.address);

        await communityImp.join(1000);

        expect(await community.numberOfMembers()).to.equal(2);
        expect(await community.enabledMembers(process.env.IMPERSONATE)).to.equal(true);
    });
    it("Should fund the community and create a timelock", async function() {
        await hre.network.provider.request({
            method: "hardhat_impersonateAccount",
            params: [process.env.IMPERSONATE]
        });

        signer = await ethers.provider.getSigner(process.env.IMPERSONATE);

        const Erc20 = await ethers.getContractFactory("ERC20", signer);
        const daiToken = Erc20.attach(dai);
        const adaiToken = Erc20.attach(adai);

        const CommunityTreasury = await ethers.getContractFactory("CommunityTreasury", signer);
        const communityTreasuryImp = CommunityTreasury.attach(communityTreasury.address);

        await daiToken.approve(communityTreasuryImp.address, "1000".concat(e18));

        await communityTreasuryImp.fund("DAI", 10);
        const fundTimelock = await timelock.timelocks(process.env.IMPERSONATE, 0);

        expect(await communityTreasury.getFunds(process.env.IMPERSONATE, daiToken.address)).to.equal("10".concat(e18));
        expect(await communityTreasury.totalFunded(daiToken.address)).to.equal("10".concat(e18));
        expect(await timelock.getTimelocksCount(process.env.IMPERSONATE)).to.equal(1);
        expect(await timelock.withdrawableByLock(process.env.IMPERSONATE, daiToken.address, fundTimelock)).to.equal("10".concat(e18));
        expect(await timelock.canWithdraw(process.env.IMPERSONATE, daiToken.address)).to.equal(0);       
    });
});
  