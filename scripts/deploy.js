const addresses = require("../addresses");
const hre = require("hardhat");
const { ethers } = require("hardhat");


async function main() {
    const network = hre.network.name;
    const [deployer] = await ethers.getSigners();
    const Token = await ethers.getContractFactory("DITOToken");
    let token;
    const tokenAmount = ethers.utils.parseEther("96000");

    const forwarder_address=addresses[network].forwarder;
    
  
    console.log(
      "Deploying contracts with the account:",
      deployer.address
    );
    
    console.log("Account balance:", (await deployer.getBalance()).toString());

    if(!addresses[network].token) {
        console.log("Deploying DITOTOken...");    
        token = await Token.deploy(tokenAmount);
    } else {
        console.log("Using exiting DITOToken");
        token = Token.attach(addresses[network].token);
    }
    console.log("Token address:", token.address);
    console.log("Forwarder address:", forwarder_address);
    console.log("Deploying Community...");
  
    const Community = await ethers.getContractFactory("Community");
    const community = await Community.deploy("test", forwarder_address, token.address);
  
    console.log("Community address:", community.address);

    //tokenBalance = await token.balanceOf(deployer.address);
    console.log("Transfering tokens and ownership to Community");
    await token.addToWhitelist(community.address);
    await token.transferOwnership(community.address);
    await token.transfer(community.address, tokenAmount);
    console.log("Community balance: ", String(await token.balanceOf(community.address)));

    console.log("Deploying Community Treasury...");
    
    const CommunityTreasury = await ethers.getContractFactory("CommunityTreasury");
    const communityTreasury = await CommunityTreasury.deploy(0, token.address);

    console.log("Community Treasury address:", communityTreasury.address);

    console.log("Linking Community Treasury to Community...");
    await communityTreasury.setCommunity(community.address);
    console.log("... and back");
    await community.setTreasury(communityTreasury.address);

    console.log("Deploying Treasury DAO...");
    
    const TreasuryDAO = await ethers.getContractFactory("TreasuryDao");
    const treasuryDAO = await TreasuryDAO.deploy(addresses[network].aaveDataProvider);

    console.log("Community Treasury address:", treasuryDAO.address);

    console.log("Linking Community Treasury to DAO...");
    await communityTreasury.setTreasuryDAO(treasuryDAO.address);
    console.log("... and back");
    await treasuryDAO.setCommunityTreasury(communityTreasury.address, 0);
}
  
  main()
    .then(() => process.exit(0))
    .catch(error => {
      console.error(error);
      process.exit(1);
    });
  