const addresses = require("../addresses");
const hre = require("hardhat");
const { ethers } = require("hardhat");

const readline = require("readline");
const rl = readline.createInterface({
    input: process.stdin,
    output: process.stdout
});

async function main() {
  const gigValidatorAddress = process.env.ORACLE;
  const template = process.env.TEMPLATE;

  if (!gigValidatorAddress) {
    console.log("Please provide Gig Validator (Oracle) address by setting ORACLE env variable");
    process.exit(0);
  };

  if (!template || template > 2 || template < 0) {
    console.log("Please provide correct template (0-2) TEMPLATE env variable");
    process.exit(0);
  };

  console.log("Creating community with NEW treasury DAO."); 
  console.log("Using Template: ", template, " and setting Gig Validator to: ", gigValidatorAddress);
  rl.question("Are you sure?", function(answer) {
    if(answer != "y") {
      process.exit(0);
    }
  });
  
  const network = hre.network.name;
  const [deployer] = await ethers.getSigners();
  const Token = await ethers.getContractFactory("DITOToken");

  const forwarder_address = addresses[network].forwarder;
  const dai = addresses[network].dai;
  const usdc = addresses[network].usdc;
  const landingPoolAP = addresses[network].landingPoolAP;

  console.log("Deploying to network: ", network);

  console.log(
    "Deploying contracts with the account:",
    deployer.address
  );
  
  console.log("Account balance:", (await deployer.getBalance()).toString());

  console.log("Forwarder address:", forwarder_address);
  console.log("Deploying Community...");

  const Community = await ethers.getContractFactory("Community");
  const community = await Community.deploy(template, dai, usdc, landingPoolAP, forwarder_address);
  await community.deployTransaction.wait();

  console.log("Community address:", community.address);
  const token = Token.attach(await community.tokens());
  console.log("Token address:", await community.tokens());

  console.log("Community balance: ", String(await token.balanceOf(community.address)));

  //console.log("Deploying Community Treasury...");
  
  const CommunityTreasury = await ethers.getContractFactory("CommunityTreasury");
  //const communityTreasury = await CommunityTreasury.deploy(0, token.address);
  //await communityTreasury.deployTransaction.wait();
  const communityTreasury = CommunityTreasury.attach(await community.communityTreasury());

  console.log("Community Treasury address:", communityTreasury.address);

  console.log("Validator address: ", gigValidatorAddress);

  console.log("Deploying gig registry...");
  const GigsRegistry = await ethers.getContractFactory("GigsRegistry");
  const gigsRegistry = await GigsRegistry.deploy(community.address, "community1", gigValidatorAddress);
  await gigsRegistry.deployTransaction.wait();
  console.log("Gig registry address: ", gigsRegistry.address); 

  console.log("Linking Community to gigs registry...");
  await community.setGigsRegistry(gigsRegistry.address);    

  console.log("Deploying Treasury DAO...");
  
  const TreasuryDAO = await ethers.getContractFactory("TreasuryDao");
  const treasuryDAO = await TreasuryDAO.deploy(template, addresses[network].aaveDataProvider, dai, usdc);
  await treasuryDAO.deployTransaction.wait();

  console.log("Treasury DAO address:", treasuryDAO.address);

  console.log("Linking Community Treasury to DAO...");
  await community.setTreasuryDAO(treasuryDAO.address);
  console.log("... and back");
  await treasuryDAO.linkCommunity(communityTreasury.address);

  console.log("Deploying and activating timelock for community treasury...");
  
  const Timelock = await ethers.getContractFactory("WithdrawTimelock");
  const timelock = await Timelock.deploy(communityTreasury.address);
  await timelock.deployed;

  console.log("Timelock address: ", timelock.address);

  await community.activateTreasuryTimelock();
}
  
main()
  .then(() => process.exit(0))
  .catch(error => {
    console.error(error);
    process.exit(1);
  });
  