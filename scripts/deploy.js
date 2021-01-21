const addresses = require("../addresses");
const hre = require("hardhat");


async function main() {
    const network = hre.network.name;
    const [deployer] = await ethers.getSigners();

    const forwarder_address=addresses[network].forwarder;
    let token_address;
  
    console.log(
      "Deploying contracts with the account:",
      deployer.address
    );
    
    console.log("Account balance:", (await deployer.getBalance()).toString());

    if(!addresses[network].token) {
        console.log("Deploying DITOTOken...");
        const Token = await ethers.getContractFactory("DITOToken");
        const token = await Token.deploy(ethers.utils.parseEther("96000"));
        token_address = token.address;
    } else {
        console.log("Using exiting DITOToken");
        token_address = addresses[network].token;
    }
    console.log("Token address:", token_address);
    console.log("Forwarder address:", forwarder_address);
    console.log("Deploying Community...");
  
    const Community = await ethers.getContractFactory("Community");
    const community = await Community.deploy(forwarder_address, token_address);
  
    console.log("Community address:", community.address);
}
  
  main()
    .then(() => process.exit(0))
    .catch(error => {
      console.error(error);
      process.exit(1);
    });
  