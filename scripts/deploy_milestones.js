const addresses = require("../addresses");
const hre = require("hardhat");
const { ethers } = require("hardhat");

const readline = require("readline");
const rl = readline.createInterface({
    input: process.stdin,
    output: process.stdout
});

const network = hre.network.name;
const dai = addresses[network].dai;
const usdc = addresses[network].usdc;
const landingPoolAP = addresses[network].landingPoolAP;

async function main(milestoneTemplate, q2tAddress, communityAddress) {
  const [deployer] = await ethers.getSigners();
  //const Token = await ethers.getContractFactory("DITOToken");

  console.log(
    "Deploying contracts with the account:",
    deployer.address
  );
  
  console.log("Account balance:", (await deployer.getBalance()).toString());
  
  console.log("----------------------------");
  console.log("Deploying one Milestones and community treasury");

  const q2t = await ethers.getContractAt("Q2T", q2tAddress);

  const createMilestonesTx = await q2t.deployMilestones(milestoneTemplate, communityAddress);

  const events = (await createMilestonesTx.wait()).events?.filter((e) => {
    return e.event == "MilestonesDeployed"
  });

  const milestonesAddress = events[0].args._milestones;
  const communityTreasuriesAddress = await q2t.milestonesTreasuries(milestonesAddress);

  console.log("Template ", milestoneTemplate, ", Milestones address: ", milestonesAddress);
  console.log("              Treasury address: ", communityTreasuriesAddress);
}

const milestoneTemplate = process.env.TEMPLATE;
const q2tAddress = process.env.Q2T;
const communityAddress = process.env.COMMUNITY;

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

console.log("Deploying to network: ", network);

console.log("About to create new Milestones and community treasury using Q2T: ", q2tAddress); 
console.log("Using Template: ", milestoneTemplate);
console.log("Using Community at address: ", communityAddress);
rl.question("Are you sure?", async function(answer) {
  if(answer == "y") {
    console.log("\n");

    await main(milestoneTemplate, q2tAddress, communityAddress)
    .then(() => process.exit(0))
    .catch(error => {
      console.error(error);
      process.exit(1);
    });
  }

  rl.close();
});

rl.on("close", function() {
    process.exit(0);
});
  

  