# Software Development Kit (SDK)

The `sdk` folder has configuration files for Hardhat and Truffle. They will help set up your development environment so you can deploy and verify your smart contracts on the Energi blockchain.

## 1. Install Extenstion

### 1.1. Energi Core Node

#### 1.1.1. Energi SDK

Add the library to the project by the following commands:

```bash title="NPM"
npm install @energi/energi-sdk
```

or

```bash title="Yarn"
yarn add @energi/energi-sdk
```


#### 1.1.2. Energi Web3js extension

This module comes with three features:

- web3.js extensions: `web3.nrg`, `web3.energi` and `web3.masternode`
- `EnergiTxCommon`, to be used along with `require('ethereumjs-tx').Transaction`, enabling signed transaction to the Energi testnet and mainnet
- Energi unit maps, so you can use `web3.utils.toWei('1', 'nrg')`

Note that Energi Unit Maps, like `web3.utils.toWei('1', 'nrg')`, can only be used on a `web3` instance, not directly with `Web3`.

Run the following to install the extension:

**NPM:**

```bash title="NPM"
npm install @energi/web3-ext
```

or

**Yarn:**

```bash title="Yarn"
yarn add @energi/web3-ext
```

For details on the SDK visit [https://www.npmjs.com/package/@energi/web3-ext](https://www.npmjs.com/package/@energi/web3-ext)


### 1.2. Energiswap

#### 1.2.1. SDK for building applications on top of Energiswap

The Energiswap SDK is provided to help developers build on top of Energiswap. It runs in any environment that can execute JavaScript (example: websites, node scripts, etc.). 

Run the following to install the extension:

**NPM:**

```bash title="NPM"
npm install @energi/energiswap-sdk
```

or

**Yarn:**

```bash title="Yarn"
yarn add @energi/energiswap-sdk
```

For details on the SDK visit  [https://www.npmjs.com/package/@energi/energiswap-sdk](https://www.npmjs.com/package/@energi/energiswap-sdk)


#### 1.2.2. Smart contracts for Energiswap

**NPM:**

```bash title="NPM"
npm install @energi/energiswap-contracts
```

#### 1.2.3. The Token Lists specification

**NPM:**

```bash title="NPM"
npm install @energi/energiswap-token-lists
```

#### 1.2.4. Energiswap Default Token List

**NPM:**

```bash title="NPM"
npm install @energi/energiswap-default-token-list
```