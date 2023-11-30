#!/bin/sh
. ./energi_command.sh
exec="${energi_command} attach --exec"
status='miner.stakingStatus()'
syncing='nrg.syncing'

printf '%b:\n' ${syncing} && ${exec} ${syncing} \
&& printf '%b:\n' ${status} && ${exec} ${status}

exit $?
