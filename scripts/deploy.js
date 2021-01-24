const addresses = require("../addresses");
const hre = require("hardhat");


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
    const community = await Community.deploy(forwarder_address, token.address);
  
    console.log("Community address:", community.address);

    tokenBalance = await token.balanceOf(deployer.address);
    console.log(String(tokenBalance));
    //if()
    console.log("Transfering tokens to Community");
    await token.transfer(community.address, tokenAmount);
    console.log("Community balance: ", String(await token.balanceOf(community.address)));
}
  
  main()
    .then(() => process.exit(0))
    .catch(error => {
      console.error(error);
      process.exit(1);
    });
  