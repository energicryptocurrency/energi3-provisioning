#!/bin/bash

#######################################################################
# Copyright (c) 2022
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
#   1.1.0  20210114  ZAlam Updated to support all version
#   1.1.1  20220121  ZAlam Bug fix with current month
#
# Set script version
NODERPTVER=1.1.0

#set -x

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

# Report file
RPTTMPFILE="/home/${USRNAME}/etc/reward_data.tmp"
RPTFILE="/home/${USRNAME}/etc/reward_data.csv"

# Report function
SQL_REPORT () {
sqlite3 -noheader -csv /var/multi-masternode-data/nodebot/nodemon.db "${1}"
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
      ___       _  _         _     __  __
     /\  \     | \| |___  __| |___|  \/  |___ _ _
    /::\  \    | .` / _ \/ _` / -_) |\/| / _ \ ' \
   /:/\:\__\   |_|\_\___/\__,_\___|_|  |_\___/_||_|
  /:/ /:/ _/_    | _ \___ _ __  ___ _ _| |_
 /:/ /:/ /\__\   |   / -_) '_ \/ _ \ '_|  _|
 \:\ \/ /:/  /   |_|_\___| .__/\___/_|  \__|
  \:\  /:/  /            |_|
ENERGI3
echo "${GREEN}   \:\/:/  /   ${NC}Options:"
echo "${GREEN}    \::/  /    ${NC}a - Extract all data"
echo "${GREEN}     \/__/     ${NC}b - Generate last month data"
echo "               ${NC}c - Generate current month data"
echo "               ${NC}d - Custom dates"
echo ${NC}
}

_instructions

REPLY='a'
read -p "Please select an option([a], b, c or d): " -r
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
    
    # Export all data
    SQL_REPORT "SELECT DATETIME(rewardTime,'unixepoch'),blockNum,'M',mnAddress,balance,Reward,nrgPrice FROM mn_rewards;" > ${RPTTMPFILE}

    SQL_REPORT "SELECT DATETIME(rewardTime,'unixepoch'),blockNum,'S',stakeAddress,balance,Reward,nrgPrice FROM stake_rewards;" >> ${RPTTMPFILE}

    ;;

  b)
  
    # Export previous month
    CURRMON=$( date +%Y-%m )
    PREVMON=$( date -d "$CURRMON-15 last month" '+%Y-%m' )
    PREVMON2=$( date -d "$CURRMON-15 last month" '+%m %Y' )
    LASTDAY=$( cal ${PREVMON2} | awk 'NF {DAYS = $NF}; END {print DAYS}' )
    
    SQL_REPORT "SELECT DATETIME(rewardTime,'unixepoch'),blockNum,'M',mnAddress,balance,Reward,nrgPrice FROM mn_rewards WHERE rewardTime >= strftime('%s','${PREVMON}-01 00:00:00') and rewardTime <= strftime('%s','${PREVMON}-${LASTDAY} 23:59:59');" > ${RPTTMPFILE}
    
    SQL_REPORT "SELECT DATETIME(rewardTime,'unixepoch'),blockNum,'S',stakeAddress,balance,Reward,nrgPrice FROM stake_rewards WHERE rewardTime >= strftime('%s','${PREVMON}-01 00:00:00') and rewardTime <= strftime('%s','${PREVMON}-${LASTDAY} 23:59:59');" >> ${RPTTMPFILE}

    ;;

  c)
  
    # Export current month
    CURRMON=$( date +%Y-%m )
    CURRMON2=$( date '+%m %Y' )
    LASTDAY=$( cal ${CURRMON2} | awk 'NF {DAYS = $NF}; END {print DAYS}' )
    
    SQL_REPORT "SELECT DATETIME(rewardTime,'unixepoch'),blockNum,'M',mnAddress,balance,Reward,nrgPrice FROM mn_rewards WHERE rewardTime >= strftime('%s','${CURRMON}-01 00:00:00') and rewardTime <= strftime('%s','${CURRMON}-${LASTDAY} 23:59:59');" > ${RPTTMPFILE}
    
    SQL_REPORT "SELECT DATETIME(rewardTime,'unixepoch'),blockNum,'S',stakeAddress,balance,Reward,nrgPrice FROM stake_rewards WHERE rewardTime >= strftime('%s','${CURRMON}-01 00:00:00') and rewardTime <= strftime('%s','${CURRMON}-${LASTDAY} 23:59:59');" >> ${RPTTMPFILE}

    ;;

  d)
    
    # Custom date range
    echo "Enter date range of report..."
    read -p "Start date [YYYY-MM-DD]: " STARTDATE
    read -p "End date [YYYY-MM-DD]  : " ENDDATE
    
    SQL_REPORT "SELECT DATETIME(rewardTime,'unixepoch'),blockNum,'M',mnAddress,balance,Reward,nrgPrice FROM mn_rewards WHERE rewardTime >= strftime('%s','${STARTDATE} 00:00:00') and rewardTime <= strftime('%s','${ENDDATE} 23:59:59');" > ${RPTTMPFILE}
    
    SQL_REPORT "SELECT DATETIME(rewardTime,'unixepoch'),blockNum,'S',stakeAddress,balance,Reward,nrgPrice FROM stake_rewards WHERE rewardTime >= strftime('%s','${STARTDATE} 00:00:00') and rewardTime <= strftime('%s','${ENDDATE} 23:59:59');" >> ${RPTTMPFILE}
    
    ;;

  *)
  
    echo
    echo "Enter Options:"
    echo " a - Extract all data"
    echo " b - Generate last month data"
    echo " c - Generate current month data"
    echo " d - Custom dates"
    echo
    exit 0
    ;;

esac

# Sort data
sort ${RPTTMPFILE} > ${RPTFILE}

# Remove temp file
rm ${RPTTMPFILE}

# Add title
sed -i '1irewardTime,blockNum,type,mnAddress,balance,reward,nrgPrice' ${RPTFILE}

# Print location of file
echo
echo "The report has been saved to:"
echo "   ${RPTFILE}"
echo
