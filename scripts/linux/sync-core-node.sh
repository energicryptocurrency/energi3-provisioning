#!/bin/bash

######################################################################
# Copyright (c) 2023
# All rights reserved.
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND.
#
# Desc:   Script to download chaindata to enable faster sync
# 
# Version:
#   1.0.0  20230718  ZA Initial Script
#

 : '
# Run this file

```
  bash -ic "$(wget -4qO- -o- raw.githubusercontent.com/energicryptocurrency/energi3-provisioning/master/scripts/linux/sync-core-node.sh)" ; source ~/.bashrc
```
'

# Set colors
BLUE=`tput setaf 4`
RED=`tput setaf 1`
GREEN=`tput setaf 2`
YELLOW=`tput setaf 2`
NC=`tput sgr0`

# Who is running the script
# If root no ${SUDO} required
# If user has ${SUDO} privilidges, run ${SUDO} when necessary

RUNAS=`whoami`

if [[ $EUID = 0 ]]
then
  SUDO=""
else
  ISSUDOER=`getent group ${SUDO} | grep ${RUNAS}`
  if [ ! -z "${ISSUDOER}" ]
  then
    SUDO='${SUDO}'
  else
    echo "User ${RUNAS} does not have ${SUDO} permissions."
    echo "Run ${BLUE}${SUDO} ls -l${NC} to set permissions if you know the user ${RUNAS} has ${SUDO} previlidges"
    echo "and then rerun the script"
    echo "Exiting script..."
    sleep 3
    exit 0
  fi
fi

#
echo "Stopping Energi Core Node"
${SUDO} systemctl stop energi3
sleep 5

# Remove old chaindata
if [ -d /home/nrgstaker/.energicore3/energi3/chaindata ]
then
  read -r -p $'Do you want to remove existing chaindata \e[7m(y/n)\e[0m? ' -e 2>&1
  REPLY=${REPLY,,} # tolower
  if [[ "${REPLY}" == 'y' ]]
  then
    /home/nrgstaker/energi3/bin/energi3 --datadir=/home/nrgstaker/energi3/.energicore3 removedb
  fi
fi

# Get list of files to download and their checksum
cd /home/nrgstaker
wget -4qo- https://eu2.contabostorage.com/679d4da708bc41d3b9f670d4eae73eb1:mainnet/chaindata-files.txt --show-progress --progress=bar:force:noscroll 2>&1
wget -4qo- https://eu2.contabostorage.com/679d4da708bc41d3b9f670d4eae73eb1:mainnet/sha256sums.txt --show-progress --progress=bar:force:noscroll 2>&1

if [ ! -f chaindata-files.txt ]
then
  echo "chaindata-files.txt was not download."
  echo "existing..."
  exit 10
fi

# Download and extract chaindata files
for FILE in `cat chaindata-files.txt`
do 
  wget -4qo- https://eu2.contabostorage.com/679d4da708bc41d3b9f670d4eae73eb1:mainnet/$FILE --show-progress --progress=bar:force:noscroll 2>&1
  tar xvfz $FILE
  rm $FILE
done

# create log dir if it does not exist
if [ ! -d /home/nrgstaker/.energicore3/energi3/log ]
then
  mkdir -p /home/nrgstaker/.energicore3/energi3/log
  touch /home/nrgstaker/.energicore3/energi3/log/energi_stdout.log
fi

# Set ownership to .energicore3 directory
${SUDO} chown -R nrgstaker:nrgstaker .energicore3

# Start Energi Core Node
echo "Starting Energi Core Node"
${SUDO} systemctl start energi3
sleep 5

# remove temporary files
${SUDO} rm chaindata-files.txt sha256sums.txt