const addresses = require("../addresses");
const hre = require("hardhat");
const { ethers } = require("hardhat");

const network = hre.network.name;
const dai = addresses[network].dai;
const usdc = addresses[network].usdc;
const landingPoolAP = addresses[network].landingPoolAP;

async function main() {
  const [deployer] = await ethers.getSigners();
  //const Token = await ethers.getContractFactory("DITOToken");

  const milestoneTemplate = process.env.TEMPLATE;
  const q2tAddress = process.env.Q2T;
  const communityAddress = process.env.COMMUNITY;
  const projectsAddress = process.env.PROJECTS;

  if (!milestoneTemplate || milestoneTemplate < 1 || milestoneTemplate > 3) {
    console.log("Please provide valid template (1, 2 or 3) by setting TEMPLATE env variable");
    process.exit(0);
  };
  if (!q2tAddress) {
    console.log("Please provide Q2T address by setting Q2T env variable");
    process.exit(0);
  };
  if (!communityAddress) {
    console.log("Please provide Community address by setting COMMUNITY env variable");
    process.exit(0);
  };
  if (!projectsAddress) {
    console.log("Please provide Projects address by setting PROJECTS env variable");
    process.exit(0);
  };

  console.log("Deploying to network: ", network);

  console.log(
    "Deploying contracts with the account:",
    deployer.address
  );

  const address0 = "0x0000000000000000000000000000000000000000";
  
  console.log("Account balance:", (await deployer.getBalance()).toString());
  console.log("----------------------------");

  console.log("About to create new Milestones and community treasury using Q2T: ", q2tAddress); 
  console.log("Using Template: ", milestoneTemplate);
  console.log("Using Community at address: ", communityAddress);
  console.log("Using Projects at address: ", projectsAddress);
  await rl.question("Are you sure?", async function(answer) {
    if(answer != "y") {
      process.exit(0);
    }
  });
  
  console.log("----------------------------");
  console.log("Deploying one Milestones and community treasury");

  const createMilestonesTx = await q2t.deployMilestones(i, address0, address0);

  const events = (await createMilestonesTx.wait()).events?.filter((e) => {
    return e.event == "MilestonesDeployed"
  });

  const milestonesAddress = events[0].args._milestones;
  const communityTreasuriesAddress = await q2t.milestonesTreasuries(milestonesAddress);

  console.log("Template ", i, ", Milestones address: ", milestonesAddress);
  console.log("              Treasury address: ", communityTreasuriesAddress);
}

async function deployOracle() {
  const [deployer] = await ethers.getSigners();

  const chainlink = addresses[network].chainlink;

  console.log("Deploying Gig Validator (oracle)...");
  const GigValidator = await ethers.getContractFactory("GigValidator");
  const gigValidator = await GigValidator.deploy(chainlink.address, ethers.utils.toUtf8Bytes(chainlink.jobId));
  await gigValidator.deployTransaction.wait();
  console.log("Validator address: ", gigValidator.address);

  return gigValidator.address;
}

async function deployFactories() {
  const [deployer] = await ethers.getSigners();

  console.log("Deploying community treasury factory");
  const CommunityTreasuryFactory = await ethers.getContractFactory("CommunityTreasuryFactory");
  const communityTreasuryFactory = await CommunityTreasuryFactory.deploy();
  console.log("Community treasury factory address: ", communityTreasuryFactory.address);

  console.log("Deploying milestones factory");
  const MilestonesLib = await ethers.getContractFactory("MilestoneStatuses");
  const milestonesLib = await MilestonesLib.deploy();
  await milestonesLib.deployed();

  const MilestonesFactory = await ethers.getContractFactory("MilestonesFactory", {
    libraries: {
      MilestoneStatuses: milestonesLib.address
    }
  });
  const milestonesFactory = await MilestonesFactory.deploy();
  console.log("Milestones factory address: ", milestonesFactory.address);

  return { 
    communityTreasuryFactoryAddr: communityTreasuryFactory.address,
    milestonesFactory: milestonesFactory.address
  };
}

async function deployAddressesProvider(communityTreasuryFactory, milestonesFactory) {
  const [deployer] = await ethers.getSigners();

  console.log("Deploying addresses provider");
  const AddressesProvider = await ethers.getContractFactory("AddressesProvider");
  const addressesProvider = await AddressesProvider.deploy(
    dai,
    usdc,
    milestonesFactory,
    communityTreasuryFactory,
    landingPoolAP,
  );
  console.log("Addresses provider address: ", addressesProvider.address);

  return addressesProvider.address;
}
  
main()
  .then(() => process.exit(0))
  .catch(error => {
    console.error(error);
    process.exit(1);
  });
  