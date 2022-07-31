require("@nomicfoundation/hardhat-toolbox");

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  solidity: "0.8.9",
  networks: {
    fuji: {
      url: " https://api.avax-test.network/ext/bc/C/rpc",
      chainId: 43113,
      accounts: [
        "0x863ae50e6bc33955d0d5b951d8712b7cceabf181878e5560729d461c37cd28f2",
      ],
    },
    mumbai: {
      url: "https://rpc-mumbai.maticvigil.com",
      chainId: 80001,
      accounts: [
        "0xa572b6a74b1371ff3de58ed16e5f67bcc82621ed979f604a98a0a2925744fce9",
      ],
    },
  },
};
