#!/bin/bash

#######################################################################
# Copyright (c) 2020
# All rights reserved.
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND.
#
# Desc:    Script to purge reward block data when in side chain
#
# Version:
#   1.0.0  20200523  ZAlam Initial Script
#
: '
# Run the script to get started:
```
bash -ic "$(wget -4qO- -o- raw.githubusercontent.com/energicryptocurrency/energi3-provisioning/master/scripts/linux/nodemon-resync.sh; source ~/.bashrc
```
'
#######################################################################

# Set script version
BLKSYNCVER=1.0.0

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

# Report function
SQL_REPORT () {
sqlite3 -noheader -csv /var/multi-masternode-data/nodebot/nodemon.db "${1}"
}

for ADDR in ${LISTACCOUNTS}
do
    # change to lower case
    ADDR=$( echo $ADDR | tr '[:upper:]' '[:lower:]' )

    # Get block data from databse
    SQL_REPORT "SELECT blockNum FROM mn_rewards WHERE mnAddress == '${ADDR}';" > dbmnblks.tmp
    SQL_REPORT "SELECT blockNum FROM stake_rewards WHERE stakeAddress == '${ADDR}';" > dbstblks.tmp

    # get block mined data
    echo "Downloading blocks mined by ${ADDR}..."
    curl -H "accept: application/json" -s  "https://explorer.energi.network/api?module=account&action=getminedblocks&address=${ADDR}" -H "accept: application/json" > dump_minedstblks.tmp

    cat dump_minedstblks.tmp | jq -r '.result[] .blockNumber' | sort -u > minedstblks.tmp

    # get block number for mn rewards
    echo "Downloading internal transactions..."
    curl -H "accept: application/json" -s "https://explorer.energi.network/api?module=account&action=txlistinternal&address=${ADDR}" -H "accept: application/json" > dump_minedmnblks.tmp

    cat dump_minedmnblks.tmp | jq -r '.result[] .blockNumber' | sort -u > minedmnblks.tmp

    # Staking
    awk '
    /^$/{next}
    FNR == NR {db_blks[$1] = 1}
    FNR != NR {
        if(!db_blks[$1])
            print $1 > "staking-mainnetblks.txt"
        delete db_blks[$1];
    }
    END {
        for(i in db_blks)
            print i > "staking-sidechainblks.txt"
    }' dbstblks.tmp minedstblks.tmp

    # remove sidechain staking blocks
    if [[ -s "staking-sidechainblks.txt" ]]
    then
        for B in `cat staking-sidechainblks.txt`
        do
            echo "Removing side chain staking block: ${B}"
            sudo sqlite3 -batch /var/multi-masternode-data/nodebot/nodemon.db "delete from stake_rewards where blockNum == '${B}';"
        done
    else
        echo "No sidechain staking blocks..."
    fi

    # Masternode
    awk '
    /^$/{next}
    FNR == NR {db_blks[$1] = 1}
    FNR != NR {
        if(!db_blks[$1])
            print $1 > "mn-mainnetblks.txt"
        delete db_blks[$1];
    }
    END {
        for(i in db_blks)
            print i > "mn-sidechainblks.txt"
    }' dbmnblks.tmp minedmnblks.tmp

    # remove sidechain mn blocks
    if [[ -s "mn-sidechainblks.txt" ]]
    then
        for B in `cat mn-sidechainblks.txt`
        do
            echo "Removing side chain mn block: ${B}"
            sudo sqlite3 -batch /var/multi-masternode-data/nodebot/nodemon.db "delete from mn_rewards where blockNum == '${B}';"
        done
    else
        echo "No sidechain masternode blocks..."
    fi

    # clean-up
    rm dbstblks.tmp minedstblks.tmp dump_minedstblks.tmp staking-sidechainblks.txt staking-mainnetblks.txt 2>/dev/null
    rm dbmnblks.tmp minedmnblks.tmp dump_minedmnblks.tmp mn-sidechainblks.txt mn-mainnetblks.txt 2>/dev/null

done


