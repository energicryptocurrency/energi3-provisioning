#!/bin/bash

#######################################################################
# Copyright (c) 2021
# All rights reserved.
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND.
#
# Desc:   Script to update --mine flag on systemd
# 
# Version:
#   1.0.0  20210406  ZAlam Initial Script

 : '
# Run this file

```
  bash -ic "$(wget -4qO- -o- raw.githubusercontent.com/energicryptocurrency/energi3-provisioning/master/scripts/linux/fix_mine.sh)" ; source ~/.bashrc
```
'

# Systemd service file
SYSTEMD_CONF="/lib/systemd/system/energi3.service"

# Main script
if [[ -f ${SYSTEMD_CONF} ]]
then
    UPDATE=$( grep "\-\-mine " ${SYSTEMD_CONF} )
    if [[ ! -z ${UPDATE} ]]
    then
        echo "Updated ${SYSTEMD_CONF}"
        sudo sed -i 's/--mine /--mine=1 /g' ${SYSTEMD_CONF}

        echo "run: sudo systemctl daemon-reload"

    else
        echo "No update required"

    fi
fi
