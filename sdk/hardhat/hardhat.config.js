// Copyright 2023 The Energi Core Authors
// This file is part of the Energi Core library.
//
// The Energi Core library is free software: you can redistribute it and/or modify
// it under the terms of the GNU Lesser General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// The Energi Core library is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// GNU Lesser General Public License for more details.
//
// You should have received a copy of the GNU Lesser General Public License
// along with the Energi Core library. If not, see <http://www.gnu.org/licenses/>.
//

require("@nomicfoundation/hardhat-toolbox");
require('dotenv').config();

// set variables from .env file
const { RPC_URL, ACCOUNT_PRIVATE_KEY } = process.env;

// Configure network accounts
const { DEV_ACCOUNTS } = require('./common/constants');
const devAccounts = DEV_ACCOUNTS;

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  solidity: {
    version: '0.8.17',
    settings: {
      evmVersion: 'istanbul',
      optimizer: {
        enabled: true,
        runs: 200,
      },
    },
  },
  defaultNetwork: "hardhat",
  networks: {
    hardhat: {
      accounts: devAccounts,
      blockGasLimit: 10000000,
    },
    energiMainnet: {
      chainId: 39797,
      url: String(RPC_URL || "https://nodeapi.energi.network"),
      gas: 1000000,
      gasPrice: 20000000000, // 20 GWei
      accounts: [`0x${ACCOUNT_PRIVATE_KEY}`],
    },
    energiTestnet: {
      chainId: 49797,
      url: String(RPC_URL || "https://nodeapi.test.energi.network"),
      gas: 1000000,
      gasPrice: 20000000000, // 20 GWei
      accounts: [`0x${ACCOUNT_PRIVATE_KEY}`],
    },
  },
  etherscan: {
    apiKey: {
      energiTestnet: 'xxxxx-no-api-key-needed-xxxxx',
      energiMainnet: 'xxxxx-no-api-key-needed-xxxxx'
    },
    customChains: [
      {
        network: "energiMainnet",
        chainId: 39797,
        urls: {
          apiURL: "https://explorer.energi.network/api",
          browserURL: "https://explorer.energi.network"
        },
      },
      {
        network: "energiTestnet",
        chainId: 49797,
        urls: {
          apiURL: "https://explorer.test.energi.network/api",
          browserURL: "https://explorer.test.energi.network"
        },
      },
    ]
  },
};
