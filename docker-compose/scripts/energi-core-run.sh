#!/bin/sh
# A script to be used as a Docker container entrypoint to run
# Energi Core node and unlock account for staking.

/usr/sbin/sshd.pam -f "${SSHD_DIR}/sshd_config"
. ./energi_command.sh
exec ${energi_command} \
  --gcmode archive \
  --masternode \
  --maxpeers 32 \
  --mine=1 \
  --nat extip:"$( wget -qO- https://api.ipify.org )" \
  --nousb \
  --password /run/secrets/account_password \
  --unlock "$( cat /run/secrets/account_address )" \
  --unlock.staking \
  --verbosity 0
