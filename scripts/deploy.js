const addresses = require("../addresses");
const hre = require("hardhat");
const { ethers } = require("hardhat");


async function main() {
    const network = hre.network.name;
    const [deployer] = await ethers.getSigners();
    const Token = await ethers.getContractFactory("DITOToken");

    const forwarder_address = addresses[network].forwarder;
    const dai = addresses[network].dai;
    const usdc = addresses[network].usdc;
    const landingPoolAP = addresses[network].landingPoolAP;
  
    console.log(
      "Deploying contracts with the account:",
      deployer.address
    );
    
    console.log("Account balance:", (await deployer.getBalance()).toString());

    console.log("Forwarder address:", forwarder_address);
    console.log("Deploying Community...");
  
    const Community = await ethers.getContractFactory("Community");
    const community = await Community.deploy(0, dai, usdc, landingPoolAP, forwarder_address);
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
    

    console.log("Deploying Treasury DAO...");
    
    const TreasuryDAO = await ethers.getContractFactory("TreasuryDao");
    const treasuryDAO = await TreasuryDAO.deploy(addresses[network].aaveDataProvider, dai, usdc);
    await treasuryDAO.deployTransaction.wait();

    console.log("Treasury DAO address:", treasuryDAO.address);

    console.log("Linking Community Treasury to DAO...");
    await community.setTreasuryDAO(treasuryDAO.address);
    console.log("... and back");
    await treasuryDAO.setCommunityTreasury(communityTreasury.address, 0);
}
  
  main()
    .then(() => process.exit(0))
    .catch(error => {
      console.error(error);
      process.exit(1);
    });
  