#!/bin/bash

#######################################################################
# Copyright (c) 2020
# All rights reserved.
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND.
#
# Desc:    Script to load missing stake reward data
#
# Version:
#   1.0.0  20201014  ZAlam Initial Script
#
: '
# Run the script to get started:
```
bash -ic "$(wget -4qO- -o- raw.githubusercontent.com/energicryptocurrency/energi3-provisioning/master/scripts/linux/missing_stake_rewards.sh; source ~/.bashrc
```
'
#######################################################################

#set -x

# Load parameters from external conf file
if [[ -f /var/multi-masternode-data/nodebot/nodemon.conf ]]
then
    . /var/multi-masternode-data/nodebot/nodemon.conf
fi

# get username; exclude testnet
USRNAME=$( find /home -name nodekey  2>&1 | grep -v "Permission denied" | grep -v testnet | awk -F\/ '{print $3}' )

# check for energi
BINLOC=$( find /home/${USRNAME} -type f -name energi -executable 2>&1 | grep -v "Permission denied" )
COMMAND="energi attach --exec "

# check for energi3 if energi not installed
if [ ! -z ${BINLOC} ]
then
  echo "Using binary name: energi"
else
  BINLOC=$( find /home/${USRNAME} -type f -name energi3 -executable 2>&1 | grep -v "Permission denied" )
  COMMAND="energi3 attach --exec "
  echo "Using binary name: energi3"
fi

# Extract path to binary
EXECPATH=$( dirname ${BINLOC} )

# set PATH
export PATH=$PATH:${EXECPATH}

# Get list of accounts from core node
if [[ -z ${LISTACCOUNTS} ]]
then
    LISTACCOUNTS=$( ${COMMAND} "personal.listAccounts" 2>/dev/null | jq -r '.[]' )
fi

# Check if CURRENCY is set
if [ ! -z $CURRENCY} ]
then
    CURRENCY=USD
fi

# SQL Data Store
SQL_QUERY () {
  if [[ ! -d /var/multi-masternode-data/nodebot ]]
  then
    sudo mkdir -p /var/multi-masternode-data/nodebot
  fi
  sudo sqlite3 -batch /var/multi-masternode-data/nodebot/nodemon.db "${1}"
}

# No way to determine at the time. Assume default
REWARDAMT=2.28

for ADDR in ${LISTACCOUNTS}
do

    # to lower case
    ADDR=$( echo ${ADDR} | tr '[:upper:]' '[:lower:]' )

    echo "Downloading blocks mined by ${ADDR}..."
    curl -H "accept: application/json" -s  "https://explorer.energi.network/api?module=account&action=getminedblocks&address=${ADDR}" -H "accept: application/json" > list_blk_mined.txt

    cat list_blk_mined.txt | jq -r '.result[] .blockNumber' | sort -u -n > blk_mined.txt

    ACCTBALANCE=''
    NRGMKTPRICE=''

    for i in `cat blk_mined.txt`
    do

        CHKBLOCK=$i

        CHKDB=$( SQL_QUERY "select * from stake_rewards where blockNum = '${CHKBLOCK}';" )

        if [ -z ${CHKDB} ]
        then

            REWARDTIME=$( ${COMMAND} "nrg.getBlock($CHKBLOCK).timestamp" 2>/dev/null )
	          BLKMINER=$( ${COMMAND} "nrg.getBlock($CHKBLOCK).miner" 2>/dev/null | jq -r '.[]' )

	    if [ "${ADDR}" = "${BLKMINER}" ]
	    then
                echo "Processing block ${CHKBLOCK}"
                NRGMKTPRICE=$( curl -H "Accept: application/json" --connect-timeout 30 -s "https://min-api.cryptocompare.com/data/price?fsym=NRG&tsyms=${CURRENCY}&ts=${REWARDTIME}" | jq .${CURRENCY} )

	        if [[ ! $NRGMKTPRICE =~ ^[+-]?[0-9]+\.?[0-9]*$ ]]
	        then
                    NRGMKTPRICE=''
          fi

                SQL_QUERY "INSERT INTO stake_rewards (stakeAddress, rewardTime, blockNum, Reward, balance, nrgPrice)
                  VALUES ('${ADDR}','${REWARDTIME}','${CHKBLOCK}','${REWARDAMT}', '${ACCTBALANCE}', '${NRGMKTPRICE}');"
	    else
		echo "Block winner: ${BLKMINER}"
	    fi

        else
            echo "Already in DB: ${CHKBLOCK}"
        fi
    done

    rm blk_mined.txt
    rm list_blk_mined.txt
done
