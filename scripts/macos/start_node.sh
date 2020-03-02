#!/usr/bin/env bash
#####################################################################
# Description: This script is to start energi core node masternode server      
#
# Download this script
# curl -sL https://raw.githubusercontent.com/energicryptocurrency/energi3-provisioning/master/scripts/macos/start_node.sh
#####################################################################
#

export PATH="$PATH:$HOME/energi3/bin"
ARG=''
LOGFILE=''
NETWORK=mainnet
RPCPORT=39796
WSPORT=39795

# Make executable
if [ ! -x "$HOME/energi3/bin/energi3" ]
then
    chmod +x "$HOME/energi3/bin/energi3"
fi

while [[ $# -gt 0 ]]
do
  key="$1"; shift
  
  case $key in
    -t|-testnet|--testnet)
      NETWORK=testnet
      ARG="${ARG} -testnet"
      RPCPORT=49796
      WSPORT=49795
      ;;
    -m|-masternode|--masternode)
      ARG="$ARG --masternode"
      ;;
    -d|-debug)
      set -x
      ;;
    -h|-help)
      cat << EOL

start_node.sh arguments:
  -t -testnet                  : Run in testnet
  -m -masternode               : Run masternode mode
  -h --help                    : Display this help text
  -d --debug                   : Debug mode

EOL
      exit
      ;;
  esac
done
  
  
# Set variables
if [ "${NETWORK}" = "mainnet" ]
then
  LOGFILE="${HOME}/Library/EnergiCore3/log/energicore3.log"
  # Create directory for logfile
  if [ ! -d "${HOME}/Library/EnergiCore3/log" ]
  then
          mkdir -p "${HOME}/Library/EnergiCore3/log"
  fi
else
  LOGFILE="${HOME}/Library/EnergiCore3/testnet/log/energicore3.log"
  # Create directory for logfile
  if [ ! -d "${HOME}/Library/EnergiCore3/testnet/log" ]
  then
          mkdir -p "${HOME}/Library/EnergiCore3/testnet/log"
  fi

fi

JSHOME="${HOME}/energi3/js"
IP=`curl -s https://ifconfig.me/`

# Start Eenrgi Core Node
if [ "x$IP" != "x" ]
then
    energi3 \
        ${ARG} \
        --nat extip:${IP} \
        --preload $JSHOME/utils.js \
        --mine \
        --rpc \
        --rpcport ${RPCPORT} \
        --rpcaddr "127.0.0.1" \
        --rpcapi admin,eth,web3,rpc,personal,energi \
        --ws \
        --wsaddr "127.0.0.1" \
        --wsport ${WSPORT} \
        --wsapi admin,eth,net,web3,personal,energi \
        --verbosity 3 \
        console 2>> $LOGFILE

else
    echo "Lookup external IP address by going to https://ifconfig.me/"
    energi3 \
        ${ARG} \
        --mine \
        --rpc \
        --rpcport ${RPCPORT} \
        --rpcaddr "127.0.0.1" \
        --rpcapi admin,eth,web3,rpc,personal,energi \
        --ws \
        --wsaddr "127.0.0.1" \
        --wsport ${WSPORT} \
        --wsapi admin,eth,net,web3,personal,energi \
        --verbosity 3 \
        console 2>> $LOGFILE
        
fi
