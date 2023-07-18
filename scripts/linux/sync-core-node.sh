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
# If root no sudo required
# If user has sudo privilidges, run sudo when necessary

RUNAS=`whoami`

if [[ $EUID = 0 ]]
then
    SUDO=""
else
    ISSUDOER=`getent group sudo | grep ${RUNAS}`
    if [ ! -z "${ISSUDOER}" ]
    then
        SUDO='sudo'
    else
        echo "User ${RUNAS} does not have sudo permissions."
        echo "Run ${BLUE}sudo ls -l${NC} to set permissions if you know the user ${RUNAS} has sudo previlidges"
        echo "and then rerun the script"
        echo "Exiting script..."
        sleep 3
        exit 0
    fi
fi

${SUDO} systemctl start energi3

cd /home/nrgstaker
wget -4qo- https://eu2.contabostorage.com/679d4da708bc41d3b9f670d4eae73eb1:mainnet/chaindata-files.txt --show-progress --progress=bar:force:noscroll 2>&1
wget -4qo- https://eu2.contabostorage.com/679d4da708bc41d3b9f670d4eae73eb1:mainnet/sha256sums.txt --show-progress --progress=bar:force:noscroll 2>&1

for FILE in `cat chaindata-files.txt`
do 
    wget -4qo- https://eu2.contabostorage.com/679d4da708bc41d3b9f670d4eae73eb1:mainnet/$FILE --show-progress --progress=bar:force:noscroll 2>&1
    tar xvfz $FILE
    rm $FILE
done

if [ ! -d /home/nrgstaker/.energicore3/energi3/log ]
then
    mkdir -p /home/nrgstaker/.energicore3/energi3/log
    touch /home/nrgstaker/.energicore3/energi3/log/energi_stdout.log
fi

chown -R nrgstaker:nrgstaker .energicore3

${SUDO} systemctl start energi3

echo "attach to energi3 and check the node is syncing"
