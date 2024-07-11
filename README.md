# energi3-provisioning

## Scripts

This repository has provisioning scripts as well as startup scrits for Energi Core Node

- Linux / VPS <br>
-- energi3-linux-installer.sh : Provisioning Script for amd64 or x86_64 Linux
-- energi3-aarch64-installer.sh : Provisioning Script for RPi and i386 (32-bit Linux)
-- start_staking.sh           : Start Staking<br>
-- start_screen_staking.sh    : Start Staking within `screen`<br>
-- start_mn.sh                : Start Masternode<br>
-- start_screen_mn.sh         : Start Masternode  within `screen`<br>
-- energi3-cli                : Wrapper command-line script<br>
 
- Windows <br>
 -- energi3-windows-installer.bat : Provisioning Script<br>
 -- start_mn.bat                  : Start Masternode<br>
 -- start_staking.bat             : Start Staking<br>
 -- energi3.ico                   : Energi Icon Logo<br>

- MacOS <br>
-- energi3-macos-installer.sh     : Provisioning Script<br>
-- start_node.sh                  : Script to start staking/mastrnode in mainnet or testnet<br>
-- start_staking.sh               : Start Staking<br>
-- start_mn.sh                    : Start Masternode<br>

## Add Peers
If you are having issues with low peer nodes, do the following.

- 1. If you are running your core on a Linux VPS, [login to the VPS](https://wiki.energi.world/docs/guides/scripted-linux-installation#2---login-to-your-vps)
- 2. Attach to core node
  - 2.1. Linux / Mac: Run the following command after you login to the VPS

```
energi3 attach
```

  - 2.2. Windows: Start [Attach](https://wiki.energi.world/docs/guides/core-node-windows#2---start-core-node--attach)


- 3. Goto https://github.com/energicryptocurrency/energi3-provisioning/blob/master/scripts/linux/bootnodes-mainnet.txt and copy the content.

- 4. Paste the content to core node console.

## SDK Configuration Files

- hardhat                         : Hardhad config files
- truffle                         : Truffle config files

## Energi Docker Compose

Files in `docker-compose` are meant to be used to spin up a Docker environment to run Energi Core node. It is monitored via `nodemon` which can send alerts to Discord and/or Telegram.
