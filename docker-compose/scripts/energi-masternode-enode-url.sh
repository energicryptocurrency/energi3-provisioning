#!/bin/sh
enode='admin.nodeInfo.enode'
. ./energi_command.sh
printf '%s:\n' ${enode} && ${energi_command} attach --exec ${enode}

exit ${?}
