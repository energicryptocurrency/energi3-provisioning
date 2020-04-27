#!/bin/bash

#######################################################################
# Copyright (c) 2020
# All rights reserved.
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND.
#
# Desc:   NRG Monitor Toolset: Set of tools to monitor and manage NRG
#         Core Node, the reward received and notify the user via email
#         SMS and Social Media channels. Currently, Discord and Telegram
#         are the social media channels supported.
#
#         This script is meant to generate a CSV report
#
# Version:
#   1.0.0  20200421  ZAlam Initial Script
#
# Set script version
NRGRPTVER=1.0.0

#set -x

#
USRNAME=$( find /home -name nodekey  2>&1 | grep -v "Permission denied" | awk -F\/ '{print $3}' )

#
export PATH=$PATH:/home/${USRNAME}/energi3/bin

# Report file
RPTTMPFILE="/home/${USRNAME}/etc/reward_data.tmp"
RPTFILE="/home/${USRNAME}/etc/reward_data.csv"

# Report function
SQL_REPORT () {
sqlite3 -noheader -csv /var/multi-masternode-data/nrgbot/nrgmon.db "${1}"
}

# Set colors
BLUE=`tput setaf 4`
RED=`tput setaf 1`
GREEN=`tput setaf 2`
YELLOW=`tput setaf 2`
NC=`tput sgr0`

_instructions () {
  echo "${GREEN}"
  clear 2> /dev/null
  cat << "ENERGI3"
      ___      
     /\  \     .  . ,-.   ,-. .   ,  ,-.  .  .   ,-.  ,--. ;-.   ,-.  ,-.  ,---.
    /::\  \    |\ | |  ) /    |\ /| /   \ |\ |   |  ) |    |  ) /   \ |  )   |`
   /:/\:\__\   | \| |-<  | -. | V | |   | | \|   |-<  |-   |-'  |   | |-<    |
  /:/ /:/ _/_  |  | |  \ \  | |   | \   / |  |   |  \ |    |    \   / |  \   |
 /:/ /:/ /\__\ '  ' '  '  `-' '   '  `-'  '  '   '  ' `--' '     `-'  '  '   '
 \:\ \/ /:/  /
ENERGI3
echo "${GREEN}  \:\  /:/  /  ${NC}Options:"
echo "${GREEN}   \:\/:/  /   ${NC}a - Extract all data"
echo "${GREEN}    \::/  /    ${NC}b - Generate current month data (not working)"
echo "${GREEN}     \/__/     ${NC}c - Custom dates (not working)"
echo ${NC}
}

_instructions

REPLY='a'
read -p "Please select an option(a, b or c): " -r
REPLY=${REPLY,,} # tolower
if [ "${REPLY}" = "" ]
then
  REPLY='a'
fi

if [[ ! -d ${HOME}/etc ]]
then
  mkdir ${HOME}/etc
fi

# Generate CSV
case ${REPLY} in

  a)
    SQL_REPORT "SELECT DATETIME(rewardTime,'unixepoch'),blockNum,'M',mnAddress,balance,Reward,nrgPrice FROM mn_rewards;" > ${RPTTMPFILE}

    SQL_REPORT "SELECT DATETIME(rewardTime,'unixepoch'),blockNum,'S',stakeAddress,balance,Reward,nrgPrice FROM stake_rewards;" >> ${RPTTMPFILE}

    ;;

  b)
    #SQL_REPORT "SELECT DATETIME(rewardTime,'unixepoch'),blockNum,mnAddress,balance,Reward,nrgPrice FROM mn_rewards WHERE strftime('%m', rewardTime, unixepoch) = '04';"
    #SQL_REPORT "SELECT DATETIME(rewardTime,'unixepoch'),blockNum,stakeAddress,balance,Reward,nrgPrice FROM stake_rewards strftime('%m', rewardTime, unixepoch) = '04';"
    echo ${REPLY}
    ;;

  c)
    echo ${REPLY}
    ;;

  *)
    echo "help"
    ;;

esac

# Sort data
sort ${RPTTMPFILE} > ${RPTFILE}

# Remove temp file
rm ${RPTTMPFILE}

# Add title
sed -i '1irewardTime,blockNum,type,mnAddress,balance,reward,nrgPrice' ${RPTFILE}

#cat ${RPTFILE}
