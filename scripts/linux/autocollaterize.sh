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
bash -ic "$(wget -4qO- -o- raw.githubusercontent.com/energicryptocurrency/energi3-provisioning/master/scripts/linux/autocollaterize.sh)" ; source ~/.bashrc
```
'
######################################################################

# Service File location
SERVICEFILE=/lib/systemd/system/energi3.service

# Set colors
BLUE=`tput setaf 4`
RED=`tput setaf 1`
GREEN=`tput setaf 2`
YELLOW=`tput setaf 2`
NC=`tput sgr0`

# Command functions
_cmd-collChk () {
    # Check status of autocollateralize
    SETTO=`energi3 ${ARG} attach --exec "miner.setAutocollateralize()" 2>/dev/null | head -1`
    if [[ ${SETTO} == 0 ]]
    then
        echo "autocollateralize is set to ${RED}OFF${NC}"

    elif [[ ${SETTO} == 1 ]]
    then
        echo "autocollateralize is set to ${GREEN}ON${NC}"

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

#
if [[ -f ${SERVICEFILE} ]]
then
    CHKIFTHERE=`grep miner.autocollateralize ${SERVICEFILE}`
    ISDISABLED=`grep "miner.autocollateralize 0" ${SERVICEFILE}`
    ISENABLED=`grep "miner.autocollateralize 1" ${SERVICEFILE}`

else
    clear
    echo
    echo "Cannot find energi3.service file to update"
    echo "  Filename: ${SERVICEFILE}"
    echo
    echo "Exiting script..."
    echo
    echo "To manually change setting attach to Core Node:"
    echo "   energi3 attach"
    echo
    echo "and then run:"
    echo "   miner.setAutocollateralize(0) - to disable"
    echo "   miner.setAutocollateralize(1) - to enable"
    echo "   miner.setAutocollateralize()  - to check current setting"
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
echo "${GREEN}  \:\  /:/  /  ${NC}This script determines if autocollateralize is enabled"
echo "${GREEN}   \:\/:/  /   ${NC}and changes the setting for you. You do not need to"
echo "${GREEN}    \::/  /    ${NC}re-announce masternode or unlock staking after you"
echo "${GREEN}     \/__/     ${NC}run the script."
echo ${NC}
echo

if [[ ! -z ${ISDISABLED} ]]
then
    echo "autocollateralize is ${RED}DISABLED{NC} on the Core Node"
    _cmd-collChk
    echo
    echo "To enable autocollateralize, type: e"
    echo "Exit without making change, type : x"
    echo
    read -n 1 -p " Select option (e/[x]): " OPTION
    echo
    OPTION=${OPTION,,}    # tolower
    echo

elif [[ ! -z ${ISENABLED} ]]
then
    echo "autocollateralize is ${GREEN}ENABLED${NC} on the Core Node"
    _cmd-collChk
    echo
    echo "To diable autocollateralize, type: d"
    echo "Exit without making change, type : x"
    echo
    read -n 1 -p " Select option (d/[x]): " OPTION
    echo
    OPTION=${OPTION,,}    # tolower
    echo

elif [[ -z ${CHKIFTHERE} ]]
then
    # Blank if parameter is not there
    echo "autocollateralize ${BLUE}PARAMETER NOT ENTERED${NC} on the Core Node"
    _cmd-collChk
    echo
    echo "To enable autocollateralize, type: e"
    echo "To diable autocollateralize, type: d"
    echo "Exit without making change, type : x"
    echo
    read -n 1 -p " Select option (e/d/[x]): " OPTION
    echo
    OPTION=${OPTION,,}    # tolower
    echo

fi


# Main program
case ${OPTION} in
    e)
      if [[ ! -z ${ISDISABLED} ]]
      then
          echo "Updating energi3.service file for reboots"
          sudo sed -i 's/--miner.autocollateralize 0/--miner.autocollateralize 1/' ${SERVICEFILE}
          sudo systemctl daemon-reload
          echo
          _cmd-collOn
          echo
          
      elif [[ -z ${CHKIFTHERE} ]]
      then
          # Parameter not there, add to enable

          echo
          echo "Updating energi3.service file for reboots"
          sudo sed -i 's/node/node --miner.autocollateralize 1/' ${SERVICEFILE}
          sudo systemctl daemon-reload
          echo
          _cmd-collOn
          echo
          
      else
          echo "autocolateralise is already set to roll up"
          echo "No changes made"
          echo
          
      fi

      ;;

    d)
      if [[ ! -z ${ISENABLED} ]]
      then
          echo "Updating energi3.service file for reboots"
          sudo sed -i 's/--miner.autocollateralize 1/--miner.autocollateralize 0/' ${SERVICEFILE}
          sudo systemctl daemon-reload
          echo
          _cmd-collOff
          echo
          
      elif [[ -z ${CHKIFTHERE} ]]
      then
          echo "Updating energi3.service file for reboots"
          sudo sed -i 's/node/node --miner.autocollateralize 0/' ${SERVICEFILE}
          sudo systemctl daemon-reload
          echo
          _cmd-collOff
          echo
      
      fi

      ;;

    *)
      echo
      echo "Exiting without doing anything."
      echo
      exit 0

      ;;

esac

