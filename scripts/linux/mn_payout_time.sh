#!/bin/bash

# Description: mn_payout_time.sh
#
#              Script to get the rank and time to receive masternode reward
#
# Written:     ZAlam 11-Nov-2020  Initial Script
#
# bash -ic "$(wget -4qO- -o- raw.githubusercontent.com/energicryptocurrency/energi3-provisioning/master/scripts/linux/mn_payout_time.sh)" ; source ~/.bashrc
#

#set -x

# Convert seconds to days, hours, minutes, seconds.
DISPLAYTIME () {
  # Round up the time.
  local T=0
  T=$( printf '%.*f\n' 0 "${1}" )
  local D=$(( T/60/60/24 ))
  local H=$(( T/60/60%24 ))
  local M=$(( T/60%60 ))
  local S=$(( T%60 ))
  (( D > 0 )) && printf '%d days ' "${D}"
  (( H > 0 )) && printf '%d hr ' "${H}"
  (( M > 0 )) && printf '%d min ' "${M}"
  (( S > 0 )) && printf '%d sec ' "${S}"
}

COMMAND="energi3 attach --exec "


# Set an address if you want
#MNADDR=

# Get list of accounts from core node
if [[ -z ${MNADDR} ]]
then
    echo "Getting list of accounts..."
    MNADDR=$( ${COMMAND} "personal.listAccounts" 2>/dev/null | jq -r '.[]' )
fi

# Main program
for ADDR in `echo ${MNADDR}`
do
    ISMN=$( ${COMMAND} "masternode.masternodeInfo('$ADDR').announcedBlock" 2>/dev/null )

    if [[ ${ISMN} -eq 0 ]]
    then
        echo "${ADDR} is not a masternode."

    else

        # Get masternode list
        ${COMMAND} "masternode.listMasternodes()" 2>/dev/null > mnList.json

	# convert to lower case
        ADDR=${ADDR,,} # tolower

        sed -i 's/announcedBlock/"announcedBlock"/g' mnList.json
        sed -i 's/collateral/"collateral"/g' mnList.json
        sed -i 's/enode: /"enode": /g' mnList.json
        sed -i 's/isActive/"isActive"/g' mnList.json
        sed -i 's/isAlive/"isAlive"/g' mnList.json
        sed -i 's/masternode/"masternode"/g' mnList.json
        sed -i 's/owner/"owner"/g' mnList.json
        sed -i 's/swFeatures/"swFeatures"/g' mnList.json
        sed -i 's/swVersion/"swVersion"/g' mnList.json

        COUNTER=0
        TOTCOL=0

        for MNLIST in `cat mnList.json | jq -r '.[] | select (.isActive == true) | select (.swFeatures != "0x0")' | grep owner | awk -F\" '{print $4}'`
        do

	    COL=$( cat mnList.json | jq --arg COUNTER ${COUNTER} '.[$COUNTER | tonumber] .collateral | tonumber' )
            COL=$( printf "%.0f" $COL )
            COL=$( echo " ${COL} / 1000000000000000000 " | bc -l | sed '/\./ s/\.\{0,1\}0\{1,\}$//' )

            TOTCOL=$( echo "$TOTCOL + $COL" | bc -l | sed '/\./ s/\.\{0,1\}0\{1,\}$//' )
        
	    COUNTER=$(( COUNTER + 1 ))

            if [[ "${MNLIST}" == "${ADDR}" ]]
            then
		TIME_TO_REWARD=$( echo "$TOTCOL / 10000 * 60" | bc -l | sed '/\./ s/\.\{0,1\}0\{1,\}$//' )
		TIME_TO_REWARD=$( DISPLAYTIME "${TIME_TO_REWARD}" )

                echo "Address: ${MNLIST} 
Rank: ${COUNTER} 
ETA: ${TIME_TO_REWARD}"
                exit
            fi
        done

        rm mnList.json
    fi
done
