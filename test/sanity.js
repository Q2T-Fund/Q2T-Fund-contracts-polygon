const { expect } = require("chai");
const addresses = require("../addresses");
const hre = require("hardhat");
const { ethers } = require("hardhat");
require('dotenv').config();

const network = hre.network.name;
const e18 = "000000000000000000";
const MAX_UINT = "115792089237316195423570985008687907853269984665640564039457584007913129639935";

let signer;
let token;
let communityTreasury;
let treasuryDAO;
let community;

const forwarder_address = addresses[network].forwarder;
const dai = addresses[network].dai;
const adai = addresses[network].adai;
const stableDebtDai = addresses[network].stableDebtDai;
const usdc = addresses[network].usdc;
const stableDebtUsdc = addresses[network].stableDebtUsdc;
const landingPoolAP = addresses[network].landingPoolAP;

describe("Deposit and borrow happy flow", function() {
    it("Should deploy community, token and treasury", async function() {
        const Community = await ethers.getContractFactory("Community");
        community = await Community.deploy(0, dai, usdc, landingPoolAP, forwarder_address);
        await community.deployed();

        const Token = await ethers.getContractFactory("DITOToken");
        token = Token.attach(await community.tokens());
        const CommunityTreasury = await ethers.getContractFactory("CommunityTreasury");
        communityTreasury = CommunityTreasury.attach(await community.communityTreasury());
        
        expect(await token.owner()).to.equal(community.address);
        expect(await communityTreasury.owner()).to.equal(community.address);
        expect(await token.balanceOf(community.address)).to.equal("94000".concat(e18));
        expect(await token.balanceOf(communityTreasury.address)).to.equal("2000".concat(e18));
    });
    it("Should deploy and link treasury dao", async function() {
        const TreasuryDAO = await ethers.getContractFactory("TreasuryDao");
        treasuryDAO = await TreasuryDAO.deploy(0, addresses[network].aaveDataProvider, dai, usdc);
        await treasuryDAO.deployed;
        
        await community.setTreasuryDAO(treasuryDAO.address);
        await treasuryDAO.linkCommunity(communityTreasury.address);
        
        expect(await communityTreasury.id()).to.equal("0");
        expect(await treasuryDAO.totalCommunities()).to.equal("1");
        expect(await communityTreasury.dao()).to.equal(treasuryDAO.address);
        expect(await treasuryDAO.communityTeasuries(0)).to.equal(communityTreasury.address);
    });
    it("Should deposit DAI through community treasry", async function() {
        await hre.network.provider.request({
            method: "hardhat_impersonateAccount",
            params: [process.env.IMPERSONATE]
        });

        signer = await ethers.provider.getSigner(process.env.IMPERSONATE);

        const Erc20 = await ethers.getContractFactory("ERC20", signer);
        const daiToken = Erc20.attach(dai);
        const adaiToken = Erc20.attach(adai);

        const TreasuryDao = await ethers.getContractFactory("TreasuryDao", signer);
        const treasuryDaoImp = TreasuryDao.attach(treasuryDAO.address);

        await daiToken.approve(treasuryDaoImp.address, "1000".concat(e18));
        await treasuryDaoImp.deposit("DAI", 1000);

        expect(await adaiToken.balanceOf(treasuryDAO.address)).to.equal("1000".concat(e18));
    });
    it("Should send DITO tokens from community to treasury upon gig completion", async function() {
        await community.completeGig(1000);

        expect(await token.balanceOf(communityTreasury.address)).to.equal("3000".concat(e18));
        expect(await token.balanceOf(community.address)).to.equal("93000".concat(e18));
    });
    it("Shoud send tokens back once theshold reached", async function() {
        await community.completeGig(1000);

        expect(await token.balanceOf(communityTreasury.address)).to.equal("2000".concat(e18));
        expect(await token.balanceOf(community.address)).to.equal("94000".concat(e18));
    });
    it("Shoud trigger credit delegation once DITO theshold reached", async function() {
        //Threshold was reached in previos test. This one just checks the delegation
        const stableDebtDaiToken = await ethers.getContractAt("ICreditDelegationToken", stableDebtDai);
        const stableDebtUsdcToken = await ethers.getContractAt("ICreditDelegationToken", stableDebtUsdc);

        expect(await stableDebtDaiToken.borrowAllowance(treasuryDAO.address, communityTreasury.address)).to.equal(MAX_UINT);
    });
    it("Should receive delegated credit", async function() {
        await communityTreasury.borrowDelegated("USDC","10".concat("000000"));

        const usdcToken = await ethers.getContractAt("IERC20", usdc);

        expect(await usdcToken.balanceOf(communityTreasury.address)).to.equal("10".concat("000000"));
    });
});
  