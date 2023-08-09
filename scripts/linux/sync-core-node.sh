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
    SUDO='sudo'
  else
    echo "User ${RUNAS} does not have ${SUDO} permissions."
    echo "Run ${BLUE}${SUDO} ls -l${NC} to set permissions if you know the user ${RUNAS} has ${SUDO} previlidges"
    echo "and then rerun the script"
    echo "Exiting script..."
    sleep 3
    exit 0
  fi
fi

# Stop nodemon if running.
NODEMONSTATUS=$(systemctl status nodemon.timer | grep "Active:" | awk '{print $2}')
if [[ "${NODEMONSTATUS}" = "active" ]]
then
  echo "Stopping nodemon service for Energi"
  ${SUDO} systemctl stop nodemon.timer
  sleep 5
fi

# Stop energi core if running.
SYSTEMCTLSTATUS=$(systemctl status energi3.service | grep "Active:" | awk '{print $2}')
if [[ "${SYSTEMCTLSTATUS}" = "active" ]]
then
  echo "Stopping Energi3 Core Node..."
  ${SUDO} systemctl stop energi3.service
  ${SUDO} systemctl disable energi3.service
  sleep 5
else
  echo "energi3 service is not running..."
fi

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
if [ ! -f chaindata-files.txt ]
then
  wget -4qo- https://usc1.contabostorage.com/ab655ed609364bd6805208d309a046f8:mainnet/chaindata-files.txt --show-progress --progress=bar:force:noscroll 2>&1
fi
if [ ! -f sha256sums.txt ]
then
  wget -4qo- https://usc1.contabostorage.com/ab655ed609364bd6805208d309a046f8:mainnet/sha256sums.txt --show-progress --progress=bar:force:noscroll 2>&1
fi

# Check list of files to download exists
if [ ! -f chaindata-files.txt ]
then
  echo "chaindata-files.txt was not download."
  echo "existing..."
  exit 10
fi

# Download and extract chaindata files
for FILE in `cat chaindata-files.txt`
do
  echo "Downloading ${FILE}..."
  sleep 5
  wget -c https://usc1.contabostorage.com/ab655ed609364bd6805208d309a046f8:mainnet/$FILE --show-progress --progress=bar:force:noscroll 2>&1
  
  # Verify sha256sum
  echo "Checking validity of ${FILE}. The validation may take some time."
  grep $FILE sha256sums.txt > SHA256SUMS
  CHECKFILE=$(sha256sum -c SHA256SUMS | grep OK)
  if [ ! -z "${CHECKFILE}" ]
  then
    echo -e "sha256sum matches ${GREEN}☑${NC}. Extracting file ${FILE}. It will some time to extract."
    tar xfz $FILE
    rm $FILE
    echo "Removing $FILE from list of files to download"
    sed -i '/'"${FILE}"'/d' chaindata-files.txt
  else
    echo "Error with file $FILE."
    echo "${BLUE}Run the sync script again.${NC} It will start from where it left off."
    echo
    echo "${RED}DO NOT remove the chaindata${NC} already downloaded when prompted this time."
    echo
    exit 20
  fi
done

# create log dir if it does not exist
if [ ! -d /home/nrgstaker/.energicore3/energi3/log ]
then
  mkdir -p /home/nrgstaker/.energicore3/energi3/log
  touch /home/nrgstaker/.energicore3/energi3/log/energi_stdout.log
fi

# Set ownership to .energicore3 directory
echo "Changing ownership of files to nrgstaker"
${SUDO} chown -R nrgstaker:nrgstaker .energicore3

# Start Energi Core Node
echo "Starting Energi Core Node"
${SUDO} systemctl enable energi3.service
${SUDO} systemctl start energi3.service
sleep 5

# If nodemon is installed, start it
if [ -f /etc/systemd/system/nodemon.timer ]
then
  echo "Starting nodemon service for Energi"
  ${SUDO} systemctl daemon-reload
  ${SUDO} systemctl start nodemon.timer
else
  echo "nodemon is not installed."
fi

# remove temporary files
echo "Removing temporary files"
${SUDO} rm chaindata-files.txt sha256sums.txt SHA256SUMS
