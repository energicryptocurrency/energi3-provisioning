#!/bin/bash

######################################################################
# Copyright (c) 2021
# All rights reserved.
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND.
#
# Desc:   Batch script to change AutoCompounding parameter on VPS
#
# Version:
#   1.0.0 20200321 ZA Initial Script
#   1.1.0 20210112 ZA Update to support v3.1
#   1.1.1 20210817 ZA Update to support support v3.1.0; no change in binary name
#   1.1.2 20211228 ZA Fix `--miner.setAutoCompounding` - Core Node v3.1.1
#
: '
# Run the script to get started:
```
bash -ic "$(wget -4qO- -o- raw.githubusercontent.com/energicryptocurrency/energi3-provisioning/master/scripts/linux/autocompounding.sh)" ; source ~/.bashrc
```
'
######################################################################

# Service File location - adjusted to keep same name
SERVICEFILE=/lib/systemd/system/energi3.service
OLDSERVICEFILE=/lib/systemd/system/energi3.service-tmp

# Set colors
BLUE=`tput setaf 4`
RED=`tput setaf 1`
GREEN=`tput setaf 2`
YELLOW=`tput setaf 2`
NC=`tput sgr0`

# Command functions
_cmd-collChk () {
    # Check status of autocollateralize

    # SETTO=`energi ${ARG} attach --exec "miner.setAutoCompounding()" 2>/dev/null | head -1`
    # if [[ ${SETTO} == 0 ]]
    # then
    #     echo "AutoCompounding is set to ${RED}OFF${NC}"

    # elif [[ ${SETTO} == 1 ]]
    # then
    #     echo "AutoCompounding is set to ${GREEN}ON${NC}"

    # fi
    CHKIFTHERE1=`grep miner.autocollateralize ${SERVICEFILE}`
    CHKIFTHERE2=`grep miner.autocompounding ${SERVICEFILE}`
    if [[ ! -z ${CHKIFTHERE1} ]] || [[ ! -z ${CHKIFTHERE2} ]]
    then
        ISDISABLED1=`grep "miner.autocollateralize 0" ${SERVICEFILE}`
        ISDISABLED2=`grep "miner.autocompounding 0" ${SERVICEFILE}`
        ISENABLED1=`grep "miner.autocollateralize 1" ${SERVICEFILE}`
        ISENABLED2=`grep "miner.autocompounding 1" ${SERVICEFILE}`
        if [[ ! -z ${ISDISABLED1} ]] || [[ ! -z ${ISDISABLED2} ]]
        then
            echo "AutoCompounding is set to ${RED}OFF${NC}"
            SETTO=0
        elif [[ ! -z ${ISENABLED1} ]] || [[ ! -z ${ISENABLED2} ]]
        then
            echo "AutoCompounding is set to ${GREEN}ON${NC}"
            SETTO=1
        fi
    else
        # Default is set to ON
        echo "AutoCompounding is set to ${GREEN}ON${NC}"
        SETTO=1
    fi
}

_cmd-collOff () {
    # Turn autocollateralize off
    energi ${ARG} attach --exec "miner.setAutoCompounding(0)" 2>/dev/null 1>/dev/null
    _cmd-collChk

}

_cmd-collOn () {
    # Turn autocollateralize on
    energi ${ARG} attach --exec "miner.setAutoCompounding(1)" 2>/dev/null 1>/dev/null
    _cmd-collChk
}

_post_message () {

    echo 
    echo "Turn on staking on by attaching to Core Node:"
    echo "   energi3 attach"
    echo
    echo "and then run:"
    echo "   personal.unlockAccount('put_your_address', null, 0, true)"
    echo

}

#
if [[ -f ${SERVICEFILE} ]]
then
    _cmd-collChk

else
    clear
    echo
    echo "Cannot find energi3.service file to update"
    echo "  Filename: ${SERVICEFILE}"
    echo
    echo "Exiting script..."
    echo
    #echo "To manually change setting attach to Core Node:"
    #echo "   energi3 attach"
    #echo
    #echo "and then run:"
    #echo "   miner.setAutoCompounding(0) - to disable"
    #echo "   miner.setAutoCompounding(1) - to enable"
    #echo "   miner.setAutoCompounding()  - to check current setting"
    #echo
    exit 1
fi

#
echo "${GREEN}"
clear 2> /dev/null
cat << "ENERGI3"
      ___       ______ _   _ ______ _____   _____ _____ 
     /\  \     |  ____| \ | |  ____|  __ \ / ____|_   _|
    /::\  \    | |__  |  \| | |__  | |__) | |  __  | |  
   /:/\:\__\   |  __| | . ` |  __| |  _  /| | |_ | | | 
  /:/ /:/ _/_  | |____| |\  | |____| | \ \| |__| |_| |_ 
 /:/ /:/ /\__\ |______|_| \_|______|_|  \_\\_____|_____|
 \:\ \/ /:/  /
ENERGI3
echo "${GREEN}  \:\  /:/  /  ${NC}This script determines if autocollateralize is enabled"
echo "${GREEN}   \:\/:/  /   ${NC}and changes the setting for you. You do not need to"
echo "${GREEN}    \::/  /    ${NC}re-announce masternode or unlock staking after you"
echo "${GREEN}     \/__/     ${NC}run the script."
echo ${NC}
echo

if [[ ${SETTO} == 0 ]]
then
    echo "AutoCompounding is ${RED}DISABLED${NC} on the Core Node"
    #_cmd-collChk
    echo
    echo "To enable AutoCompounding, type: e"
    echo "Exit without making change, type : x"
    echo
    read -n 1 -p " Select option (e/[x]): " OPTION
    echo
    OPTION=${OPTION,,}    # tolower
    echo

elif [[ ${SETTO} == 1 ]]
then
    echo "AutoCompounding is ${GREEN}ENABLED${NC} on the Core Node"
    #_cmd-collChk
    echo
    echo "To disable AutoCompounding, type: d"
    echo "Exit without making change, type : x"
    echo
    read -n 1 -p " Select option (d/[x]): " OPTION
    echo
    OPTION=${OPTION,,}    # tolower
    echo

elif [[ ! -z ${CHKIFTHERE1} ]] || [[ ! -z ${CHKIFTHERE2} ]]
then
    # Blank if parameter is not there
    echo "AutoCompounding ${BLUE}PARAMETER NOT ENTERED${NC} on the Core Node"
    #_cmd-collChk
    echo
    echo "To enable AutoCompounding, type: e"
    echo "To disable AutoCompounding, type: d"
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
      if [[ ! -z ${ISDISABLED1} ]] || [[ ! -z ${ISDISABLED2} ]]
      then
          echo "Updating energi3.service file"
          if [[ -f ${OLDSERVICEFILE} ]]
          then
              sudo mv ${OLDSERVICEFILE} ${SERVICEFILE}
          fi
          sudo sed -i 's/--miner.autocollateralize 0/--miner.autocompounding 1/' ${SERVICEFILE}
          sudo sed -i 's/--miner.autocompounding 0/--miner.autocompounding 1/' ${SERVICEFILE}
          sudo systemctl daemon-reload
          sudo systemctl restart energi3.service
          echo
          #_cmd-collOn
          _post_message
          echo
          
      elif [[ -z ${CHKIFTHERE1} ]] || [[ -z ${CHKIFTHERE2} ]]
      then
          # Parameter not there, add to enable
          echo
          echo "Updating energi3.service file"
          if [[ -f ${OLDSERVICEFILE} ]]
          then
              sudo mv ${OLDSERVICEFILE} ${SERVICEFILE}
          fi
          sudo sed -i 's/node/node --miner.autocompounding 1/' ${SERVICEFILE}
          sudo systemctl daemon-reload
          sudo systemctl restart energi3.service
          echo
          #_cmd-collOn
          _post_message
          echo
          
      else
          echo "AutoCompounding is already set to roll up"
          echo "No changes made"
          echo
          
      fi

      ;;

    d)
      if [[ ! -z ${ISENABLED1} ]] || [[ ! -z ${ISENABLED2} ]]
      then
          echo "Updating energi3.service file"
          if [[ -f ${OLDSERVICEFILE} ]]
          then
              sudo mv ${OLDSERVICEFILE} ${SERVICEFILE}
          fi
          sudo sed -i 's/--miner.autocollateralize 1/--miner.autocompounding 0/' ${SERVICEFILE}
          sudo sed -i 's/--miner.autocompounding 1/--miner.autocompounding 0/' ${SERVICEFILE}
          sudo systemctl daemon-reload
          sudo systemctl restart energi3.service
          echo
          #_cmd-collOff
          _post_message
          echo
          
      elif [[ -z ${CHKIFTHERE1} ]] || [[ -z ${CHKIFTHERE2} ]]
      then
          echo "Updating energi3.service file"
          if [[ -f ${OLDSERVICEFILE} ]]
          then
              sudo mv ${OLDSERVICEFILE} ${SERVICEFILE}
          fi
          sudo sed -i 's/node/node --miner.autocompounding 0/' ${SERVICEFILE}
          sudo systemctl daemon-reload
          sudo systemctl restart energi3.service
          echo
          #_cmd-collOff
          _post_message
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
