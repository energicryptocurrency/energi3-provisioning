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

# Generate CSV
SQL_REPORT "SELECT DATETIME(rewardTime,'unixepoch'),blockNum,'M',mnAddress,balance,Reward,nrgPrice FROM mn_rewards;" > ${RPTTMPFILE}
#SQL_REPORT "SELECT DATETIME(rewardTime,'unixepoch'),blockNum,mnAddress,balance,Reward,nrgPrice FROM mn_rewards WHERE strftime('%m', rewardTime) = '04';"

SQL_REPORT "SELECT DATETIME(rewardTime,'unixepoch'),blockNum,'S',stakeAddress,balance,Reward,nrgPrice FROM stake_rewards;" >> ${RPTTMPFILE}
#SQL_REPORT "SELECT DATETIME(rewardTime,'unixepoch'),blockNum,stakeAddress,balance,Reward,nrgPrice FROM stake_rewards strftime('%m', `rewardTime`) = '04';"

# Sort data
sort ${RPTTMPFILE} > ${RPTFILE}

# Remove temp file
rm ${RPTTMPFILE}

# Add title
sed -i '1irewardTime,blockNum,type,mnAddress,balance,reward,nrgPrice' ${RPTFILE}

#cat ${RPTFILE}
