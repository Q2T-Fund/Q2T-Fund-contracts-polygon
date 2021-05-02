require('dotenv').config();
require("@nomiclabs/hardhat-waffle");
require("@nomiclabs/hardhat-etherscan");
require('hardhat-contract-sizer');

/**
 * @type import('hardhat/config').HardhatUserConfig
 */
module.exports = {
  defaultNetwork: "hardhat",
  networks: {
    hardhat: {
      forking: {
        url: "https://matic-mainnet-archive-rpc.bwarelabs.com",
        //url: process.env.MATICVIGIL_URL,
        blockNumber: Number(process.env.ALCHEMY_BLOCK)
      }
    },
    matic: {
      url: 'https://rpc-mainnet.maticvigil.com/',
      gasPrice: 1000000000,
      accounts: [process.env.PRIVATE_KEY]
    },
    maticTestnet: {
      url: 'https://rpc-mumbai.maticvigil.com/',
      gasPrice: 1000000000,
      accounts: [process.env.PRIVATE_KEY]
    },
    kovan: {
      chainId: 42,
      url: process.env.PROVIDER_URL_KOVAN,
      accounts: [process.env.PRIVATE_KEY],
      gas: 9500000,
      pasPrice: 20000000000
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
      },
      { 
        version: "0.6.10"
      }
    ]
  },
  contractSizer: {
    alphaSort: true,
    runOnCompile: true,
    disambiguatePaths: false,
  },
  etherscan: {
    apiKey: process.env.ETHERSCAN_API
  },
  mocha: {
    timeout: 100000
  }
};
