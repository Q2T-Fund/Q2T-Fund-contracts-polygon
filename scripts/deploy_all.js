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

  console.log("Deploying to network: ", network);

  console.log(
    "Deploying contracts with the account:",
    deployer.address
  );

  const address0 = "0x0000000000000000000000000000000000000000";
  
  console.log("Account balance:", (await deployer.getBalance()).toString());
  console.log("----------------------------");
  console.log("Deploying prerequisites");

  //const gigValidatorAddress = await deployOracle();
  const { communityTreasuryFactoryAddr, milestonesFactory } = await deployFactories();
  const addressesProviderAddress = await deployAddressesProvider(
    communityTreasuryFactoryAddr,
    milestonesFactory
  );
  const addressesProvider = await ethers.getContractAt("AddressesProvider", addressesProviderAddress);

  console.log("----------------------------");
  console.log("Deploying Q2T and Template Treasuries");

  const Q2T = await ethers.getContractFactory("Q2T");
  const q2t = await Q2T.deploy(addressesProvider.address);
  await q2t.deployed();

  console.log("Q2T address: ", q2t.address);

  const templatesTreasuriesAddress = await q2t.templatesTreasuries();
  const templatesReapayersTreasuriesAddress = await q2t.templatesReapayersTreasuries();

  console.log("Templates Treasuries address: ", templatesTreasuriesAddress);
  console.log("Templates Reapayers Treasuries address: ", templatesReapayersTreasuriesAddress);
  
  console.log("----------------------------");
  console.log("Deploying one Milestones and community treasury per each template");

  let milestonesAddresses = [];
  let communityTreasuriesAddresses = [];

  for (let i = 1; i <= 3; i++) {
    const createMilestonesTx = await q2t.deployMilestones(i, address0);

    const events = (await createMilestonesTx.wait()).events?.filter((e) => {
      return e.event == "MilestonesDeployed"
    });

    milestonesAddresses.push(events[0].args._milestones);
    communityTreasuriesAddresses.push(await q2t.milestonesTreasuries(milestonesAddresses[i - 1]));

    console.log("Template ", i, ", Milestones address: ", milestonesAddresses[i - 1]);
    console.log("              Treasury address: ", communityTreasuriesAddresses[i - 1]);
  }

  if (network == "kovan") {
    console.log("Verifying contracts with etherscan...");
    
    await hre.run("verify:verify", {
      address: community.address,
      constructorArguments: [template, dai, usdc, landingPoolAP, forwarder_address,],
    });

    await hre.run("verify:verify", {
      address: communityTreasury.address,
      constructorArguments: [template, token.address, deployer.address, dai, usdc, landingPoolAP,],
    });

    await hre.run("verify:verify", {
      address: token.address,
      constructorArguments: ["96000000000000000000000",],
    });

    await hre.run("verify:verify", {
      address: gigsRegistry.address,
      constructorArguments: [community.address, "community1", gigValidatorAddress,],
    });

    await hre.run("verify:verify", {
      address: treasuryDAO.address,
      constructorArguments: [template, addresses[network].aaveDataProvider, dai, usdc,],
    });
  }
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
  