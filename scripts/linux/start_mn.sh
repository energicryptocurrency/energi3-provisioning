#!/bin/bash
#####################################################################
# Description: This script is to start energi core node masternode server      
#
# Download this script
# wget https://raw.githubusercontent.com/energicryptocurrency/energi3-provisioning/master/scripts/linux/start_mn.sh
#####################################################################
#

export PATH=$HOME/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/snap/bin:$HOME/energi3/bin


if [ ! -d $HOME/.energicore3/log ]
then
        mkdir -p $HOME/.energicore3/log
fi

# Set variables
LOGFILE=$HOME/.energicore3/log/energicore3.log
JSHOME=$HOME/energi3/js
#IP=`dig +short myip.opendns.com @resolver1.opendns.com`
IP=`curl -s https://ifconfig.me/`

if [ "x$IP" != "x" ]
then
    energi3 \
        --masternode \
        --nat extip:${IP} \
        --preload $JSHOME/utils.js \
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
        console 2>> $LOGFILE
else
    echo "Lookup external IP address by going to https://ifconfig.me/"
    energi3 \
        --masternode \
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
        console 2>> $LOGFILE
fi
