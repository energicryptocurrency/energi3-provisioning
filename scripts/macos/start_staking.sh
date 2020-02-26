#!/usr/bin/env bash
#####################################################################
# Description: This script is to start energi gen 3 node staking server    
#
# Download this script
# wget https://raw.githubusercontent.com/energicryptocurrency/energi3-provisioning/master/scripts/linux/start_staking.sh
#####################################################################
#

export PATH=$PATH:$HOME/energi3/bin

# Create directory for logfile
if [ ! -d "${HOME}/Library/EnergiCore3/testnet/log" ]
then
        mkdir -p "${HOME}/Library/EnergiCore3/testnet/log"
fi

# Install dig which is part of bind
#brew install bind

# Make executable
if [ ! -x $HOME/energi3/bin/energi3 ]
then
    chmod +x $HOME/energi3/bin/energi3
fi

# Set variables
LOGFILE="${HOME}/Library/EnergiCore3/testnet/log/energicore3.log"
JSHOME="$HOME/energi3/js"
IP=`curl -s https://ifconfig.me/`

# Start staking server
if [ -f ${HOME}/Library/EnergiCore3/testnet/keystore/UTC* ]
then
    energi3 \
        --preload ${JSHOME}/utils.js \
        --mine \
        --rpc \
        --rpcport 39796 \
        --rpcaddr "127.0.0.1" \
        --rpcapi admin,eth,web3,rpc,personal,energi \
        --ws \
        --wsaddr "127.0.0.1" \
        --wsport 39795 \
        --wsapi admin,eth,net,web3,personal,energi \
        --verbosity 3 \
        console 2>> ${LOGFILE}
else
    energi3 \
        --preload ${JSHOME}/utils.js \
        --rpc \
        --rpcport 39796 \
        --rpcaddr "127.0.0.1" \
        --rpcapi admin,eth,web3,rpc,personal,energi \
        --ws \
        --wsaddr "127.0.0.1" \
        --wsport 39795 \
        --wsapi admin,eth,net,web3,personal,energi \
        --verbosity 3 \
        console 2>> ${LOGFILE}
fi

