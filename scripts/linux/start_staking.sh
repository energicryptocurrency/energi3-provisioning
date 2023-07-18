#!/bin/bash
#####################################################################
# Description: This script is to start energi gen 3 node
#              staking server
#
# Download this script
# wget https://raw.githubusercontent.com/energicryptocurrency/energi3-provisioning/master/scripts/linux/start_staking.sh
#####################################################################
#

export PATH=$HOME/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/snap/bin:$HOME/energi3/bin

# Create directory for logfile
if [ ! -d $HOME/.energicore3/log ]
then
        mkdir -p $HOME/.energicore3/log
fi

# Make executable
if [ ! -x $HOME/energi3/bin/energi3 ]
then
    chmod +x $$HOME/energi3/bin/energi3
fi

# Set variables
LOGFILE=$HOME/.energicore3/log/energicore3.log
JSHOME="$HOME/energi3/js"
IP=`curl -s https://ifconfig.me/`

if [ -f ${HOME}/.energicore3/keystore/UTC* ]
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
