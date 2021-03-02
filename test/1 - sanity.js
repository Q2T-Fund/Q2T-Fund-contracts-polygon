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
let gigValidator;
let ditoTokenFactory;
let communityTreasuryFactory;
let addressesProvider;
let communitiesRegistry;

const forwarder_address = addresses[network].forwarder;
const dai = addresses[network].dai;
const adai = addresses[network].adai;
const stableDebtDai = addresses[network].stableDebtDai;
const usdc = addresses[network].usdc;
const stableDebtUsdc = addresses[network].stableDebtUsdc;
const landingPoolAP = addresses[network].landingPoolAP;
const chainlink = addresses[network].chainlink;

const gigHashIncompl = "0xB3B3886F389F27BC1F2A41F0ADD45A84453F0D2A877FCD1225F13CD95953A86";
const gigProject = "0x1111111111111111111111111111111111111111";

describe("Deposit and borrow happy flow", function() {
    describe("Deployment", function () {
        it("Should deploy gig validator (oracle)", async function () {
            const GigValidator = await ethers.getContractFactory("GigValidator");
            gigValidator = await GigValidator.deploy(chainlink.address, ethers.utils.toUtf8Bytes(chainlink.jobId));
            await gigValidator.deployed();
    
            expect(gigValidator.address).not.to.be.undefined;
        });
        it("Should deploy contract factories", async function() {
            const DITOTokenFactory = await ethers.getContractFactory("DITOTokenFactory");
            ditoTokenFactory = await DITOTokenFactory.deploy();
            await ditoTokenFactory.deployed();

            const CommunityTreasuryFactory = await ethers.getContractFactory("CommunityTreasuryFactory");
            communityTreasuryFactory = await CommunityTreasuryFactory.deploy();
            await communityTreasuryFactory.deployed();

            expect(ditoTokenFactory.address).not.to.be.undefined;
            expect(communityTreasuryFactory.address).not.to.be.undefined;
        });
        it("Should deploy addresses provider and communities registry", async function() {
            const AddressesProvider = await ethers.getContractFactory("AddressesProvider");
            addressesProvider = await AddressesProvider.deploy(
                dai,
                usdc,
                communityTreasuryFactory.address,
                ditoTokenFactory.address,
                gigValidator.address,
                landingPoolAP,
                forwarder_address
            );
            await addressesProvider.deployed();

            expect(addressesProvider.address).not.to.be.undefined;
            expect(await addressesProvider.communitiesRegistry()).not.to.equal("0x0000000000000000000000000000000000000000");
            expect(await addressesProvider.communityTreasuryFactory()).to.equal(communityTreasuryFactory.address);
            expect(await addressesProvider.ditoTokenFactory()).to.equal(ditoTokenFactory.address);
            expect(await addressesProvider.oracle()).to.equal(gigValidator.address);
            expect((await addressesProvider.currenciesAddresses("DAI")).toLowerCase()).to.equal(dai);
            expect((await addressesProvider.currenciesAddresses("USDC")).toLowerCase()).to.equal(usdc);
        });
        it("Should deploy and treasury dao", async function() {
            const TreasuryDAO = await ethers.getContractFactory("TreasuryDao");
            treasuryDAO = await TreasuryDAO.deploy(0, addressesProvider.address, addresses[network].aaveDataProvider);
            await treasuryDAO.deployed;
            
            expect(treasuryDAO.address).not.to.be.undefined;
        });
        it("Should add treasury dao to communities registry", async function() {
            communitiesRegistry = await ethers.getContractAt(
                "CommunitiesRegistry", 
                await addressesProvider.communitiesRegistry()
            );

            await communitiesRegistry.setDao(0, treasuryDAO.address, false);

            expect(await communitiesRegistry.daos(0)).to.equal(treasuryDAO.address);
            expect(await communitiesRegistry.daos(1)).to.equal("0x0000000000000000000000000000000000000000");
            expect(await communitiesRegistry.daos(2)).to.equal("0x0000000000000000000000000000000000000000");
        });
    });
    describe("Community creation", function () {
        it("Should create new community", async function() {
            await communitiesRegistry.createCommunity(0);

            expect(await communitiesRegistry.communities(0,0)).not.to.equal("0x0000000000000000000000000000000000000000");
            expect(await communitiesRegistry.getCommunitiesNumber(0)).to.equal(1);
            expect(await communitiesRegistry.getCommunitiesNumber(1)).to.equal(0);
            expect(await communitiesRegistry.getCommunitiesNumber(2)).to.equal(0);
        });
        it("Should have created token with community", async function() {
            community = await ethers.getContractAt("Community", await communitiesRegistry.communities(0,0));
            token = await ethers.getContractAt("DITOToken", await community.tokens());

            expect(await token.owner()).to.equal(community.address);
            expect(await token.balanceOf(community.address)).to.equal("94000".concat(e18));
        });
        it("Should have created community treasury", async function() {
            communityTreasury = await ethers.getContractAt("CommunityTreasury", await community.communityTreasury());
            
            expect(await communityTreasury.owner()).to.equal(community.address);
            expect(await token.balanceOf(communityTreasury.address)).to.equal("2000".concat(e18));
        });
        it("Should have linked community with dao", async function() {
            expect(await communityTreasury.id()).to.equal("0");
            expect(await treasuryDAO.nextId()).to.equal("1");
            expect(await communityTreasury.dao()).to.equal(treasuryDAO.address);
            expect(await treasuryDAO.communityTreasuries(0)).to.equal(communityTreasury.address);
        });
        it("Should deploy and link gig registry", async function() {
            const GigsRegistry = await ethers.getContractFactory("GigsRegistry");
            gigsRegistry = await GigsRegistry.deploy(community.address, "community1", gigValidator.address);
            await gigsRegistry.deployed();
    
            await community.setGigsRegistry(gigsRegistry.address);
            await gigsRegistry.enableOracle(false); //to ignore oracle for tests
    
            expect(await gigsRegistry.community()).to.equal(community.address);
            expect(await community.gigsRegistry()).to.equal(gigsRegistry.address);
        });
        it("Should allow to create another community", async function() {
            await communitiesRegistry.createCommunity(0);

            expect(await communitiesRegistry.communities(0,1)).not.to.equal("0x0000000000000000000000000000000000000000");
            expect(await communitiesRegistry.getCommunitiesNumber(0)).to.equal(2);
            expect(await communitiesRegistry.communities(0,1)).not.to.equal(await communitiesRegistry.communities(0,0));
        });
        it("Should not allow to create community without deployed dao", async function() {
            expect(communitiesRegistry.createCommunity(1)).to.be.revertedWith("dao not set");;
        });
    });
    describe("Basic flow", function() {
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
    
            await gigsRegistry.createGig(gigHash, "community1");
            await gigsRegistry.confirmGig(gigHash);
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
            //const stableDebtDaiToken = await ethers.getContractAt("ICreditDelegationToken", stableDebtDai);
            const stableDebtUsdcToken = await ethers.getContractAt("ICreditDelegationToken", stableDebtUsdc);
    
            //expect(await stableDebtDaiToken.borrowAllowance(treasuryDAO.address, communityTreasury.address)).to.equal(MAX_UINT);
            expect(await stableDebtUsdcToken.borrowAllowance(treasuryDAO.address, communityTreasury.address)).to.equal("604".concat("000000"));
        });
        it("Should receive delegated credit", async function() {
            await communityTreasury.borrowDelegated("USDC","604".concat("000000"));
    
            const usdcToken = await ethers.getContractAt("IERC20", usdc);
    
            expect(await usdcToken.balanceOf(communityTreasury.address)).to.equal("604".concat("000000"));
        });
    })
    
});

describe("Self-fund happy flow", function() {
    before(async function() {
        //first reset the fork
        await hre.network.provider.request({
            method: "hardhat_reset",
            params: [{
              forking: {
                jsonRpcUrl: process.env.ALCHEMY_URL,
                blockNumber: Number(process.env.ALCHEMY_BLOCK)
              }
            }]
          });

        //deploy stuff        
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

        await community.setTreasuryDAO(treasuryDAO.address);
        await treasuryDAO.linkCommunity(communityTreasury.address);
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
    it("Should deposit funing into dao", async function() {
        //treasury already funded so only check dao
        const adaiToken = await ethers.getContractAt("ERC20",adai);

        expect(await adaiToken.balanceOf(treasuryDAO.address)).to.equal("10".concat(e18));
        expect(await treasuryDAO.depositors(communityTreasury.address)).to.equal("10".concat(e18));
        expect(await treasuryDAO.totalDeposited()).to.equal("10".concat(e18));
        expect(await treasuryDAO.repayableAmount(communityTreasury.address, dai)).to.equal("10".concat(e18));        
    })
});