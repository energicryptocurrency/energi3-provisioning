# Energi Core Node in a Docker container using Docker Compose

The original files were cloned from [Github Repo](https://github.com/eandersons/energi-docker-compose) by [Edgars](https://github.com/eandersons). The private keys embedded in the repo was removed to ensure there is no back door to the environment.

This repository is meant to ease running Energi Core Node in a Docker container
using [Docker Compose](https://docs.docker.com/compose/) and the official
[Energi image](https://hub.docker.com/r/energicryptocurrency/energi).

As Energi Core node officially can be run on macOS, Ubuntu and Windows (menu
subsections "Staking Guides" and "VPS Guides" in
[Energi Support Wiki](https://wiki.energi.world/en/home)), this repository is
intended for use on non-Ubuntu Linux machines, though `energi-docker-compose`
can be used on Ubuntu as well and it should work on macOS too.
Theoretically this repository should also work on Windows by using WSL and maybe
Git Bash or any other Linux shell emulator that supports commands used in the
helper shell script [`helper`](helper).

---

- [Prerequisites](#prerequisites)
- [Run Energi Core Node](#run-energi-core-node)
- [Masternode](#masternode)
- [Troubleshooting](#troubleshooting)
  - [Apply preimages](#apply-preimages)
  - [Bootstrap chaindata](#bootstrap-chaindata)
- [Energi Core Node Monitor](#energi-core-node-monitor)
- [Update](#update)
- [Helper script](#helper-script)
- [Credits](#credits)

---

## Prerequisites

Requirements to run a Energi Core Node in a Docker container:

- [Docker](https://docs.docker.com/engine/install/);
- [Docker Compose](https://docs.docker.com/compose/install/);
- enough free space to store blockchain data (at the beginning of January 2022
  size of the Energi Core Node data volume is roughly 50 GB).

## Run Energi Core Node

To run Energi Core Node in a Docker container:

- clone this git repository:
  `git clone https://github.com/eandersons/energi-docker-compose.git`;
- create the following files:

  - `configuration/energi_account_address` that contains the Energi account
    address;

    to add multiple accounts for staking, they must be specified as a comma
    separated list of addresses;

  - `configuration/energi_account_password` that contains the Energi account
    password;

    to use multiple accounts for staking each password must be entered in a
    separate line in the same order addresses are specified in
    `configuration/energi_account_address`; these files are used to get
    account's address and password to automatically unlock account for staking
    when launching Energi Core Node;

- copy keystore file(s) to
  [`setup/.energi_core/keystore`](setup/.energi_core/keystore);

  > Note: original keystore file(s) should be stored in a safe place as the
  > keystore file(s) that will be placed in the directory
  > [`setup/.energi_core/keystore`](setup/.energi_core/keystore) will be moved
  > to a Docker volume.

- open the necessary ports for external inbound access in router and/or
  firewall:

  - `39797` TCP;
  - `39797` UDP;

  `39797` TCP and UDP ports are required for staking and Masternode as it is
  mentioned
  [here (section "1.7. Firewall Rules")](https://wiki.energi.world/en/advanced/core-node-vps#h-17-firewall-rules);

- optionally, the Energi Core Node Monitor container can be enabled;
  instructions on how to do it can be found in
  [`nodemon/ReadMe.md`](nodemon/ReadMe.md);
- to move keystore file to the Energi data directory volume, bootstrap chaindata
  and start the Energi Core Node container the following command should be
  executed: `./helper setup core` (or `./helper setup` if Energi Core Node
  Monitor container should be set up and started as well and all the neccessary
  preparation for it has been done);

  > `docker compose` is used in `./helper setup` so `sudo` might be necessary.

The aforementioned actions must be executed only once - when running Energi Core
Node container for the first time. Later on container can be started with the
command `docker compose up --detach` or with the helper command
`./helper start`.

To check if Energi Core Node is running and account is unlocked for staking, the
command `./helper status` should be executed. When Energi Core Node is fully
synchronised, value under `nrg.syncing:` is `false` and value for `miner` and
`staking` in the output under `miner.stakingStatus():` is `true`. If not, a
block synchronisation might be in progress and `./helper status` should be
executed after a while again to check if Energi Core Node is syncrhonised.

## Masternode

`energi-docker-compose` is masternode ready. Masternode can be enabled by
following the official
[Masternode Guide](https://wiki.energi.world/en/masternode-guide).

A helper command is available to get masternode enode URL:
`./helper masternode-enode-url` (shorter aliases are available as well:
`masternode-enode`, `mn-enode-url`, `mn-enode`). It covers steps 3.1 and 3.2
from the section
[Announcing the Masternode](https://wiki.energi.world/en/masternode-guide#h-3-announcing-the-masternode).\
Alternatively step 3.1 can be executed with `./helper attach`, then 3.2 as
described in the guide.

## Troubleshooting

General troubleshooting is described in the official
[Energi troubleshooting guide](https://wiki.energi.world/en/core-node-troubleshoot).

The following actions executed one by one might help if something goes sideways
with chain synchronisation in Energi Core Node container:

1. [apply preimages](#apply-preimages);

   if the problem is not solved, the next step should be executed;

2. [bootstrap chaindata](#bootstrap-chaindata).

If applying preimages and bootstraping chaindata did not help, it might help if
those actions are executed again.
[Energi support](https://wiki.energi.world/en/support/help-me) should be
contacted if the problem is still persistent after multiple tries.

### Apply preimages

Official Energi documentation:
[Apply Preimages](https://wiki.energi.world/en/core-node-troubleshoot#preimages).

To apply preimages for Energi Core Node container the following command
can be used: `./helper apply-preimages`.

> `docker compose` is used in `./helper apply-preimages` so `sudo` might be
> necessary.

### Bootstrap chaindata

Official Energi documentation:
[Bootstrap Chaindata](https://wiki.energi.world/en/core-node-troubleshoot#bootstrap).

To bootstrap chaindata for Energi Core Node container the following command can
be used: `./helper bootstrap-chaindata`.

> `docker compose` is used in `./helper bootstrap-chaindata` so `sudo` might be
> necessary.

## Energi Core Node Monitor

It is possible to enable Energi Core Node Monitor. Instructions on how to set it
up are located in [`nodemon/ReadMe.md`](nodemon/ReadMe.md).

Energi Core Node Monitor container provides some additional features that can be
enabled optionally:

- configurable interval between Monitor runs
  ([`ECNM_INTERVAL`](nodemon/ReadMe.md#ecnm_interval));
- configurable timezone for time display in messages
  ([`MESSAGE_TIME_ZONE`](nodemon/ReadMe.md#message_time_zone));
- display the current Enrgi market price in the configured currency in
  information messages
  ([`MARKET_PRICE_IN_INFORMATION`](nodemon/ReadMe.md#market_price_in_information));
- display reward amount, balance and its changes also in the configured currency
  ([`NRG_AMOUNT_IN_CURRENCY`](nodemon/ReadMe.md#nrg_amount_in_currency)).

## Update

To get changes from the repository and update Energi Core Node images and
containers the command `./helper update` should be executed. Or
`./helper update core` or `./helper update monitor` to update image and
container only for the specified service.

It is possible to build images and create containers for Energi Core Node
versions other than the one specified in `.env`: `./helper update vX.Y.Z` or
`./helper update core|monitor vX.Y.Z`. This may be especially useful for cases
when a new version has been released but it has not been reflected in `.env` yet
to update Energi Core Node (and Monitor) to the lateset version.
Note that there is a chance that this command will fail (most probably because
of an error while building Monitor image when the newest Energi version cannot
be compiled using the Go version specified in `nodemon/Dockerfile`), and in such
case the following commands should be executed:

1. `./helper start core` to start Core container as the image for the newest
   Energi Core Node version should be already built;
2. `./helper update monitor` if Energi Core Node Monitor is used; this will use
   the version that is specified in `.env`

or `./helper update` to use Core and Monitor version specified in `.env` till
isues are resolved in the repopsitory.

## Helper script

A little helper script [`helper`](helper) is available. To see what it provides,
`./helper help` should be executed.

## Credits

A list of tools and sources used in this repository:

- [Docker Engine](https://docs.docker.com/engine/);
- [Docker Compose](https://docs.docker.com/compose/);
- [Energi Docker image](https://hub.docker.com/r/energicryptocurrency/energi)
  (source:
  [Energi Core GitHub repository](https://github.com/energicryptocurrency/energi)
  ([`containers/docker/master-alpine/Dockerfile`](https://github.com/energicryptocurrency/energi/blob/master/containers/docker/master-alpine/Dockerfile)));
- [Energi Core Node Monitor script `nodemon.sh`](https://github.com/energicryptocurrency/energi3-provisioning/blob/master/scripts/linux/nodemon.sh).
