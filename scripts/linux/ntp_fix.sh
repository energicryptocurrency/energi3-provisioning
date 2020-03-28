#!/bin/bash

######################################################################
# Copyright (c) 2020
# All rights reserved.
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND.
#
# Desc:   Fix NTP (Network Time Protocol) on Ubuntu Linux
#
# Version:
#   1.0.0  20200328  ZA Initial Script
#
: '
# Run the script to get started:
```
bash -ic "$(wget -4qO- -o- raw.githubusercontent.com/energicryptocurrency/energi3-provisioning/master/scripts/linux/ntp_fix.sh)" ; source ~/.bashrc
```
'
######################################################################

if [ -x "$( command -v timedatectl )" ]
then
  echo "Stopping timedatectl..."
  sudo timedatectl set-ntp no
fi

if [ ! -x "$( command -v ntp )" ]
then
  sudo apt install ntp -y
fi

if [ ! -x "$( command -v ntpdate )" ]
then
  sudo apt install ntpdate -y
fi

sleep 0.3
clear
echo
echo
echo "Starting ntp service..."
sudo systemctl start ntp

sleep 0.3
echo
echo
echo -n "NTP status: "
systemctl status ntp | grep Active | awk '{print $2}'

echo

