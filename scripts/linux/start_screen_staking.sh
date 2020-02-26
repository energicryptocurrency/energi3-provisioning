#!/bin/bash
#####################################################################
# Description: This script is to start energi core node masternode server within screen 
#
# Download this script
# wget https://raw.githubusercontent.com/energicryptocurrency/energi3-provisioning/master/scripts/linux/start_screen_staking.sh
#####################################################################
#

export PATH=$HOME/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/snap/bin:$HOME/energi3/bin

# Start masternode in screen
screen -S energi3 start_staking.sh