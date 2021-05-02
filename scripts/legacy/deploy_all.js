const addresses = require("../addresses");
const hre = require("hardhat");
const { ethers } = require("hardhat");

const network = hre.network.name;
const forwarder_address = addresses[network].forwarder;
const dai = addresses[network].dai;
const usdc = addresses[network].usdc;
const landingPoolAP = addresses[network].landingPoolAP;

async function main() {
  const [deployer] = await ethers.getSigners();
  const Token = await ethers.getContractFactory("DITOToken");

  console.log("Deploying to network: ", network);

  console.log(
    "Deploying contracts with the account:",
    deployer.address
  );
  
  console.log("Account balance:", (await deployer.getBalance()).toString());
  console.log("Forwarder address:", forwarder_address);
  console.log("----------------------------");
  console.log("Deploying prerequisites");

  const gigValidatorAddress = await deployOracle();
  const { ditoTokenFactoryAddr, communityTreasuryFactoryAddr, gigsRegistryFactoryAddr } = await deployFactories();
  const addressesProviderAddress = await deployAddressesProvider(
    gigValidatorAddress,
    ditoTokenFactoryAddr,
    communityTreasuryFactoryAddr,
    gigsRegistryFactoryAddr
  );
  const addressesProvider = await ethers.getContractAt("AddressesProvider", addressesProviderAddress);
  const communitiesRegistry = await ethers.getContractAt(
    "CommunitiesRegistry", 
    await addressesProvider.communitiesRegistry()
  );

  console.log("----------------------------");
  console.log("Deploying DAOs for 3 templates");
  
  let daoAddresses = [];

  for (let i = 0; i < 3; i++) {
    daoAddresses.push(await deployTreasuryDao(i, addressesProviderAddress));

    console.log("Adding dao to registry");
    await communitiesRegistry.setDao(i, daoAddresses[i], false);
  }
  
  console.log("----------------------------");
  console.log("Deploying one Community per each template");

  let communitiesAddresses = [];

  for (let i = 0; i < 3; i++) {
    const createCommunityTx = await communitiesRegistry.createCommunity(i);

    const events = (await createCommunityTx.wait()).events?.filter((e) => {
      return e.event == "CommunityCreated"
    });

    communitiesAddresses.push(events[0].args._newCommunityAddress);

    console.log("Template ", i, ", Community address: ", communitiesAddresses[i]);

    const community = await ethers.getContractAt("Community", communitiesAddresses[i]);
    
    const token = Token.attach(await community.tokens());
    console.log("Token address:", await community.tokens());
    console.log("Community balance: ", String(await token.balanceOf(community.address)));

    console.log("Adding Community Treasury");

    await communitiesRegistry.addCommunityTreasury(community.address);

    const communityTreasury = await ethers.getContractAt("CommunityTreasury", await community.communityTreasury());
    console.log("Community Treasury address:", communityTreasury.address);

    console.log("Deploying and activating timelock for community treasury...");
  
    const Timelock = await ethers.getContractFactory("WithdrawTimelock");
    const timelock = await Timelock.deploy(community.communityTreasury());
    await timelock.deployed();
  
    console.log("Timelock address: ", timelock.address);
  
    await community.activateTreasuryTimelock();

    console.log("Deploying gig registry...");
    await community.addGigsRegistry("community" + i);
    const gigsRegistryAddress = await community.gigsRegistry();
    console.log("Gig registry address: ", gigsRegistryAddress); 

    /*console.log("Linking Community to gigs registry...");
    await community.setGigsRegistry(gigsRegistry.address);*/
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

  console.log("Deploying DITO token factory");
  const DITOTokenFactory = await ethers.getContractFactory("DITOTokenFactory");
  const ditoTokenFactory = await DITOTokenFactory.deploy();
  console.log("DITO token factory address: ", ditoTokenFactory.address);

  console.log("Deploying community treasury factory");
  const CommunityTreasuryFactory = await ethers.getContractFactory("CommunityTreasuryFactory");
  const communityTreasuryFactory = await CommunityTreasuryFactory.deploy();
  console.log("Deploying community treasury factory: ", communityTreasuryFactory.address);

  console.log("Deploying gigs registry factory");
  const GigsRegistryFactory = await ethers.getContractFactory("GigsRegistryFactory");
  const gigsRegistryFactory = await GigsRegistryFactory.deploy();
  console.log("Deploying gigs registry factory: ", gigsRegistryFactory.address);

  return { 
    ditoTokenFactoryAddr: ditoTokenFactory.address, 
    communityTreasuryFactoryAddr: communityTreasuryFactory.address,
    gigsRegistryFactoryAddr: gigsRegistryFactory.address
  };
}

async function deployAddressesProvider(oracle, ditoTokenFactory, communityTreasuryFactory, gigsRegistry) {
  const [deployer] = await ethers.getSigners();

  console.log("Deploying addresses provider");
  const AddressesProvider = await ethers.getContractFactory("AddressesProvider");
  const addressesProvider = await AddressesProvider.deploy(
    dai,
    usdc,
    communityTreasuryFactory,
    ditoTokenFactory,
    gigsRegistry,
    oracle,
    landingPoolAP,
    forwarder_address
  );
  console.log("Addresses provider address: ", addressesProvider.address);
  console.log("Communities registry address: ", await addressesProvider.communitiesRegistry());

  return addressesProvider.address;
}

async function deployTreasuryDao(template, ap) {
  const [deployer] = await ethers.getSigners();

  console.log("Deploying Treasury DAO with template ", template);
  const TreasuryDAO = await ethers.getContractFactory("TreasuryDao");
  const treasuryDAO = await TreasuryDAO.deploy(template, ap, addresses[network].aaveDataProvider);

  console.log("Treasury DAO address:", treasuryDAO.address);

  return treasuryDAO.address;
}
  
main()
  .then(() => process.exit(0))
  .catch(error => {
    console.error(error);
    process.exit(1);
  });
  