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
  const dao = process.env.DAO;

  if (!gigValidatorAddress) {
    console.log("Please provide Gig Validator (Oracle) address by setting ORACLE env variable");
    process.exit(0);
  };

  if (!dao) {
    console.log("Please provide TreasuryDAO address by setting DAO env variable");
    process.exit(0);
  };

  const treasuryDAO = await ethers.getContractAt("TreasuryDao", dao);
  const template = await treasuryDAO.template();

  console.log("Creating community with EXISTING treasury DAO at: ", treasuryDAO.address); 
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

  /*console.log("Linking Community to Treasury...");
  await community.setTreasury(communityTreasury.address);
  console.log("... and back");
  await communityTreasury.setCommunity(community.address);*/
  console.log("Validator address: ", gigValidatorAddress);

  console.log("Deploying gig registry...");
  const GigsRegistry = await ethers.getContractFactory("GigsRegistry");
  const gigsRegistry = await GigsRegistry.deploy(community.address, "community1", gigValidatorAddress);
  await gigsRegistry.deployTransaction.wait();
  console.log("Gig registry address: ", gigsRegistry.address); 

  console.log("Linking Community to gigs registry...");
  await community.setGigsRegistry(gigsRegistry.address);    

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
  }
}
  
main()
  .then(() => process.exit(0))
  .catch(error => {
    console.error(error);
    process.exit(1);
  });
  