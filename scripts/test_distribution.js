const addresses = require("../addresses");
const hre = require("hardhat");
const { ethers } = require("hardhat");
require('dotenv').config();

async function main () {
    const network = hre.network.name;
    const [deployer] = await ethers.getSigners();

    const stableDebtUsdc = "0x252c017036b144a812b53bc122d0e67cbb451ad4";


    const gigHashIncompl = "0xFFB3886F389F27BC1F2A41F0ADD45A84453F0D2A877FCD1225F13CD95953A8";

    const gigs = [
        ["400", "100", "81", "144"], //comm 1
        ["1600"], //comm 2
        ["900", "900", "100"] //comm 3
    ];

    const gigsProjects = [
        [
            "0x1111111111111111111111111111111111111111",
            "0x1111111111111111111111111111111111111111",
            "0x1111111111111111111122222222222222222222",
            "0x1111111111111111111122222222222222222222"
        ],
        [
            "0x2222222222222222222222222222222222222222"
        ],
        [
            "0x3333333333333333333333333333333333333333",
            "0x3333333333333333333333333333333333333333",
            "0x3333333333333333333333333333333333333333"
        ]
    ];

    //let communities = [];
    const grAddresses = [
        "0x702fD6F0eb39FA5911106C27b488771C14fa0127",
        "0x4724A57e7841c0A9CCd04A405F81E298E75a9504",
        "0x72f0eA5067FD8d9fE5Db7FB6c7e02B8eD4086B00"
    ];

    const treasuriesAddresses = [
        "0x3CFCae3fe95f555783E13DF1ce6697602608f66D",
        "0x65F08477152f9ca46c50dA602C26fc310Df953a1",
        "0xBf55774377039fcdA269D697d7567E56e999816D"
    ];

    const daoAddress = "0x912261b12Dfcb4f13c8955324870cA21676F6291";

    const communitiesNumber = treasuriesAddresses.length;

    let communityTreasuries = [];
    let gigsRegistries = [];

    const skipCommunities = 3;
    const skipGigs = 2;

    const hashSuffix = 50;

    if(network != "kovan") {
        console.log("Please use Kovan testnet");
        process.exit(0);
    }

    const GigsRegistry = await ethers.getContractFactory("GigsRegistry");
    const CommunityTreasury = await ethers.getContractFactory("CommunityTreasury");

    for (let i = 0; i < communitiesNumber; i++) {
        communityTreasuries.push(CommunityTreasury.attach(treasuriesAddresses[i]));
        gigsRegistries.push(GigsRegistry.attach(grAddresses[i]));
    }

    console.log("--------------------------------");
    for (let i = 0; i < gigs.length; i++) {
        console.log("Community ", i);
        console.log("Gig registry ", gigsRegistries[i].address);
        console.log("Treasury: ", communityTreasuries[i].address);
        if (i < skipCommunities) {
            console.log("Skipping");
        }
        if (gigs[i].length > 0 && i >= skipCommunities) {
            for (let j = 0; j < gigs[i].length; j++) {
                const gigHash = gigHashIncompl + String(hashSuffix);
                hashSuffix++;

                console.log(gigsProjects[2][0]);

                if (i == skipCommunities && j < skipGigs) {
                    console.log("   Skipping");
                    continue;
                }

                console.log("   Gig ", gigHash);
                
                console.log("   Register...");
                console.log("   Project: ", gigsProjects[i][j]);
                await gigsRegistries[i].createMilestone(gigHash, gigsProjects[i][j]);
                const [id, ] = await gigsRegistries[i].gigIdLookup(deployer.address, gigHash);
                
                console.log("   Id = ", String(id));
                console.log("   Take...");
                await gigsRegistries[i].takeGig(id);

                console.log("   Complete with ", gigs[i][j], "credits...");
                await gigsRegistries[i].completeGig(id, deployer.address, gigHash, gigs[i][j]);
                
                console.log("   Treasury DiTo balance");
                console.log("   ", communityTreasuries[i].address, String(await communityTreasuries[i].getDitoBalance()));
            }
        }
        console.log("--------------------------------");
    }

    const stableDebtUsdcToken = await ethers.getContractAt("ICreditDelegationToken", stableDebtUsdc);

    console.log("Borrow allowances: ");
    for (let i = 0; i < communitiesNumber; i++) {
        console.log(
            communityTreasuries[i].address, ":", 
            String(await stableDebtUsdcToken.borrowAllowance(
                daoAddress, communityTreasuries[i].address)
            ));
    }
}

main()
  .then(() => process.exit(0))
  .catch(error => {
    console.error(error);
    process.exit(1);
  });