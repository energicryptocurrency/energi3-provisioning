#!/bin/bash

######################################################################
# Copyright (c) 2020
# All rights reserved.
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND.
#
# Desc:   Batch script to change autocollaterelize parameter on VPS
#
# Version:
#   1.0.0 20200321 ZA Initial Script
#
: '
# Run the script to get started:
```
bash -ic "$(wget -4qO- -o- raw.githubusercontent.com/energicryptocurrency/energi3-provisioning/master/scripts/linux/autocollaterelize.sh)" ; source ~/.bashrc
```
'
######################################################################

# Actual
#SERVICEFILE=/lib/systemd/system/energi3.service
# Testing
SERVICEFILE=/home/nrgstaker/energi3.service

# Set colors
BLUE=`tput setaf 4`
RED=`tput setaf 1`
GREEN=`tput setaf 2`
YELLOW=`tput setaf 2`
NC=`tput sgr0`

#
if [[ -f ${SERVICEFILE} ]]
then
    CHKIFTHERE=`grep autocollateralize ${SERVICEFILE}`
    ISDISABLED=`grep "autocollateralize 0" ${SERVICEFILE}`
    ISENABLED=`grep "autocollateralize 1" ${SERVICEFILE}`

else
    echo "Cannot find service file to update"
    echo "  Filename: ${SERVICEFILE}"
    echo
    echo "Exiting script..."
    echo
    exit 1
fi

#
echo "${GREEN}"
clear 2> /dev/null
cat << "ENERGI3"
      ___       ______ _   _ ______ _____   _____ _____ ____
     /\  \     |  ____| \ | |  ____|  __ \ / ____|_   _|___ \
    /::\  \    | |__  |  \| | |__  | |__) | |  __  | |   __) |
   /:/\:\__\   |  __| | . ` |  __| |  _  /| | |_ | | |  |__ <
  /:/ /:/ _/_  | |____| |\  | |____| | \ \| |__| |_| |_ ___) |
 /:/ /:/ /\__\ |______|_| \_|______|_|  \_\\_____|_____|____/
 \:\ \/ /:/  /
ENERGI3
echo "${GREEN}  \:\  /:/  /  ${NC}This script determines if autocollateralize is set"
echo "${GREEN}   \:\/:/  /   ${NC}and changes the setting for you. You do not need to"
echo "${GREEN}    \::/  /    ${NC}re-announce masternode or unlock staking after you"
echo "${GREEN}     \/__/     ${NC}run the script."
echo ${NC}
echo

if [[ ! -z ${ISDISABLED} ]]
then
    echo "autocollateralize is ${RED}NOT SET${NC} on the Core Node"
    echo
    echo "To set autocollateralize, type: s"
    echo "Exit without changing, type   : x"
    echo
    read -n 1 -p " Select option (s/[x]): " OPTION
    echo
    OPTION=${OPTION,,}    # tolower
    echo

elif [[ ! -z ${ISENABLED} ]]
then
    echo "autocollateralize is ${GREEN}SET${NC} on the Core Node"
    echo
    echo "Remove autocollateralize, type: r"
    echo "Exit without changing, type   : x"
    echo
    read -n 1 -p " Select option (r/[x]): " OPTION
    echo
    OPTION=${OPTION,,}    # tolower
    echo

elif [[ -z ${CHKIFTHERE} ]]
then
    echo "autocollateralize ${BLUE}PARAMETER NOT ENTERED${NC} on the Core Node"
    echo
    echo "To set autocollateralize, type: s"
    echo "Exit without changing, type   : x"
    echo
    read -n 1 -p " Select option (s/[x]): " OPTION
    echo
    OPTION=${OPTION,,}    # tolower
    echo

fi

# Command functions
_cmd-collChk () {
    # Check status of autocollateralize
    SETTO=`energi3 ${ARG} attach --exec "miner.setAutocollateralize()" 2>/dev/null | head -1`
    if [[ ${SETTO} == 0 ]]
    then
        echo "autocollateralize is OFF"

    elif [[ ${SETTO} == 1 ]]
    then
        echo "autocollateralize is ON"

    fi
}

_cmd-collOff () {
    # Turn autocollateralize off
    energi3 ${ARG} attach --exec "miner.setAutocollateralize(0)" 2>/dev/null 1>/dev/null
    _cmd-collChk

}

_cmd-collOn () {
    # Turn autocollateralize on
    energi3 ${ARG} attach --exec "miner.setAutocollateralize(1)" 2>/dev/null 1>/dev/null
    _cmd-collChk
}

case ${OPTION} in
    s)
      if [[ -z ${CHKIFTHERE} ]]
      then
          _cmd-collOn
	  echo
	  echo "Updating energi3.service file for reboots"
          sudo sed -i 's/node/node --autocollateralize 1/' ${SERVICEFILE}
	  sudo systemctl daemon-reload

      elif [[ -z ${ISENABLED} ]]
      then
          _cmd-collOn
	  echo
	  echo "Updating energi3.service file for reboots"
          sudo sed -i 's/--autocollateralize 0/--autocollateralize 1/' ${SERVICEFILE}
          sudo systemctl daemon-reload
      else
          echo "autocolateralise is already set to roll up"
          echo "No changes made"
      fi

      ;;

    r)
      if [[ -z ${CHKIFTHERE} ]]
      then
          _cmd-collOff
	  echo
	  echo "Updating energi3.service file for reboots"
          sudo sed -i 's/node/node --autocollateralize 0/' ${SERVICEFILE}
          sudo systemctl daemon-reload

      elif [[ -z ${ISDISABLED} ]]
      then
          _cmd-collOff
	  echo
	  echo "Updating energi3.service file for reboots"
          sudo sed -i 's/--autocollateralize 1/--autocollateralize 0/' ${SERVICEFILE}
          sudo systemctl daemon-reload

      fi

      ;;

    *)
      echo
      echo "Exiting without doing anything."
      echo
      exit 0

      ;;

esac

