const addresses = require("../addresses");
const hre = require("hardhat");
const { ethers } = require("hardhat");


async function main() {
    const network = hre.network.name;
    const [deployer] = await ethers.getSigners();

    const chainlink = addresses[network].chainlink;

    console.log("Deploying to network: ", network);
  
    console.log(
      "Deploying contracts with the account:",
      deployer.address
    );
    
    console.log("Account balance:", (await deployer.getBalance()).toString());

    console.log("Deploying Gig Validator (oracle)...");
    const GigValidator = await ethers.getContractFactory("GigValidator");
    const gigValidator = await GigValidator.deploy(chainlink.address, ethers.utils.toUtf8Bytes(chainlink.jobId));
    await gigValidator.deployTransaction.wait();
    console.log("Validator address: ", gigValidator.address);
}
  
  main()
    .then(() => process.exit(0))
    .catch(error => {
      console.error(error);
      process.exit(1);
    });
  