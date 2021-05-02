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
let communityTreasuryFactory;
let milestonesFactory;
let communitiesRegistry;
let gigsRegistryFactory;

let q2t;
let templatesTreasuries;
let templatesReapayersTreasuries;
let addressesProvider;

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
                communityTreasuryFactory.address,
                milestonesFactory.address,
                //gigsRegistryFactory.address,
                //gigValidator.address,
                landingPoolAP,
            );
            await addressesProvider.deployed();

            expect(addressesProvider.address).not.to.be.undefined;
            //expect(await addressesProvider.communitiesRegistry()).not.to.equal("0x0000000000000000000000000000000000000000");
            //expect(await addressesProvider.communityTreasuryFactory()).to.equal(communityTreasuryFactory.address);
            //expect(await addressesProvider.ditoTokenFactory()).to.equal(ditoTokenFactory.address);
            //expect(await addressesProvider.oracle()).to.equal(gigValidator.address);
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
        /*it("Should add treasury dao to communities registry", async function() {
            communitiesRegistry = await ethers.getContractAt(
                "CommunitiesRegistry", 
                await addressesProvider.communitiesRegistry()
            );

            await communitiesRegistry.setDao(0, treasuryDAO.address, false);

            expect(await communitiesRegistry.daos(0)).to.equal(treasuryDAO.address);
            expect(await communitiesRegistry.daos(1)).to.equal("0x0000000000000000000000000000000000000000");
            expect(await communitiesRegistry.daos(2)).to.equal("0x0000000000000000000000000000000000000000");
        });*/
    });
    /*describe("Community creation", function () {
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
            expect(await token.balanceOf(community.address)).to.equal("96000".concat(e18));
        });
        it("Should create community treasury", async function() {
            await communitiesRegistry.addCommunityTreasury(community.address);
            communityTreasury = await ethers.getContractAt("CommunityTreasury", await community.communityTreasury());
            
            expect(await communityTreasury.owner()).to.equal(community.address);
            expect(await token.balanceOf(communityTreasury.address)).to.equal("2000".concat(e18));
            expect(await token.balanceOf(community.address)).to.equal("94000".concat(e18));
        });
        it("Should have linked community with dao", async function() {
            expect(await communityTreasury.id()).to.equal("0");
            expect(await treasuryDAO.nextId()).to.equal("1");
            expect(await communityTreasury.dao()).to.equal(treasuryDAO.address);
            expect(await treasuryDAO.communityTreasuries(0)).to.equal(communityTreasury.address);
        });
        it("Should deploy and link gig registry", async function() {
            //const GigsRegistry = await ethers.getContractFactory("GigsRegistry");
            //gigsRegistry = await GigsRegistry.deploy(community.address, "community1", gigValidator.address);
            //await gigsRegistry.deployed();
    
            await community.addGigsRegistry("community1");
            gigsRegistry = await ethers.getContractAt("GigsRegistry", await community.gigsRegistry());
            await gigsRegistry.enableOracle(false); //to ignore oracle for tests
    
            expect(gigsRegistry.address).not.to.be.undefined;
            expect(gigsRegistry.address).not.to.equal("0x0000000000000000000000000000000000000000");
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
    });*/
    describe("Basic flow", function() {
        before(async function() {
            const [ , sender ]  = await ethers.getSigners(); //need to send some gas funds to impersonated acc
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
        /*it("Should create gig (without project)", async function() {
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
            const debtUsdcToken = await ethers.getContractAt("ICreditDelegationToken", variableDebtUsdc);
    
            //expect(await stableDebtDaiToken.borrowAllowance(treasuryDAO.address, communityTreasury.address)).to.equal(MAX_UINT);
            expect(await debtUsdcToken.borrowAllowance(treasuryDAO.address, communityTreasury.address)).to.equal("601".concat("000000"));
        });
        it("Should borrow delegated credit and allocate it to project", async function() {
            await communityTreasury.allocateDelegated();

            const usdcToken = await ethers.getContractAt("IERC20", usdc);
    
            expect(await usdcToken.balanceOf(communityTreasury.address)).to.equal("601".concat("000000"));
            expect(await communityTreasury.projectAllocation(gigProject)).to.equal("601".concat("000000"));
        });
        it("Should not allow receiving by project with no allocation", async function() {
            expect(
                communityTreasury.receiveAllocation("USDC", "1", "0x111111111111111111111111111111111111111e")
            ).to.be.revertedWith("< allocation");
        });
        it("Should not allow receiving more than allocation", async function() {
            expect(
                communityTreasury.receiveAllocation("USDC", "601".concat("000001"), gigProject)
            ).to.be.revertedWith("< allocation");
        });
        it("Should receive allocated credit", async function() {
            await communityTreasury.receiveAllocation("USDC", "601".concat("000000"), gigProject);
    
            const usdcToken = await ethers.getContractAt("IERC20", usdc);
    
            expect(await usdcToken.balanceOf(gigProject)).to.equal("601".concat("000000"));

        });
        it("Should not be able to receive allocation again", async function() {
            expect(await communityTreasury.projectAllocation(gigProject)).to.equal("0");
            expect(
                communityTreasury.receiveAllocation("USDC", "601".concat("000000"), gigProject)
            ).to.be.revertedWith("< allocation");
        });*/
    })
    
});