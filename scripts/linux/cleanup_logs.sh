#!/bin/bash

######################################################################
# Copyright (c) 2020
# All rights reserved.
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND.
#
# Desc:   Batch script to remove uncessary logs and adjust log rotate.
# 
# Version:
#   0.0.1  20200929 DT Initial Script
#   1.0.1  20201012 ZA Added echo to provide information of what is being cleaned
: '
# Run the script to get started:
```
curl raw.githubusercontent.com/energicryptocurrency/energi3-provisioning/master/scripts/linux/cleanup_logs.sh | bash
```
'
######################################################################

# Removes logs ending in .gz and .1 in /var/log
echo "Cleaning /var/log directory..."
sudo find /var/log -name "*.gz" -exec sudo rm {} \;   
sudo find /var/log -name "*.1" -exec sudo rm {} \;

#Request immediate rotation of the journal files and Remove journal files older than specified time
echo "Cleaning up journalctl logs..."
sudo journalctl --rotate
sudo journalctl --vacuum-time=1s

