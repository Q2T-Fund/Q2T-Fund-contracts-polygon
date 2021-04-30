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
let gigValidator;
let ditoTokenFactory;
let communityTreasuryFactory;
let addressesProvider;
let communitiesRegistry;
let gigsRegistryFactory;

const forwarder_address = addresses[network].forwarder;
const dai = addresses[network].dai;
const adai = addresses[network].adai;
const stableDebtDai = addresses[network].stableDebtDai;
const usdc = addresses[network].usdc;
const stableDebtUsdc = addresses[network].stableDebtUsdc;
const variableDebtUsdc = addresses[network].variableDebtUsdc;
const landingPoolAP = addresses[network].landingPoolAP;
const chainlink = addresses[network].chainlink;

const gigHashIncompl = "0xB3B3886F389F27BC1F2A41F0ADD45A84453F0D2A877FCD1225F13CD95953A8";

/*const gigs = [
    ["400", "100", "81", "144"], //comm 1
    ["1600"], //comm 2
    [], //comm 3
    ["900", "900", "100"] //comm 4
];*/

const gigs = [
    ["400", "100", "81", "144"], //comm 1
    ["1600"], //comm 2
    [], //comm 3
    ["900", "900", "100"] //comm 4
];


const projects = [
    "0xf1f1f11543111111111111111111111111111111",
    "0xf1f1f11111543111111122222222222222222222",
    "0xf2f2f22456222222222222222222222222222222",
    "0xf3f3f33333456333333333333333333333333333",
    "0xf1f1f1fffffff456fffffffffffffffffffffff1",
    "0xf1f1f1ffffffffff456ffffffffffffffffffff2",
    "0xf1f1f1fffffffffffff456fffffffffffffffff3"
];

const gigsProjects = [
    [
        projects[0],
        projects[0],
        projects[1],
        projects[1],
    ],
    [
        projects[2]
    ],
    [],
    [
        projects[3],
        projects[3],
        projects[3]
    ]
];

let projectsAllocs = [];

let projectsWithAllocs = [];

const expectedAllocs = [
    "17264980512",
    "10620495444",
    "0",
    "32525403222"
];

const communitiesNumber = 4;

let communities = [];
let communityTreasuries = [];
let gigsRegistries = [];

describe("Gig completion and quadratic distribution", function() {
    before(async function() {
        //first reset the fork
        await hre.network.provider.request({
            method: "hardhat_reset",
            params: [{
              forking: {
                jsonRpcUrl: "https://matic-mainnet-archive-rpc.bwarelabs.com",
                blockNumber: Number(process.env.ALCHEMY_BLOCK)
              }
            }]
        });

        const [ ,, sender ]  = await ethers.getSigners(); //need to send some gas funds to impersonated acc
        await sender.sendTransaction({
            to: process.env.IMPERSONATE, 
            value: ethers.utils.parseEther("9000.0")
        });

        const GigValidator = await ethers.getContractFactory("GigValidator");
        gigValidator = await GigValidator.deploy(chainlink.address, ethers.utils.toUtf8Bytes(chainlink.jobId));
        await gigValidator.deployed();
        
        const DITOTokenFactory = await ethers.getContractFactory("DITOTokenFactory");
        ditoTokenFactory = await DITOTokenFactory.deploy();
        await ditoTokenFactory.deployed();

        const CommunityTreasuryFactory = await ethers.getContractFactory("CommunityTreasuryFactory");
        communityTreasuryFactory = await CommunityTreasuryFactory.deploy();
        await communityTreasuryFactory.deployed();

        const GigsRegistryFactory = await ethers.getContractFactory("GigsRegistryFactory");
        gigsRegistryFactory = await GigsRegistryFactory.deploy();
        await gigsRegistryFactory.deployed();

        const AddressesProvider = await ethers.getContractFactory("AddressesProvider");
        addressesProvider = await AddressesProvider.deploy(
            dai,
            usdc,
            communityTreasuryFactory.address,
            ditoTokenFactory.address,
            gigsRegistryFactory.address,
            gigValidator.address,
            landingPoolAP,
            forwarder_address
        );
        await addressesProvider.deployed();

        const TreasuryDAO = await ethers.getContractFactory("TreasuryDao");
        treasuryDAO = await TreasuryDAO.deploy(0, addressesProvider.address, addresses[network].aaveDataProvider);
        await treasuryDAO.deployed;

        communitiesRegistry = await ethers.getContractAt(
            "CommunitiesRegistry", 
            await addressesProvider.communitiesRegistry()
        );

        await communitiesRegistry.setDao(0, treasuryDAO.address, false);
        
        for (let i = 0; i < communitiesNumber; i++) {
            await communitiesRegistry.createCommunity(0);

            community = await ethers.getContractAt("Community", await communitiesRegistry.communities(0,i));
            await communitiesRegistry.addCommunityTreasury(community.address);
            communityTreasury = await ethers.getContractAt("CommunityTreasury", await community.communityTreasury());

            //const GigsRegistry = await ethers.getContractFactory("GigsRegistry");
            //gigsRegistry = await GigsRegistry.deploy(community.address, "community1", gigValidator.address);
            await community.addGigsRegistry("community" + i);
            gigsRegistry = await ethers.getContractAt("GigsRegistry", await community.gigsRegistry());
            //await gigsRegistry.deployed();

            await gigsRegistry.enableOracle(false);
            //await community.setGigsRegistry(gigsRegistry.address);

            communities.push(community);
            communityTreasuries.push(communityTreasury);
            gigsRegistries.push(gigsRegistry);

            console.log(i, "   ", communities[i].address, ", ", communityTreasuries[i].address);
        }

        await hre.network.provider.request({
            method: "hardhat_impersonateAccount",
            params: [process.env.IMPERSONATE]
        });

        const signer = await ethers.provider.getSigner(process.env.IMPERSONATE);

        const Erc20 = await ethers.getContractFactory("ERC20", signer);
        const daiToken = Erc20.attach(dai);

        const TreasuryDaoImp = await ethers.getContractFactory("TreasuryDao", signer);
        const treasuryDaoImp = TreasuryDaoImp.attach(treasuryDAO.address);

        await daiToken.approve(treasuryDaoImp.address, "1000000".concat(e18));
        await treasuryDaoImp.deposit("DAI", "100000", 30);
    });
    it("Test deployment and links", async function() {
        expect(await treasuryDAO.nextId()).to.equal("4");
        for (let i = 0; i < communitiesNumber; i++) {
            expect(await treasuryDAO.communityTreasuries(i)).to.equal(communityTreasuries[i].address);
            expect(await gigsRegistries[i].community()).to.equal(communities[i].address);
            expect(await communities[i].gigsRegistry()).to.equal(gigsRegistries[i].address);
        }
    });
    it("Should create and complete milestones", async function() {
        const [deployer] = await ethers.getSigners();


        for (let i = 0; i < gigs.length; i++) {
            if (gigs[i].length > 0) {
                for (let j = 0; j < gigs[i].length; j++) {
                    const gigHash = gigHashIncompl + String(i) + String(j);

                    await gigsRegistries[i].createMilestone(gigHash, gigsProjects[i][j]);
                    const [id, ] = await gigsRegistries[i].gigIdLookup(deployer.address, gigHash);

                    await gigsRegistries[i].takeGig(id);

                    await gigsRegistries[i].completeGig(id, deployer.address, gigHash, gigs[i][j]);

                    //console.log(communityTreasuries[i].address, String(await communityTreasuries[i].getDitoBalance()));
                }
            }
        }
    });
    it("Should allow treasuries to borrow (and distribute among projects) now", async function() {
        const debtUsdcToken = await ethers.getContractAt("ICreditDelegationToken", variableDebtUsdc);
        const usdcToken = await ethers.getContractAt("IERC20", usdc);

        for (let i = 0; i < communitiesNumber; i++) {
            console.log(String(await debtUsdcToken.borrowAllowance(
                treasuryDAO.address, communityTreasuries[i].address
            )));
            /*expect(
                await debtUsdcToken.borrowAllowance(
                    treasuryDAO.address, communityTreasuries[i].address
                )
            ).to.equal(expectedAllocs[i]);*/

            if (expectedAllocs[i] != "0" ) {
                await communityTreasuries[i].allocateDelegated();
            };
            
            //expect(await usdcToken.balanceOf(communityTreasuries[i].address)).to.equal(expectedAllocs[i]);
            expect(await debtUsdcToken.borrowAllowance(
                treasuryDAO.address, communityTreasuries[i].address)
            ).to.equal("0");

            let allocs = new Map();

            projectsWithAllocs.push([]);

            for (let j = 0; j < gigsProjects[i].length; j++) {
                if (!allocs.has(gigsProjects[i][j])) {
                    allocs.set(gigsProjects[i][j], String(await communityTreasuries[i].projectAllocation(gigsProjects[i][j])));
                    projectsWithAllocs[i].push(gigsProjects[i][j]);
                }
            }

            projectsAllocs.push(allocs);
        }

        console.log(projectsAllocs);
        console.log(projectsWithAllocs);
    });
    it("Should allow projects to get distribution according to allocation", async function() {
        const usdcToken = await ethers.getContractAt("IERC20", usdc);

        for (let i = 0; i < communitiesNumber; i++) {
            for (let j = 0; j < projectsWithAllocs[i].length; j++) {
                let balance = await usdcToken.balanceOf(projectsWithAllocs[i][j]);

                await communityTreasuries[i].receiveAllocation(
                    "USDC", 
                    projectsAllocs[i].get(projectsWithAllocs[i][j]),
                    projectsWithAllocs[i][j]
                );

                balance = (await usdcToken.balanceOf(projectsWithAllocs[i][j])).sub(balance);

                expect(balance).to.equal(projectsAllocs[i].get(projectsWithAllocs[i][j]));
                expect(await communityTreasuries[i].projectAllocation(projectsWithAllocs[i][j])).to.equal("0");
            }
        }
    });
});