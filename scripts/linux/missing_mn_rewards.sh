#!/bin/bash

######################################################################
# Copyright (c) 2021
# All rights reserved.
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND.
#
# Desc: Load missing masternode rewards to the database
#
# Version:
#   1.0.0  20210515  ZA Initial Script
#
: '
# Run the script to get started:
```
bash -ic "$(wget -4qO- -o- raw.githubusercontent.com/energicryptocurrency/energi3-provisioning/master/scripts/linux/missing_mn_rewards.sh START_BLOCK END_BLOCK MN_ADDR)" ; source ~/.bashrc
Syntax: missing_mn_rewards.sh START_BLOCK END_BLOCK MN_ADDR
Script arguments:
    START_BLOCK  : Block number to start from
    END_BLOCK    : Block number to stop at
    MN_ADDR      : Masternode address
```
'
######################################################################

#set -x

STARTBLK=$1
ENDBLK=$2
ADDR=$3

if [[ -z $STARTBLK || -z $ENDBLK || -z $ADDR ]]
then
    echo "Syntax:"
    echo "    missing_mn_rewards.sh START_BLOCK END_BLOCK MN_ADDR" 
    echo "    Script arguments:"
    echo "      START_BLOCK  : Block number to start from"
    echo "      END_BLOCK    : Block number to stop at"
    echo "      MN_ADDR      : Masternode address"
    exit 10
fi

MNTOTALNRG=0
USRNAME=$( find /home -name nodekey  2>&1 | grep -v "Permission denied" | awk -F\/ '{print $3}' )
export PATH=$PATH:/home/${USRNAME}/energi3/bin

if [[ ! -z $3 ]]
then
    export ADDR=$3
fi

# Set API server
#export NRGAPI="https://explorer.energi.network/api"
export NRGAPI="http://mainnet.energi.cloudns.cl:4000/api"

echo "Downloading internal transactions..."
curl -H "accept: application/json" -s "${NRGAPI}?module=account&action=txlistinternal&address=${ADDR}&startblock=${STARTBLK}&endblock=${ENDBLK}" -H "accept: application/json" > list_int_tran.txt

cat list_int_tran.txt | jq -r '.result[] .blockNumber' | sort -u -n > list_int_tran_blks.txt

for CHKBLOCK in `cat list_int_tran_blks.txt`
do
    # CHKBLOCK=$1

    if [[ -z $CHKBLOCK ]]
    then
	echo "enter a block number"
	exit
    fi

    if [[ -z $ADDR || -z $NRGAPI ]]
    then
        echo "No ADDR or NRGAPI set"
        exit 10
    fi

    COMMAND="energi3 attach --exec "
    if [[ ! -z $MNCOLLATERAL ]]
    then
        MNCOLLATERAL=$( $COMMAND "web3.fromWei(masternode.masternodeInfo('$ADDR').collateral, 'energi')" 2>/dev/null | jq -r '.' )
    fi

    #if [[ ${MNCOLLATERAL} -gt 0 ]]
    #then

    # Check if CURRENCY is set
    if [ ! -z $CURRENCY} ]
    then
        CURRENCY=USD
    fi

    #
    SQL_QUERY () {
      if [[ ! -d /var/multi-masternode-data/nodebot ]]
      then
        sudo mkdir -p /var/multi-masternode-data/nodebot
      fi
      sudo sqlite3 -batch /var/multi-masternode-data/nodebot/nodemon.db "${1}"
    }

    # to lower case
    ADDR=$( echo ${ADDR} | tr '[:upper:]' '[:lower:]' )

    CHKDB=$( SQL_QUERY "select * from mn_rewards where blockNum = '${CHKBLOCK}';" )

    if [ -z ${CHKDB} ]
    then
        echo "Processing block ${CHKBLOCK}"

        TXLSTINT=$( curl -H "accept: application/json" -s "${NRGAPI}?module=account&action=txlistinternal&address=${ADDR}&startblock=${CHKBLOCK}&endblock=${CHKBLOCK}" )

        BLOCKSUMWEI=$( echo $TXLSTINT | jq -r '.result | map(.value | tonumber) | add ' )
        BLOCKSUMWEI=$( printf "%.0f" $BLOCKSUMWEI )
        BLOCKSUMNRG=$( echo " ${BLOCKSUMWEI} / 1000000000000000000 " | bc -l | sed '/\./ s/\.\{0,1\}0\{1,\}$//' )

        REWARDTIME=$( ${COMMAND} "nrg.getBlock($CHKBLOCK).timestamp" 2>/dev/null )
        # Get price once
        if [[ -z "${NRGMKTPRICE}" ]]
        then
            NRGMKTPRICE=$( curl -H "Accept: application/json" --connect-timeout 30 -s "https://min-api.cryptocompare.com/data/price?fsym=NRG&tsyms=${CURRENCY}" | jq .${CURRENCY} )
        fi

        if [[ ! -z $BLOCKSUMNRG ]]
        then
        SQL_QUERY "INSERT INTO mn_rewards (mnAddress, rewardTime, blockNum, Reward, balance, nrgPrice)
          VALUES ('${ADDR}','${REWARDTIME}','${CHKBLOCK}','${BLOCKSUMNRG}', '${MNCOLLATERAL}', '${NRGMKTPRICE}');"
        fi 

    else
        echo "Already in DB: ${CHKBLOCK}"
    fi
done

# Clean-up
rm list_int_tran.txt
rm list_int_tran_blks.txt
