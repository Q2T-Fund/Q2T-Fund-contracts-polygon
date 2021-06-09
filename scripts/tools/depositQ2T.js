const addresses = require("../../addresses");
const hre = require("hardhat");
const { ethers } = require("hardhat");

const e18 = "000000000000000000";
const MAX_UINT = "115792089237316195423570985008687907853269984665640564039457584007913129639935";

const network = hre.network.name;
const dai = addresses[network].dai;
const q2tAddress = "0x75609e5C1334C0bfB7F99Eb91a92be9069E6Ef38";

async function main() {
    //const [signer] = await ethers.getSigners();
    const q2t = await ethers.getContractAt("Q2TAaveless", q2tAddress);
    const daiContract = await ethers.getContractAt("ERC20", dai);

    await daiContract.approve(q2t.address, MAX_UINT);
    await q2t.deposit(1, "10".concat(e18), 20);

    console.log("Done");
}

main()
  .then(() => process.exit(0))
  .catch(error => {
    console.error(error);
    process.exit(1);
  });