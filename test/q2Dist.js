const { expect } = require("chai");
const addresses = require("../addresses");
const hre = require("hardhat");
const { ethers } = require("hardhat");
require('dotenv').config();

const network = hre.network.name;
const e18 = "000000000000000000";
const MAX_UINT = "115792089237316195423570985008687907853269984665640564039457584007913129639935";

let q2Dist;

/*const contributions = [
    ["16".concat(e18), "25".concat(e18), "36".concat(e18)],
    ["64".concat(e18)],
    ["49".concat(e18), "25".concat(e18)]
];*/

const contributions = [
    ["164".concat(e18), "125".concat(e18), "360".concat(e18)],
    ["764".concat(e18)],
    ["549".concat(e18), "625".concat(e18)]
];


let unweighted = [];
let weights = [];
let weighted = [];

const totalFunds = "10000000".concat(e18);

describe("Quadratic Distribution", function() {
    it("Should deploy quadratic distribution lib", async function() {
        const QuadraticDistribution = await ethers.getContractFactory("Q2DistTest");
        q2Dist = await QuadraticDistribution.deploy();
        await q2Dist.deployed();
        console.log(q2Dist.me)

        expect(q2Dist.address).not.to.be.undefined;
    });
    it("Should return unweghted allocations", async function() {
        for (let i = 0; i < contributions.length; i++) {
            unweighted.push(String(await q2Dist.calcUnweightedAlloc(contributions[i])));
            console.log(unweighted[i]);
        }        
    });
    it("Should Calculate weights", async function() {
        weights = await q2Dist.calcWeights(unweighted);

        for (let i = 0; i < weights.length; i++) {
            console.log(String(weights[i]));
        }
    });
    it("Should return weighted allocations", async function() {
        weighted = await q2Dist.calcWeightedAlloc(totalFunds, weights);

        for (let i = 0; i < weighted.length; i++) {
            console.log(String(weighted[i]).slice(0, -14));
        }
        
        console.log(totalFunds.slice(0, -18));
    });
});

