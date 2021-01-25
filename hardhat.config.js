require('dotenv').config();
require("@nomiclabs/hardhat-waffle");

/**
 * @type import('hardhat/config').HardhatUserConfig
 */
module.exports = {
  defaultNetwork: "hardhat",
  networks: {
    hardhat: {},
    kovan: {
      url: process.env.PROVIDER_URL_KOVAN,
      accounts: [process.env.PRIVATE_KEY]
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
  }
};
