import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";

const config: HardhatUserConfig = {
  solidity: "0.8.18",
  etherscan: {
    apiKey: {
      polygonMumbai: 'HIMBJ4BN61YFH6BFEFH87JE1HYWQZRICAX',
      polygon: 'HIMBJ4BN61YFH6BFEFH87JE1HYWQZRICAX',
      bsc: 'XWM3SG4TYSAA5VKDS249GZ399ZSPIMWK72',
      optimisticEthereum: 'R4TTCRFDM7CYW53G1WM46PH53248VQMM4C'
    }
  },
  networks: {
    mumbai: {
      url: process.env.MUMBAI_URL || "",
      // accounts: [process.env.POLYGON_KEY],
    },
    polygon: {
      url: process.env.POLYGON_URL || "",
      // accounts: [process.env.POLYGON_KEY],
      gasPrice: 190000000000,
    }
  }
};

export default config;
