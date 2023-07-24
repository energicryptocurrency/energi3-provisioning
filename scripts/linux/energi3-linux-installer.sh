#!/bin/bash

######################################################################
# Copyright (c) 2020
# All rights reserved.
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND.
#
# Desc:   Batch script to download and setup Energi3 on Linux. The
#         script will upgrade an existing installation. If v2 is
#         installed on the VPS, the script can be used to auto migrate
#         from v2 to v3.
# 
# Version:
#   1.2.9  20200309  ZA Initial Script
#   1.2.12 20200311  ZA added removedb to upgrade
#   1.2.14 20200312  ZA added create keystore if not downloading
#   1.2.15 20200423  ZA bug in _add_nrgstaker
#
: '
# Run the script to get started:
```
bash -ic "$(wget -4qO- -o- raw.githubusercontent.com/energicryptocurrency/energi3-provisioning/master/scripts/linux/energi3-linux-installer.sh)" ; source ~/.bashrc
```
'
######################################################################

clear
echo "Please run the following script instead:"
echo " bash -ic "$(wget -4qO- -o- raw.githubusercontent.com/energicryptocurrency/energi3-provisioning/master/scripts/linux/energi-linux-installer.sh)"; source ~/.bashrc"
echo
