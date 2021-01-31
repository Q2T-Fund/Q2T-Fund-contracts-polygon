require('dotenv').config();
require("@nomiclabs/hardhat-waffle");
require('hardhat-contract-sizer');

/**
 * @type import('hardhat/config').HardhatUserConfig
 */
module.exports = {
  defaultNetwork: "hardhat",
  networks: {
    hardhat: {
      forking: {
        url: process.env.ALCHEMY_URL,
        blockNumber: Number(process.env.ALCHEMY_BLOCK)
      }
    },
    kovan: {
      chainId: 42,
      url: process.env.PROVIDER_URL_KOVAN,
      accounts: [process.env.PRIVATE_KEY],
      gas: 9500000
    },
    mainnet: {
      url: process.env.PROVIDER_URL_MAIN,
      accounts: [process.env.PRIVATE_KEY]
    }
  },
  solidity: {
    compilers: [
      { 
        version: "0.7.4"
      }
    ]
  },
  contractSizer: {
    alphaSort: true,
    runOnCompile: true,
    disambiguatePaths: false,
  }
};
