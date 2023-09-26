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
// See also <http://truffleframework.com/docs/advanced/configuration>

const HDWalletProvider = require('@truffle/hdwallet-provider');
const fs = require('fs');
const mnemonic = fs.existsSync('.secret') ? fs.readFileSync('.secret').toString().trim() : null;

module.exports = {
    plugins: ['truffle-plugin-verify'],

    /**
     * Networks define how you connect to your client and let you set the
     * defaults web3 uses to send transactions. If you don't specify one truffle
     * will spin up a development blockchain for you on port 9545 when you
     * run `develop` or `test`. You can ask a truffle command to use a specific
     * network from the command line, e.g
     *
     * $ truffle test --network <network-name>
     */

    networks: {
        test: {
            // we recommend Ganache CLI
            host: '127.0.0.1', // Localhost
            port: 7545, // Standard port for Ganache CLI
            network_id: '*', // Any ID will be accepted
            gas: 10000000 // can be configured as needed; 6721975 is the default block limit on Ganache CLI
        },
        development: {
            // we recommend Ganache CLI
            host: '127.0.0.1', // Localhost
            port: 8545, // Standard port for Ganache CLI
            network_id: '*', // Any ID will be accepted
            gas: 40000000, // can be configured as needed; 6721975 is the default block limit on Ganache CLI
            disableConfirmationListener: true
        },
        migration: {
            // for testing migrations locally
            host: '127.0.0.1',
            port: 7545,
            network_id: '*',
            gas: 10000000
        },
        testnet: {
            provider: () =>
                new HDWalletProvider({
                    mnemonic: {
                        phrase: mnemonic // as defined in a local .secret_energi_testnet file before deployment.
                    },
                    providerOrUrl: 'https://nodeapi.test.energi.network', // if this fails, try: 'http://172.31.77.180:49796'
                    derivationPath: "m/44'/49797'/0'/0/"
                }),
            network_id: '49797',
            gas: 40000000, // gas limit used for deploy. 40000000 is the block gas limit.
            websockets: true, // used for the confirmations listener or to hear events using .on or .once.
            verify: {
                apiUrl: 'https://explorer.test.energi.network/api',
                apiKey: 'xxxxx-no-api-key-needed-xxxxx',
                explorerUrl: 'https://explorer.test.energi.network/address',
            },
        },
        mainnet: {
            provider: () =>
                new HDWalletProvider({
                    mnemonic: {
                        phrase: mnemonic // change to desired mnemonic in a local .secret_energi file before deployment.
                    },
                    providerOrUrl: 'https://nodeapi.energi.network',
                    derivationPath: "m/44'/39797'/0'/0/"
                }),
            network_id: '39797',
            from: '0x123...890', // = change token minter
            gas: 40000000, // gas limit used for deploy. 40000000 is the block gas limit.
            websockets: true, //Used for the confirmations listener or to hear events using .on or .once.
            verify: {
                apiUrl: 'https://explorer.energi.network/api',
                apiKey: 'xxxxx-no-api-key-needed-xxxxx',
                explorerUrl: 'https://explorer.energi.network/address',
            },
        }
    },
    mocha: {
        useColors: true
    },
    compilers: {
        solc: {
            version: '0.8.17',
            evmVersion: 'istanbul',
            optimizer: {
                enabled: true,
                runs: 200
            }
        }
    }
};
