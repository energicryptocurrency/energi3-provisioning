#!/bin/bash
while :
do
  if /bin/bash nodemon.sh cron
  then
    sleep "${ECNM_INTERVAL:-'10m'}"
  else
    printf '%s\n%s\n\n' \
      "Exiting Energi Core Node Monitor container cron because of an error." \
      "Please see the output above for details!"
    break
  fi
done
