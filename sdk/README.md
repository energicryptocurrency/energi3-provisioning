# Software Development Kit (SDK)

The `sdk` folder has configuration files for Hardhat and Truffle. They will help set up your development environment so you can deploy and verify your smart contracts on the Energi blockchain.

**Networks to connect to (providers):**

- Testnet: https://nodeapi.test.energi.network
- Mainnet: https://nodeapi.energi.network

Here are guides on how you can launch your own core node and connect on either port 39797 (mainnet) or 49797 (testnet).

- [Set up Linux VPS](https://wiki.energi.world/docs/guides/linux-vps)
- [Install Core Node on Linux VPS](https://wiki.energi.world/docs/guides/scripted-linux-installation)


## 1. Install Extenstion

Check out the [NPM Package site](https://www.npmjs.com/search?q=%40energi) for details of the extensions noted below.

### 1.1. Energi Core Node

#### 1.1.1. Energi Web3js extension

This module comes with three features:

- web3.js extensions: `web3.nrg`, `web3.energi` and `web3.masternode`
- `EnergiTxCommon`, to be used along with `require('ethereumjs-tx').Transaction`, enabling signed transaction to the Energi testnet and mainnet
- Energi unit maps, so you can use `web3.utils.toWei('1', 'nrg')`

Note that Energi Unit Maps, like `web3.utils.toWei('1', 'nrg')`, can only be used on a `web3` instance, not directly with `Web3`.

Run the following to install the extension:

|          NPM                 |            Yarn           |
| ---------------------------- | ------------------------- |
| npm install @energi/web3-ext | yarn add @energi/web3-ext |


#### 1.1.2. Energi SDK

Add the library to the project by the following commands:

|            NPM                 |             Yarn            |
| ------------------------------ | --------------------------- |
| npm install @energi/energi-sdk | yarn add @energi/energi-sdk |


### 1.2. Energiswap

#### 1.2.1. SDK for building applications on top of Energiswap

The Energiswap SDK is provided to help developers build on top of Energiswap. It runs in any environment that can execute JavaScript (example: websites, node scripts, etc.). 

Run the following to install the extension:

|               NPM                  |               Yarn              |
| ---------------------------------- | ------------------------------- |
| npm install @energi/energiswap-sdk | yarn add @energi/energiswap-sdk |


#### 1.2.2. Smart contracts for Energiswap

Energiswap is a decentralized protocol for automated token exchange. 

|                   NPM                    |                   Yarn                |
| ---------------------------------------- | ------------------------------------- |
| npm install @energi/energiswap-contracts | yarn add @energi/energiswap-contracts |


#### 1.2.3. The Token Lists Specification

Energiswap Token Lists is a specification for lists of token metadata (e.g. address, decimals, ...) that can be used by any dApp interfaces that needs one or more lists of tokens.

Anyone can create and maintain a token list, as long as they follow the specification.

Specifically an instance of a token list is a JSON blob that contains a list of ERC20 token metadata for use in dApp user interfaces. Token list JSON must validate against the JSON schema in order to be used in the Energiswap Interface. Tokens on token lists, and token lists themselves, are tagged so that users can easily find tokens.

|                   NPM                      |                   Yarn                  |
| ------------------------------------------ | --------------------------------------- |
| npm install @energi/energiswap-token-lists | yarn add @energi/energiswap-token-lists |


#### 1.2.4. Energiswap Default Token List

This NPM module contains the default token list for all dApss used in the Energi ecosystem. It also contains all SVG logo files.

|                      NPM                          |                      Yarn                      |
| ------------------------------------------------- | ---------------------------------------------- |
| npm install @energi/energiswap-default-token-list | yarn add @energi/energiswap-default-token-list |
