#!/bin/bash

#######################################################################
# Copyright (c) 2022
# All rights reserved.
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND.
#
# Desc:   NRG Monitor Toolset: Set of tools to monitor and manage NRG
#         Core Node, the reward received and notify the user via email
#         SMS and Social Media channels. Currently, Discord and Telegram
#         are the social media channels supported.
#
# Version:
#   1.0.0  20200416  ZAlam Initial Script
#   1.0.2  20200423  ZAlam Bug fixes; Email & SMS integration
#   1.0.3  20200424  ZAlam Updating report post
#   1.0.4  20200426  ZAlam Sudo, Telegram and other fixes
#   1.0.5  20200430  ZAlam Clean-up, add stake calc and chain split
#   1.0.6  20200430  ZAlam Stake Calc bug fix
#   1.0.7  20200502  ZAlam Added reset functionality
#   1.1.0  20200504  ZAlam First Public Release
#   1.1.1  20200505  ZAlam Update email content
#   1.1.2  20200507  ZAlam Masternode ETA
#   1.2.0  20200521  ZAlam name change to energi
#   1.2.1  20201015  ZAlam Updated MN Reward time calculation
#   1.3.0  20210208  ZAlam Update USRNAME & DATADIR; support all versions
#   1.3.1  20211208  ZAlam Energi Core Node repo change
#   1.3.5  20210101  ZAlam Exclude TTY executions & use correct ${ENERGI_EXEC} binary

# Energi Core Node Monitor for `energi-docker-compose`
#
# This is a modified version of
# https://github.com/energicryptocurrency/energi3-provisioning/blob/master/scripts/linux/nodemon.sh
# that is adjusted to use it with the dockerised Energi Core Node.

INTERACTIVE=${INTERACTIVE_SETUP:-yes}
source nodemon_helper.sh

# Set script version
NODEMONVER=1.3.5

: '
# Run this file

```
  bash -ic "$(wget -4qO- -o- raw.githubusercontent.com/energicryptocurrency/energi3-provisioning/master/scripts/linux/nodemon.sh)" ; source ~/.bashrc
```
'

# Load parameters from external conf file
if [[ -f /var/multi-masternode-data/nodebot/nodemon.conf ]]; then
  . /var/multi-masternode-data/nodebot/nodemon.conf
else
  SENDEMAIL=N
  SENDSMS=N
fi

# Which Timezone you want to see notices
export TZ=UTC

function CTRL_C() {
  stty sane 2>/dev/null
  printf '\e[0m\n'

  exit
}

trap CTRL_C INT
# Define simple variables.
stty sane 2>/dev/null
arg1="${1}"
arg2="${2}"
arg3="${3}"
RE='^[0-9]+$'
DISCORD_WEBHOOK_USERNAME_DEFAULT='Energi Node Monitor'
DISCORD_WEBHOOK_AVATAR_DEFAULT='https://i.imgur.com/8WHSSa7s.jpg'
DISCORD_TITLE_LIMIT=266
# NRG Parameters
GITAPI_URL="https://api.github.com/repos/energicryptocurrency/energi/releases/latest"
# Set variables
MNTOTALNRG=0
REMOVE_TRALING_DECIMAL_ZEROS_PATTERN='/\./ s/\.\?0\+$//'
# get username; exclude testnet
USRNAME=$(find /home -name nodekey 2>&1 |
  grep -v "Permission denied" |
  grep -v testnet |
  awk -F\/ '{print $3}')

if [[ -z ${USRNAME} ]]; then
  USRNAME=$(basename "${STAKER_HOME}")
fi

ENERGI_EXEC="${ENERGI_BIN}"
printf 'Using binary: %s\n' "${ENERGI_EXEC}"

LOGDIR="${STAKER_HOME}/log"
LOGFILE="${LOGDIR}/nodemon.log"

if [[ -z "${CURRENCY:=$ECNM_CURRENCY}" ]]; then
  CURRENCY=USD
fi

# Set colors
BLUE=$(tput setaf 4)
NC=$(tput sgr0)

# Script can be run as root or nrgstaker
if [[ $EUID != 0 ]]; then
  ISSUDOER=$(getent group sudo | grep "${USRNAME}")

  if [ -z "${ISSUDOER}" ]; then
    printf "User \`%s\` does not have sudo permissions.\n" "${USRNAME}"
    printf 'Run %ssudo ls -l%s to set permissions ' "${BLUE}" "${NC}"
    printf "if you know the user \`%s\` has sudo privileges " "${USRNAME}"
    printf 'and then rerun the script\nExiting script...\n'
    sleep 3

    exit 1
  fi
fi

DATADIR="${ENERGI_CORE_DIR}"

if [[ ! -f ${DATADIR}/energi3/nodekey ]]; then
  printf "Cannot determine \`DATADIR\`\n"
  DATADIR=''
fi

# Attach command
if [[ -z ${DATADIR} ]]; then
  COMMAND="${ENERGI_EXEC} ${ARG} attach --exec "
else
  COMMAND="${ENERGI_EXEC} ${ARG} --datadir ${DATADIR} attach --exec "
fi

if [[ ${ARG} == '--testnet' ]]; then
  NODEAPICOMMAND="${ENERGI_EXEC} attach https://nodeapi.test.energi.network --exec "
  NRGAPI="https://explorer.test.energi.network/api"
else
  NODEAPICOMMAND="${ENERGI_EXEC} attach https://nodeapi.energi.network --exec "
  NRGAPI="https://explorer.energi.network/api"
fi

if [[ "${arg1}" == 'version' ]]; then
  echo "Version: ${NODEMONVER}"
  exit 0
fi

if [[ "${arg2}" == 'version' ]]; then
  echo "Version: ${NODEMONVER}"
  exit 0
fi

if [[ "${arg3}" == 'version' ]]; then
  echo "Version: ${NODEMONVER}"
  exit 0
fi

# debug arg.
DEBUG_OUTPUT=0

if [[ "${arg1}" == 'debug' ]]; then
  DEBUG_OUTPUT=1
fi

if [[ "${arg2}" == 'debug' ]]; then
  DEBUG_OUTPUT=1
fi

if [[ "${arg3}" == 'debug' ]]; then
  DEBUG_OUTPUT=1
fi

# reset arg.
RESET=n

if [[ "${arg1}" == 'reset' ]]; then
  RESET=y
fi

if [[ "${arg2}" == 'reset' ]]; then
  RESET=y
fi

if [[ "${arg3}" == 'reset' ]]; then
  RESET=y
fi

TEST_OUTPUT=0

if [[ "${arg1}" == 'test' ]]; then
  TEST_OUTPUT=1
fi

if [[ "${arg2}" == 'test' ]]; then
  TEST_OUTPUT=1
fi

if [[ "${arg3}" == 'test' ]]; then
  TEST_OUTPUT=1
fi

# Get bc.
if [ ! -x "$(command -v bc)" ]; then
  sudo DEBIAN_FRONTEND=noninteractive apt-get install -yq bc
fi

# Set defaults.
# RAM.
if [[ -z "${LOW_MEM_WARN_MB}" ]]; then
  LOW_MEM_WARN_MB=850
fi

if [[ -z "${LOW_MEM_WARN_PERCENT}" ]]; then
  LOW_MEM_WARN_PERCENT=2
fi

if [[ -z "${LOW_MEM_ERROR_MB}" ]]; then
  LOW_MEM_ERROR_MB=725
fi

if [[ -z "${LOW_MEM_ERROR_PERCENT}" ]]; then
  LOW_MEM_ERROR_PERCENT=1
fi

# SWAP.
if [[ -z "${LOW_SWAP_ERROR_MB}" ]]; then
  LOW_SWAP_ERROR_MB=512
fi

if [[ -z "${LOW_SWAP_WARN_MB}" ]]; then
  LOW_SWAP_WARN_MB=1024
fi

# Hard Drive Space.
if [[ -z "${LOW_HDD_ERROR_MB}" ]]; then
  LOW_HDD_ERROR_MB=512
fi

LOW_HDD_ERROR_KB=$(echo "${LOW_HDD_ERROR_MB} * 1024" | bc)

if [[ -z "${LOW_HDD_WARN_MB}" ]]; then
  LOW_HDD_WARN_MB=1536
fi

LOW_HDD_WARN_KB=$(echo "${LOW_HDD_WARN_MB} * 1024" | bc)

if [[ -z "${LOW_HDD_BOOT_ERROR_MB}" ]]; then
  LOW_HDD_BOOT_ERROR_MB=64
fi

LOW_HDD_BOOT_ERROR_KB=$(echo "${LOW_HDD_BOOT_ERROR_MB} * 1024" | bc)

if [[ -z "${LOW_HDD_BOOT_WARN_MB}" ]]; then
  LOW_HDD_BOOT_WARN_MB=128
fi

LOW_HDD_BOOT_WARN_KB=$(echo "${LOW_HDD_BOOT_WARN_MB} * 1024" | bc)

# CPU Load.
if [[ -z "${CPU_LOAD_ERROR}" ]]; then
  CPU_LOAD_ERROR=4
fi

if [[ -z "${CPU_LOAD_WARN}" ]]; then
  CPU_LOAD_WARN=2
fi

if [[ ! -f /var/multi-masternode-data/nodebot/nodemon.sh ]]; then
  # APT update/upgrade if new install
  sudo DEBIAN_FRONTEND=noninteractive apt-get update
  sudo DEBIAN_FRONTEND=noninteractive apt-get upgrade -yq
fi

# Get sqlite.
if [ ! -x "$(command -v sqlite3)" ]; then
  sudo DEBIAN_FRONTEND=noninteractive apt-get install -yq sqlite3
fi

# Get jq.
if [ ! -x "$(command -v jq)" ]; then
  sudo DEBIAN_FRONTEND=noninteractive apt-get install -yq jq
fi

# Get ntpdate.
if [ ! -x "$(command -v ntpdate)" ]; then
  sudo DEBIAN_FRONTEND=noninteractive apt-get install -yq ntpdate
fi

# Get debsums.
if [ ! -x "$(command -v debsums)" ]; then
  sudo DEBIAN_FRONTEND=noninteractive apt-get install -yq debsums
fi

# Get rkhunter
if [ ! -x "$(command -v rkhunter)" ]; then
  sudo DEBIAN_FRONTEND=noninteractive apt-get install -yq rkhunter
fi

# Run a sqlite query.
SQL_QUERY() {
  if [[ ! -d /var/multi-masternode-data/nodebot ]]; then
    sudo mkdir -p /var/multi-masternode-data/nodebot
  fi

  sudo sqlite3 -batch /var/multi-masternode-data/nodebot/nodemon.db "${1}"
}

# Formatted sqlite report
SQL_REPORT() {
  sqlite3 -header -column -separator ROW /var/multi-masternode-data/nodebot/nodemon.db "${1}"
}

# Create tables if they do not exist.
# Key Value table.
SQL_QUERY "CREATE TABLE IF NOT EXISTS variables (
  key TEXT PRIMARY KEY,
  value TEXT NOT NULL
);"
# System logs.
SQL_QUERY "CREATE TABLE IF NOT EXISTS system_log (
  name TEXT PRIMARY KEY,
  start_time INTEGER ,
  last_ping_time INTEGER ,
  message TEXT
);"
# Daemon logs.
SQL_QUERY "CREATE TABLE IF NOT EXISTS node_log (
  conf_loc TEXT,
  type TEXT,
  start_time INTEGER ,
  last_ping_time INTEGER ,
  message TEXT,
  PRIMARY KEY (conf_loc, type)
);"
# Staking rewards
SQL_QUERY "CREATE TABLE IF NOT EXISTS stake_rewards (
  stakeAddress TEXT,
  rewardTime INTEGER,
  blockNum INTEGER,
  reward INTEGER,
  balance REAL,
  nrgPrice REAL,
  PRIMARY KEY (stakeAddress, blockNum)
);"
# Masternode rewards
SQL_QUERY "CREATE TABLE IF NOT EXISTS mn_rewards (
  mnAddress TEXT,
  rewardTime INTEGER,
  blockNum INTEGER,
  reward INTEGER,
  balance REAL,
  nrgPrice REAL,
  PRIMARY KEY (mnAddress, blockNum)
);"
SQL_QUERY "CREATE TABLE IF NOT EXISTS mn_blocks (
  mnAddress TEXT PRIMARY KEY,
  mnBlocksReceived TEXT,
  startMnBlk INTEGER,
  endMnBlk INTEGER,
  mnTotalReward INTEGER
);"
# Network Difficulty table.
SQL_QUERY "CREATE TABLE IF NOT EXISTS net_difficulty (
  blockNum INTEGER PRIMARY KEY,
  difficulty INTEGER NOT NULL
);"

# Insert seed data; give poll 5 blocks from current
CURRENTBLKNUM=$(${COMMAND} "nrg.blockNumber" 2>/dev/null | jq -r '.')
CURRENTBLKNUM=$(printf '%s - 5\n' "${CURRENTBLKNUM}" | bc -l)

if [[ -S ${DATADIR}/energi3.ipc ]] && [[ ${CURRENTBLKNUM} -gt 0 ]]; then
  SQL_QUERY "INSERT OR IGNORE INTO variables
    VALUES ('last_block_checked', '${CURRENTBLKNUM}');"
else
  printf '%s\n' "${DATADIR}"
  printf '%s\n' "${COMMAND}"
  printf '%s\n' "$(${COMMAND} "nrg.blockNumber" 2>/dev/null | jq -r '.')"
  printf '%s\n' "${CURRENTBLKNUM}"
  printf "\`%s\` is not running. Exiting nodemon.\n" "${ENERGI_EXEC}"

  exit 1
fi

# Daemon_bin_name URL_to_logo Bot_name
DAEMON_BIN_LUT="
${ENERGI_EXEC} https://s2.coinmarketcap.com/static/img/coins/128x128/3218.png Energi Monitor
"
# Daemon_bin_name minimum_balance_to_stake staking_reward mn_reward_factor confirmations cooloff_seconds networkhashps_multiplier ticker_name blocktime_seconds
DAEMON_BALANCE_LUT="
${ENERGI_EXEC} 1 2.28 0.914 101 3600 0.000001 NRG 60
"

# Add timestamp to Log
log() {
  echo "[$(date --rfc-3339=seconds)]: $*" >>"$LOGFILE"
}

# Convert seconds to days, hours, minutes, seconds.
DISPLAYTIME() {
  # Round up the time.
  local T=0
  T=$(printf '%.*f\n' 0 "${1}")
  local D=$((T / 60 / 60 / 24))
  local H=$((T / 60 / 60 % 24))
  local M=$((T / 60 % 60))
  local S=$((T % 60))
  ((D > 0)) && printf '%d days ' "${D}"
  ((H > 0)) && printf '%d hr ' "${H}"
  ((M > 0)) && printf '%d min ' "${M}"
  ((S > 0)) && printf '%d sec ' "${S}"
}

# Check if FIRST version is greater than SECOND version
_version_gt() {
  test "$(printf '%s\n' "$@" | sort -V | head -n 1)" != "$1"
}

RESET_NODEMON() {
  printf '\nThis will remove the database and the exiting nodemon script\n\n'
  REPLY=''
  read -p "Do you want to completely remove nodemon? y/[n]: "
  REPLY=${REPLY,,} # tolower

  if [[ "${REPLY}" == "n" ]] || [[ -z "${REPLY}" ]]; then
    printf '\nExiting script without removing nodemon...\n\n'
    exit 0
  fi

  echo
  echo "Removing nodemon database"
  sudo rm -rf /var/multi-masternode-data/nodebot

  exit 0
}

# Send the data to discord via webhook.
DISCORD_WEBHOOK_SEND() {
  (
    local SERVER_ALIAS
    local SHOW_IP
    local _PAYLOAD
    local IP_ADDRESS=''
    local URL="${1}"
    local DESCRIPTION="${2}"
    local TITLE="${3}"
    local DISCORD_WEBHOOK_USERNAME="${4}"
    local DISCORD_WEBHOOK_AVATAR="${5}"
    local DISCORD_WEBHOOK_COLOR="${6}"
    local SERVER_INFO="${7}"

    # Username to show.
    if [[ -z "${DISCORD_WEBHOOK_USERNAME}" ]]; then
      DISCORD_WEBHOOK_USERNAME="${DISCORD_WEBHOOK_USERNAME_DEFAULT}"
    fi

    # Avatar to show.
    if [[ -z "${DISCORD_WEBHOOK_AVATAR}" ]]; then
      DISCORD_WEBHOOK_AVATAR="${DISCORD_WEBHOOK_AVATAR_DEFAULT}"
    fi

    if [[ -z "${SERVER_INFO}" ]]; then
      SERVER_INFO="$(message_date)"
      # Show Server Alias.
      SERVER_ALIAS=$(SQL_QUERY "SELECT value FROM variables WHERE key = 'server_alias';")

      if [[ -z "${SERVER_ALIAS}" ]]; then
        SERVER_ALIAS=$(hostname)
      fi

      if [[ -n "${SERVER_ALIAS}" ]]; then
        SERVER_INFO="${SERVER_INFO}
- ${SERVER_ALIAS}"
      fi

      # Show IP Address.
      SHOW_IP=$(SQL_QUERY "SELECT value FROM variables WHERE key = 'show_ip';")

      if [[ "${SHOW_IP}" -gt 0 ]]; then
        IP_ADDRESS=$(ip_address)
      fi

      if [[ -n "${IP_ADDRESS}" ]]; then
        SERVER_INFO="${SERVER_INFO}
- ${IP_ADDRESS}"
      fi
    fi

    # Replace new line with \n
    SERVER_INFO=$(echo "${SERVER_INFO}" | awk '{printf "%s\\n", $0}')
    TITLE=$(echo "${TITLE}" | tr '\n' ' ')
    ALT_DESC=''

    while read -r LINE; do
      CURRENT_CHAR_COUNT=$(echo "${ALT_DESC}" | tail -n 1 | wc -c)
      NEW_LINE_CHAR_COUNT=$(echo "${LINE}\n " | wc -c)
      NEW_TOTAL=$((CURRENT_CHAR_COUNT + NEW_LINE_CHAR_COUNT))

      if [[ "${NEW_TOTAL}" -lt "${DISCORD_TITLE_LIMIT}" ]]; then
        ALT_DESC="${ALT_DESC}${LINE}\n"
      else
        ALT_DESC="${ALT_DESC}
${LINE}\n"
      fi
    done <<<"${DESCRIPTION}"

    # Split up the description into mutiple embeds.
    LINE_COUNT=$(echo "${ALT_DESC}" | wc -l)
    COUNTER=0
    EMBEDS='['
    while read -r LINE; do
      COUNTER=$((COUNTER + 1))

      if [[ -n "${LINE}" ]]; then
        EMBEDS="${EMBEDS}{
      \"color\": ${DISCORD_WEBHOOK_COLOR},
      \"title\": \"${LINE}\""
      fi

      if [[ "${COUNTER}" -lt "${LINE_COUNT}" ]]; then
        EMBEDS="${EMBEDS}
      },
"
      else
        EMBEDS="${EMBEDS},
      \"description\": \"${SERVER_INFO}\"
      }"
      fi
    done <<<"${ALT_DESC}"

    EMBEDS="${EMBEDS}]"
    # Build HTTP POST.
    _PAYLOAD=$(
      cat <<PAYLOAD
{
  "username": "${DISCORD_WEBHOOK_USERNAME} - ${SERVER_ALIAS}",
  "avatar_url": "${DISCORD_WEBHOOK_AVATAR}",
  "content": "**${TITLE}**",
  "embeds": ${EMBEDS}
}
PAYLOAD
    )

    # Do the post.
    OUTPUT=$(curl \
      -H "Content-Type: application/json" \
      -s \
      -X POST "${URL}" \
      -d "${_PAYLOAD}" | sed '/^[[:space:]]*$/d')

    if [[ -n "${OUTPUT}" ]]; then
      # Wait if we got throttled.
      MS_WAIT=$(printf '%s' "${OUTPUT}" | jq -r '.retry_after' 2>/dev/null)

      if [[ -n "${MS_WAIT}" ]]; then
        SECONDS_WAIT=$(printf "%.1f" \
          "$(printf 'scale=3; %s / 1000\n' "${MS_WAIT}" | bc -l)")
        SECONDS_WAIT=$(printf '%s + 0.1\n' "${SECONDS_WAIT}" | bc -l)
        sleep "${SECONDS_WAIT}"
        OUTPUT=$(curl \
          -H "Content-Type: application/json" \
          -s \
          -X POST "${URL}" \
          -d "${_PAYLOAD}" | sed '/^[[:space:]]*$/d')
      fi
    fi

    # If only errors get a return value.
    if [[ -n "${OUTPUT}" ]]; then
      echo "Discord Error"
      _PAYLOAD=$(echo "${_PAYLOAD}" | tr -d \')
      echo "curl -H \"Content-Type: application/json\" -v ${URL} -d '${_PAYLOAD}'"
      echo "Output:"
      echo "${OUTPUT}" | jq '.'
      echo "Payload:"
      echo "${_PAYLOAD}"
      echo "-"
    fi
  )
}

# Get the webhook url and test to make sure it works.
DISCORD_WEBHOOK_URL_PROMPT() {
  # Title of this webhook.
  TEXT_A="${1}"
  # Url of the existing webhook.
  DISCORD_WEBHOOK_URL="${2}"

  while :; do
    printf "\n%s's webhook url: " "${TEXT_A}"
    override_read "${DISCORD_WEBHOOK_URL}"
    DISCORD_WEBHOOK_URL="${REPLY:-${DISCORD_WEBHOOK_URL}}"

    if [[ -n "${DISCORD_WEBHOOK_URL}" ]]; then
      TOKEN=$(wget -qO- -o- "${DISCORD_WEBHOOK_URL}" | jq -r '.token')

      if [[ -z "${TOKEN}" ]]; then
        printf 'Given URL is not a webhook.\n\n'
        printf 'Get Webhook URL: Your personal server '
        printf '(press plus on left if you do not have one)'
        printf ' -> Right click on your server -> Server Settings -> Webhooks'
        printf ' -> Create Webhook -> Copy webhook url -> save\n'
        DISCORD_WEBHOOK_URL=''

        if ! value_to_bool "${INTERACTIVE}"; then
          echo "Exiting..."

          exit 1
        fi
      else
        printf '%s\n' "${TOKEN}"

        break
      fi
    fi

    sleep 1
  done

  SQL_QUERY "REPLACE INTO variables (key,value) VALUES ('discord_webhook_url_${TEXT_A}','${DISCORD_WEBHOOK_URL}');"
}

# Prompt for all webhooks that we need.
GET_DISCORD_WEBHOOKS() {
  # Get webhook url from discord.
  echo
  echo -n 'Get Webhook URL: Your personal server (press plus on left if you do not have one)'
  echo -n ' -> text channels, general, click gear to "edit channel" -> Left side SELECT Webhooks'
  echo -n ' -> Create Webhook -> Copy webhook url -> save'
  echo
  echo "This webhook will be used for ${TEXT_A} Messages."
  echo 'You can reuse the same webhook url if you want all alerts and information'
  echo 'pings in the same channel.'

  # Errors.
  DISCORD_WEBHOOK_URL=$(SQL_QUERY \
    "SELECT value FROM variables WHERE key = 'discord_webhook_url_error';")
  DISCORD_WEBHOOK_URL_PROMPT \
    "error" \
    "${DISCORD_WEBHOOK_ERROR:-${DISCORD_WEBHOOK_URL}}"
  SEND_ERROR "Test Error"

  # Warnings.
  DISCORD_WEBHOOK_URL=$(SQL_QUERY \
    "SELECT value FROM variables WHERE key = 'discord_webhook_url_warning';")
  DISCORD_WEBHOOK_URL_PROMPT \
    "warning" \
    "${DISCORD_WEBHOOK_WARNING:-${DISCORD_WEBHOOK_URL}}"
  SEND_WARNING "Test Warning"

  # Info.
  DISCORD_WEBHOOK_URL=$(SQL_QUERY \
    "SELECT value FROM variables WHERE key = 'discord_webhook_url_information';")
  DISCORD_WEBHOOK_URL_PROMPT \
    "information" \
    "${DISCORD_WEBHOOK_INFORMATION:-${DISCORD_WEBHOOK_URL}}"
  SEND_INFO "Test Info"

  # Success.
  DISCORD_WEBHOOK_URL=$(SQL_QUERY \
    "SELECT value FROM variables WHERE key = 'discord_webhook_url_success';")
  DISCORD_WEBHOOK_URL_PROMPT \
    "success" \
    "${DISCORD_WEBHOOK_SUCCESS:-${DISCORD_WEBHOOK_URL}}"
  SEND_SUCCESS "Test Success"
}

# Send the data to telegram via bot.
TELEGRAM_SEND() {
  (
    local SERVER_INFO
    local SHOW_IP
    local SERVER_ALIAS
    local _PAYLOAD
    local TOKEN="${1}"
    local CHAT_ID="${2}"
    local TITLE="${3}"
    local MESSAGE="${4}"
    local SERVER_INFO="${5}"

    # Translate discord emojis to telegram.
    # https://apps.timwhitlock.info/emoji/tables/unicode
    # http://www.unicode.org/emoji/charts/full-emoji-list.html
    # https://onlineutf8tools.com/convert-utf8-to-bytes
    MESSAGE=$(echo "${MESSAGE}" |
      sed 's/:exclamation:/\xE2\x9D\x97/g' |
      sed 's/:unlock:/\xF0\x9F\x94\x93/g' |
      sed 's/:warning:/\xE2\x9A\xA0/g' |
      sed 's/:blue_book:/\xF0\x9F\x93\x98/g' |
      sed 's/:money_mouth:/\xF0\x9F\xA4\x91/g' |
      sed 's/:moneybag:/\xF0\x9F\x92\xB0/g' |
      sed 's/:floppy_disk:/\xF0\x9F\x92\xBE/g' |
      sed 's/:desktop:/\xF0\x9F\x96\xA5/g' |
      sed 's/:wrench:/\xF0\x9F\x94\xA7/g' |
      sed 's/:watch:/\xE2\x8C\x9A/g' |
      sed 's/:link:/\xF0\x9F\x94\x97/g' |
      sed 's/:fire:/\xF0\x9F\x94\xA5/g')

    TITLE=$(echo "${TITLE}" |
      sed 's/:exclamation:/\xE2\x9D\x97/g' |
      sed 's/:unlock:/\xF0\x9F\x94\x93/g' |
      sed 's/:warning:/\xE2\x9A\xA0/g' |
      sed 's/:blue_book:/\xF0\x9F\x93\x98/g' |
      sed 's/:money_mouth:/\xF0\x9F\xA4\x91/g' |
      sed 's/:moneybag:/\xF0\x9F\x92\xB0/g' |
      sed 's/:floppy_disk:/\xF0\x9F\x92\xBE/g' |
      sed 's/:desktop:/\xF0\x9F\x96\xA5/g' |
      sed 's/:wrench:/\xF0\x9F\x94\xA7/g' |
      sed 's/:watch:/\xE2\x8C\x9A/g' |
      sed 's/:link:/\xF0\x9F\x94\x97/g' |
      sed 's/:fire:/\xF0\x9F\x94\xA5/g')

    if [[ -z "${SERVER_INFO}" ]]; then
      SERVER_INFO="$(message_date)"
      SHOW_IP=$(SQL_QUERY "SELECT value FROM variables WHERE key = 'show_ip';")

      if [[ "${SHOW_IP}" -gt 0 ]]; then
        SERVER_INFO=$(
          printf "%s\n - " "${SERVER_INFO}"
          ip_address
        )
      fi

      SERVER_ALIAS=$(SQL_QUERY \
        "SELECT value FROM variables WHERE key = 'server_alias';")

      if [[ -z "${SERVER_ALIAS}" ]]; then
        # shellcheck disable=SC2028
        SERVER_INFO=$(
          printf "%s\n - " "${SERVER_INFO}"
          hostname
        )
      else
        SERVER_INFO=$(printf "%s\n - %s\n" "${SERVER_INFO}" "${SERVER_ALIAS}")
      fi
    fi

    _PAYLOAD=$(printf 'text=<b>%s</b>\n<i>%s</i>\n%s' \
      "${TITLE}" "${SERVER_INFO}" "$MESSAGE")
    URL="https://api.telegram.org/bot$TOKEN/sendMessage"
    TELEGRAM_MSG=$(curl -s -X POST "${URL}" \
      -d "chat_id=${CHAT_ID}&parse_mode=html" -d "${_PAYLOAD}" |
      sed '/^[[:space:]]*$/d')
    IS_OK=$(printf '%s' "${TELEGRAM_MSG}" | jq '.ok')

    if [[ "${IS_OK}" != true ]]; then
      printf "Telegram Error\n%s\nPayload: \n%s\n-\n" \
        "$("${TELEGRAM_MSG}" | jq '.')" "${_PAYLOAD}"
    fi

    # Rate limit this function.
    sleep 0.3
  )
}

# Install telegram bot.
TELEGRAM_SETUP() {
  TOKEN=$(SQL_QUERY "SELECT value FROM variables WHERE key = 'telegram_token';")

  if [[ -z "${TOKEN}" ]]; then
    TEXT_B="Enter"
  else
    TEXT_B="Replace"
  fi

  printf '%sTelegram Token [%s]: \n' "${TEXT_B}" "${TOKEN}"
  override_read "${TOKEN:-${TELEGRAM_BOT_TOKEN}}"

  if [[ -n "${REPLY}" ]]; then
    TOKEN="${REPLY}"
  fi

  CHAT_ID=$(SQL_QUERY "SELECT value FROM variables WHERE key = 'telegram_chatid';")

  if [[ -z "${CHAT_ID}" ]] || [[ "${CHAT_ID}" == 'null' ]]; then
    IS_OK='false'

    while [[ "${IS_OK}" == true ]]; do
      GET_UPDATES=$(curl -s "https://api.telegram.org/bot${TOKEN}/getUpdates")
      IS_OK=$(echo "${GET_UPDATES}" | jq '.ok')

      if [[ "${IS_OK}" != true ]]; then
        echo "Could not get a response from Telegram Bot."
        echo "Login to Telegram and post a message to the bot."

        if ! value_to_bool "${interactive:-'yes'}"; then
          REPLY=check
        else
          read -p "Press ENTER to check again or q to quit." -r
        fi

        REPLY=${REPLY,,} # tolower

        if [[ "${REPLY}" == q ]]; then
          return 1 2>/dev/null
        else
          break
        fi
      fi
      sleep 3
    done

    while :; do
      GET_UPDATES=$(curl -s "https://api.telegram.org/bot${TOKEN}/getUpdates")
      CHAT_ID=$(echo "${GET_UPDATES}" |
        jq '.result[0].message.chat.id' 2>/dev/null)

      if [[ -z "${CHAT_ID}" ]]; then
        echo "Login to Telegram and post a message to the bot."
      else
        SQL_QUERY "REPLACE INTO variables (key,value) VALUES ('telegram_token','${TOKEN}');"
        SQL_QUERY "REPLACE INTO variables (key,value) VALUES ('telegram_chatid','${CHAT_ID}');"

        break
      fi
    done
  fi

  TITLE="Test Title"
  MESSAGE="Bot Works!"
  TELEGRAM_SEND "${TOKEN}" "${CHAT_ID}" "${TITLE}" "<pre>${MESSAGE}</pre>"
}

# Send an error messsage to discord and telegram.
SEND_ERROR() {
  URL=$(SQL_QUERY "SELECT value FROM variables WHERE key = 'discord_webhook_url_error';")
  TOKEN=$(SQL_QUERY "SELECT value FROM variables WHERE key = 'telegram_token';")
  CHAT_ID=$(SQL_QUERY "SELECT value FROM variables WHERE key = 'telegram_chatid';")

  DESCRIPTION="${1}"
  if [[ -z "${DESCRIPTION}" ]]; then
    DESCRIPTION="Default Error Message!"
  fi

  TITLE="${2}"

  if [[ -z "${TITLE}" ]]; then
    TITLE=":exclamation: Error :exclamation:"
  fi

  DISCORD_WEBHOOK_COLOR="${5}"

  if [[ -z "${DISCORD_WEBHOOK_COLOR}" ]]; then
    DISCORD_WEBHOOK_COLOR=16711680
  fi

  if [[ -n "${6}" ]]; then
    URL="${6}"
  fi

  SENT=0

  if [[ -n "${URL}" ]]; then
    SENT=1
    DISCORD_WEBHOOK_SEND \
      "${URL}" \
      "${DESCRIPTION}" \
      "${TITLE}" \
      "${3}" \
      "${4}" \
      "${DISCORD_WEBHOOK_COLOR}"
  fi

  if [[ -n "${TOKEN}" ]] && [[ -n "${CHAT_ID}" ]]; then
    SENT=1
    TELEGRAM_SEND "${TOKEN}" "${CHAT_ID}" "${TITLE}" "<code>${DESCRIPTION}</code>"
  fi

  if [[ "${SENT}" -eq 0 ]] || [[ "${DEBUG_OUTPUT}" -eq 1 ]]; then
    echo "${TITLE}" >/dev/tty
    echo "${DESCRIPTION}" >/dev/tty
    echo "-" >/dev/tty
  fi
}

SEND_WARNING() {
  URL=$(SQL_QUERY "SELECT value FROM variables WHERE key = 'discord_webhook_url_warning';")
  TOKEN=$(SQL_QUERY "SELECT value FROM variables WHERE key = 'telegram_token';")
  CHAT_ID=$(SQL_QUERY "SELECT value FROM variables WHERE key = 'telegram_chatid';")

  DESCRIPTION="${1}"
  if [[ -z "${DESCRIPTION}" ]]; then
    DESCRIPTION="Default Warning Message."
  fi

  TITLE="${2}"

  if [[ -z "${TITLE}" ]]; then
    TITLE=":warning: Warning :warning:"
  fi

  DISCORD_WEBHOOK_COLOR="${5}"

  if [[ -z "${DISCORD_WEBHOOK_COLOR}" ]]; then
    DISCORD_WEBHOOK_COLOR=16776960
  fi

  if [[ -n "${6}" ]]; then
    URL="${6}"
  fi

  SENT=0

  if [[ -n "${URL}" ]]; then
    SENT=1
    DISCORD_WEBHOOK_SEND "${URL}" "${DESCRIPTION}" "${TITLE}" "${3}" "${4}" "${DISCORD_WEBHOOK_COLOR}"
  fi

  if [[ -n "${TOKEN}" ]] && [[ -n "${CHAT_ID}" ]]; then
    SENT=1
    TELEGRAM_SEND "${TOKEN}" "${CHAT_ID}" "${TITLE}" "<pre>${DESCRIPTION}</pre>"
  fi

  if [[ "${SENT}" -eq 0 ]] || [[ "${DEBUG_OUTPUT}" -eq 1 ]]; then
    echo "${TITLE}" >/dev/tty
    echo "${DESCRIPTION}" >/dev/tty
    echo "-" >/dev/tty
  fi
}

SEND_INFO() {
  URL=$(SQL_QUERY "SELECT value FROM variables
    WHERE key = 'discord_webhook_url_information';")
  TOKEN=$(SQL_QUERY "SELECT value FROM variables
    WHERE key = 'telegram_token';")
  CHAT_ID=$(SQL_QUERY "SELECT value FROM variables
    WHERE key = 'telegram_chatid';")
  DESCRIPTION="${1}"

  if [[ -z "${DESCRIPTION}" ]]; then
    DESCRIPTION="Default Information Message."
  fi

  TITLE="${2}"

  if [[ -z "${TITLE}" ]]; then
    TITLE=":blue_book: Information :blue_book:"
  fi

  DISCORD_WEBHOOK_COLOR="${5}"

  if [[ -z "${DISCORD_WEBHOOK_COLOR}" ]]; then
    DISCORD_WEBHOOK_COLOR=65535
  fi

  if [[ -n "${6}" ]]; then
    URL="${6}"
  fi

  SENT=0

  if [[ -n "${URL}" ]]; then
    SENT=1
    DISCORD_WEBHOOK_SEND "${URL}" "${DESCRIPTION}" "${TITLE}" "${3}" "${4}" "${DISCORD_WEBHOOK_COLOR}"
  fi

  if [[ -n "${TOKEN}" ]] && [[ -n "${CHAT_ID}" ]]; then
    SENT=1
    TELEGRAM_SEND "${TOKEN}" "${CHAT_ID}" "${TITLE}" "<pre>${DESCRIPTION}</pre>"
  fi

  if [[ "${SENT}" -eq 0 ]] || [[ "${DEBUG_OUTPUT}" -eq 1 ]]; then
    echo "${TITLE}" >/dev/tty
    echo "${DESCRIPTION}" >/dev/tty
    echo "-" >/dev/tty
  fi
}

SEND_SUCCESS() {
  URL=$(SQL_QUERY "SELECT value FROM variables
    WHERE key = 'discord_webhook_url_success';")
  TOKEN=$(SQL_QUERY "SELECT value FROM variables
    WHERE key = 'telegram_token';")
  CHAT_ID=$(SQL_QUERY "SELECT value FROM variables
    WHERE key = 'telegram_chatid';")
  DESCRIPTION="${1}"

  if [[ -z "${DESCRIPTION}" ]]; then
    DESCRIPTION="Default Success Message!"
  fi

  TITLE="${2}"

  if [[ -z "${TITLE}" ]]; then
    TITLE=":moneybag: Success :money_mouth:"
  fi

  DISCORD_WEBHOOK_COLOR="${5}"

  if [[ -z "${DISCORD_WEBHOOK_COLOR}" ]]; then
    DISCORD_WEBHOOK_COLOR=65535
  fi

  if [[ -n "${6}" ]]; then
    URL="${6}"
  fi

  SENT=0

  if [[ -n "${URL}" ]]; then
    SENT=1
    DISCORD_WEBHOOK_SEND "${URL}" "${DESCRIPTION}" "${TITLE}" "${3}" "${4}" "${DISCORD_WEBHOOK_COLOR}"
  fi

  if [[ -n "${TOKEN}" ]] && [[ -n "${CHAT_ID}" ]]; then
    SENT=1
    TELEGRAM_SEND "${TOKEN}" "${CHAT_ID}" "${TITLE}" "<pre>${DESCRIPTION}</pre>"
  fi

  if [[ "${SENT}" -eq 0 ]] || [[ "${DEBUG_OUTPUT}" -eq 1 ]]; then
    printf '%s\n%s\n-\n' "${TITLE}" "${DESCRIPTION}" >/dev/tty
  fi
}

SEND_EMAIL() {
  # Temp Files
  TOMAILFILE=/tmp/reward_email.txt
  # Compose Email Message
  printf 'To: %s\n' "${SENDTOEMAIL}" >$TOMAILFILE
  {
    printf 'From: %s\n' "${SENDTOEMAIL}"
    printf 'Subject: NRG-%s - %s \n' "${SHORTADDR}" "${1}"
    printf '\n'
    printf 'Market Price: %s %s\n' "${CURRENCY}" "${NRGMKTPRICE}"
  } >>$TOMAILFILE

  if [[ ${STAKERWD} == Y ]]; then
    {
      printf '%s\n' "$(stake_reward_info "${REWARDAMT}")"
      printf 'Block Number: %s\n' "${CHKBLOCK}"
      printf '%s\n' "$(new_balance_info "${ACCTBALANCE}")"
      printf 'Next Stake ETA: %s\n' "${TIME_TO_STAKE}"
    } >>$TOMAILFILE
  elif [[ ${MNRWD} == Y ]]; then
    {
      printf 'Masternode Collateral: %s NRG\n' "${MNCOLLATERAL}"
      printf '%s\n' "$(masternode_reward_info "${MNTOTALNRG}")"
      printf '%s\n' "${_MNREWARDS}"
    } >>$TOMAILFILE
  fi

  printf '\n' >>$TOMAILFILE
  # Send email
  log "${SHORTADDR}: Send email"
  ssmtp "${SENDTOEMAIL}" <$TOMAILFILE
  rm $TOMAILFILE
}

SEND_SMS() {
  # Temp Files
  TOSMSFILE=/tmp/reward_sms.txt
  # Compose SMS Message
  echo "To: ${SENDTOMOBILE}@${SENDTOGATEWAY}" >$TOSMSFILE
  echo "From: ${SENDTOEMAIL}" >>$TOSMSFILE
  echo "Subject: NRG-${SHORTADDR}" >>$TOSMSFILE
  echo "" >>$TOSMSFILE

  if [[ ${STAKERWD} == Y ]]; then
    echo "Rwd: ${REWARDAMT}, Price: ${CURRENCY} ${NRGMKTPRICE}" >>$TOSMSFILE
  elif [[ ${MNRWD} == Y ]]; then
    echo "Rwd: ${MNTOTALNRG}, Price: ${CURRENCY} ${NRGMKTPRICE}" >>$TOSMSFILE
  fi

  # Send email
  log "${SHORTADDR}: Send SMS"
  ssmtp "${SENDTOMOBILE}@${SENDTOGATEWAY}" <$TOSMSFILE
  rm $TOSMSFILE
}

PROCESS_MESSAGES() {
  local ERRORS=''
  local MESSAGE=''
  local NAME=${1}
  local MESSAGE_ERROR=${2}
  local MESSAGE_WARNING=${3}
  local MESSAGE_INFO=${4}
  local MESSAGE_SUCCESS=${5}
  local RECOVERED_MESSAGE_SUCCESS=${6}
  local RECOVERED_TITLE_SUCCESS=${7}
  local DISCORD_WEBHOOK_USERNAME=${8}
  local DISCORD_WEBHOOK_AVATAR=${9}

  # Get past events.
  UNIX_TIME=$(date -u +%s)
  MESSAGE_PAST=$(SQL_QUERY "SELECT start_time,last_ping_time,message FROM system_log WHERE name == '${NAME}'; ")
  START_TIME=$(echo "${MESSAGE_PAST}" | cut -d \| -f1)

  if [[ ! ${START_TIME} =~ ${RE} ]]; then
    START_TIME="${UNIX_TIME}"
  fi

  LAST_PING_TIME=$(echo "${MESSAGE_PAST}" | cut -d \| -f2)

  if [[ ! ${LAST_PING_TIME} =~ ${RE} ]]; then
    LAST_PING_TIME='0'
  fi

  MESSAGE_PAST=$(echo "${MESSAGE_PAST}" | cut -d \| -f3)
  SECONDS_SINCE_PING="$(printf '%s - %s\n' "${UNIX_TIME}" "${LAST_PING_TIME}" |
    bc -l)"

  # Send recovery message.
  if
    [[ -z "${MESSAGE_ERROR}" ]] &&
      [[ -z "${MESSAGE_WARNING}" ]] &&
      [[ -n "${MESSAGE_PAST}" ]] &&
      [[ -n "${RECOVERED_MESSAGE_SUCCESS}" ]]
  then
    ERRORS=$(SEND_SUCCESS "${RECOVERED_MESSAGE_SUCCESS}" ":wrench: ${RECOVERED_TITLE_SUCCESS} :wrench:")
    if [[ -n "${ERRORS}" ]]; then
      echo "ERROR: ${ERRORS}"
    else
      SQL_QUERY "DELETE FROM system_log WHERE name == '${NAME}'; "
    fi
  fi

  # Send message out.
  ERRORS=''
  MESSAGE=''
  if
    [[ -n "${MESSAGE_ERROR}" ]] && [[ "${SECONDS_SINCE_PING}" -gt 300 ]]
  then
    ERRORS=$(SEND_ERROR \
      "${MESSAGE_ERROR}" \
      "" \
      "${DISCORD_WEBHOOK_USERNAME}" \
      "${DISCORD_WEBHOOK_AVATAR}")
    MESSAGE="${MESSAGE_ERROR}"
  elif
    [[ -n "${MESSAGE_WARNING}" ]] && [[ "${SECONDS_SINCE_PING}" -gt 900 ]]
  then
    ERRORS=$(SEND_WARNING "${MESSAGE_WARNING}" "" "${DISCORD_WEBHOOK_USERNAME}" "${DISCORD_WEBHOOK_AVATAR}")
    MESSAGE="${MESSAGE_WARNING}"
  elif
    [[ -n "${MESSAGE_INFO}" ]] && [[ "${SECONDS_SINCE_PING}" -gt 3600 ]]
  then
    ERRORS=$(SEND_INFO "${MESSAGE_INFO}" "" "${DISCORD_WEBHOOK_USERNAME}" "${DISCORD_WEBHOOK_AVATAR}")
    MESSAGE="${MESSAGE_INFO}"
  elif [[ -n "${MESSAGE_SUCCESS}" ]]; then
    ERRORS=$(SEND_SUCCESS "${MESSAGE_SUCCESS}" "" "${DISCORD_WEBHOOK_USERNAME}" "${DISCORD_WEBHOOK_AVATAR}")
    MESSAGE="${MESSAGE_SUCCESS}"
  fi

  if [[ "${DEBUG_OUTPUT}" -eq 1 ]]; then
    echo "system_log name ${NAME}"
    echo "Last ping: ${SECONDS_SINCE_PING}"
    if [[ -n "${MESSAGE_ERROR}" ]]; then
      echo "Error: ${MESSAGE_ERROR}"
    fi
    if [[ -n "${MESSAGE_WARNING}" ]]; then
      echo "Warning: ${MESSAGE_WARNING}"
    fi
    if [[ -n "${MESSAGE_INFO}" ]]; then
      echo "Info: ${MESSAGE_INFO}"
    fi
    if [[ -n "${MESSAGE_SUCCESS}" ]]; then
      echo "Success: ${MESSAGE_SUCCESS}"
    fi
    if [[ -n "${MESSAGE}" ]]; then
      echo "Message: ${MESSAGE}"
    fi
    if [[ -n "${ERRORS}" ]]; then
      echo "Errors: ${ERRORS}"
    fi
    echo
  fi

  # Write to the database.
  if [[ -n "${ERRORS}" ]]; then
    printf '%s\n' "${ERRORS}" >/dev/tty
  elif [[ "${TEST_OUTPUT}" -eq 0 ]] && [[ -n "${MESSAGE}" ]]; then
    SQL_QUERY "REPLACE INTO system_log (start_time,last_ping_time,name,message)
      VALUES ('${START_TIME}','${UNIX_TIME}','${NAME}','${MESSAGE}');"
  fi
}

PROCESS_NODE_MESSAGES() {
  local ERRORS=''
  local MESSAGE=''
  local DATADIR=${1}
  local TYPE=${2}
  # 1=Error, 2=Warning, 3=Info, 4=Success, 5=Recovery
  local MESSAGE_TYPE=${3}
  local MESSAGE_TEXT=${4}
  local MESSAGE_TITLE=${5}
  local DISCORD_WEBHOOK_USERNAME=${6}
  local DISCORD_WEBHOOK_AVATAR=${7}

  # Get past events.
  UNIX_TIME=$(date -u +%s)
  MESSAGE_PAST=$(SQL_QUERY \
    "SELECT start_time,last_ping_time,message
    FROM node_log WHERE conf_loc == '${DATADIR}' AND type == '${TYPE}'; ")
  START_TIME=$(echo "${MESSAGE_PAST}" | head -n1 | cut -d \| -f1)

  if [[ ! ${START_TIME} =~ ${RE} ]]; then
    START_TIME="${UNIX_TIME}"
  fi

  LAST_PING_TIME=$(echo "${MESSAGE_PAST}" | head -n1 | cut -d \| -f2)

  if [[ ! ${LAST_PING_TIME} =~ ${RE} ]]; then
    LAST_PING_TIME='0'
  fi
  MESSAGE_PAST=$(echo "${MESSAGE_PAST}" | cut -d \| -f3)
  SECONDS_SINCE_PING="$(printf '%s - %s\n' "${UNIX_TIME}" "${LAST_PING_TIME}" |
    bc -l)"

  # Send message out.
  ERRORS=''
  MESSAGE=''
  # Error Message.
  if
    [[ "${MESSAGE_TYPE}" -eq 1 ]] && [[ "${SECONDS_SINCE_PING}" -gt 300 ]]
  then
    ERRORS=$(SEND_ERROR "${MESSAGE_TEXT}" "" "${DISCORD_WEBHOOK_USERNAME}" "${DISCORD_WEBHOOK_AVATAR}")
    MESSAGE="${MESSAGE_TEXT}"
  # Warning Message.
  elif
    [[ "${MESSAGE_TYPE}" -eq 2 ]] && [[ "${SECONDS_SINCE_PING}" -gt 900 ]]
  then
    ERRORS=$(SEND_WARNING "${MESSAGE_TEXT}" "" "${DISCORD_WEBHOOK_USERNAME}" "${DISCORD_WEBHOOK_AVATAR}")
    MESSAGE="${MESSAGE_TEXT}"
  # Information Message.
  elif
    [[ "${MESSAGE_TYPE}" -eq 3 ]] && [[ "${SECONDS_SINCE_PING}" -gt 3600 ]]
  then
    ERRORS=$(SEND_INFO "${MESSAGE_TEXT}" "" "${DISCORD_WEBHOOK_USERNAME}" "${DISCORD_WEBHOOK_AVATAR}")
    MESSAGE="${MESSAGE_TEXT}"
  # Success Message.
  elif
    [[ "${MESSAGE_TYPE}" -eq 4 ]] && [[ "${SECONDS_SINCE_PING}" -gt 7200 ]]
  then
    ERRORS=$(SEND_SUCCESS "${MESSAGE_TEXT}" "" "${DISCORD_WEBHOOK_USERNAME}" "${DISCORD_WEBHOOK_AVATAR}")
    MESSAGE="${MESSAGE_TEXT}"
  # Send recovery message.
  elif [[ "${MESSAGE_TYPE}" -eq 5 ]] && [[ -n "${MESSAGE_PAST}" ]]; then
    ERRORS=$(SEND_SUCCESS "${MESSAGE_TEXT}" ":wrench: ${MESSAGE_TITLE} :wrench:" "${DISCORD_WEBHOOK_USERNAME}" "${DISCORD_WEBHOOK_AVATAR}")
    if [[ -z "${ERRORS}" ]]; then
      SQL_QUERY "DELETE FROM node_log WHERE conf_loc == '${DATADIR}' AND type == '${TYPE}'; "
    fi
  fi

  if [[ "${DEBUG_OUTPUT}" -eq 1 ]]; then
    echo "node_log conf ${DATADIR} type ${TYPE}"
    echo "Last ping: ${SECONDS_SINCE_PING}"
    echo "Message Type: ${MESSAGE_TYPE}"
    echo "Message: ${MESSAGE_TEXT}"
    if [[ -n "${MESSAGE_TITLE}" ]]; then
      echo "Message Title: ${MESSAGE_TITLE}"
    fi
    if [[ -n "${ERRORS}" ]]; then
      echo "Errors: ${ERRORS}"
    fi
    echo
  fi

  # Write to the database.
  if [[ -n "${ERRORS}" ]]; then
    echo "Error: ${ERRORS}"
  elif [[ "${TEST_OUTPUT}" -eq 0 ]] && [[ -n "${MESSAGE}" ]]; then
    SQL_QUERY "REPLACE INTO node_log (
      start_time, last_ping_time, conf_loc, type, message
    ) VALUES (
      '${START_TIME}', '${UNIX_TIME}', '${DATADIR}', '${TYPE}', '${MESSAGE}'
    );"
  fi
}

GET_LATEST_LOGINS() {
  if [[ "${DEBUG_OUTPUT}" -eq 1 ]]; then
    echo 'Checking SSH logins'
  fi

  LAST_LOGIN_TIME_CHECK=$(SQL_QUERY "SELECT value FROM variables
    WHERE key == 'last_login_time_check' ")

  if [[ -z "${LAST_LOGIN_TIME_CHECK}" ]]; then
    LAST_LOGIN_TIME_CHECK=0
  fi

  UNIX_TIME=$(date -u +%s)

  while read -r DATE_1 DATE_2 DATE_3 LINE; do
    if [[ -z "${LINE}" ]]; then
      continue
    fi

    UNIX_TIME_LOG=$(date -u --date="${DATE_1} ${DATE_2} ${DATE_3}" +%s)

    if [[ "${LAST_LOGIN_TIME_CHECK}" -gt "${UNIX_TIME_LOG}" ]]; then
      continue
    fi

    LINE=$(echo "${LINE}" | sed 's/SHA[[:digit:]]\+.*$//')
    SSH_USER=$(echo "${LINE}" |
      grep -Pio 'for .*? from' |
      cut -d ' ' -f 2 |
      sed 's/for //' |
      sed 's/ from//')
    SSH_IP=$(echo "${LINE}" | grep -Pio 'from .*? port' | sed 's/from //' | sed 's/ port//')
    VERB='in'

    if [[ $(echo "${LINE}" | grep -ci ': Accepted ') -eq 0 ]]; then
      VERB='out'
    fi

    ERRORS=$(SEND_WARNING "${DATE_1} ${DATE_2} ${DATE_3} ${LINE}" ":unlock: User ${SSH_USER} logged ${VERB} at ${UNIX_TIME_LOG} from ${SSH_IP}")

    if [[ -n "${ERRORS}" ]]; then
      echo "ERROR: ${ERRORS}"
    elif [[ "${TEST_OUTPUT}" -eq 0 ]]; then
      SQL_QUERY "REPLACE INTO variables (key,value) VALUES ('last_login_time_check','${UNIX_TIME}');"
    fi
  done <<<"$(grep 'port' /var/log/auth.log | grep -iv 'CRON\|TTY\|preauth\|Invalid[[:space:]]user\|user[[:space:]]unknown\|major[[:space:]]versions[[:space:]]differ\|Failed[[:space:]]password\|authentication[[:space:]]failure\|refused[[:space:]]connect\|ignoring[[:space:]]max\|not[[:space:]]receive[[:space:]]identification\|[[:space:]]sudo\|[[:space:]]su\|Bad[[:space:]]protocol\|Disconnected[[:space:]]from[[:space:]]user\|disconnected[[:space:]]on[[:space:]]user\|Failed[[:space:]]none' | tail -1)"
}

CHECK_DISK() {
  NAME='disk_space'
  MESSAGE_ERROR=''
  MESSAGE_WARNING=''
  MESSAGE_INFO=''
  MESSAGE_SUCCESS=''
  FREEPSPACE_ALL=$(df -P . | tail -1 | awk '{print $4}')
  FREEPSPACE_BOOT=$(df -P /boot | tail -1 | awk '{print $4}')

  if
    [[ "${FREEPSPACE_ALL}" -lt "${LOW_HDD_ERROR_KB}" ]] ||
      [[ "${TEST_OUTPUT}" -eq 1 ]]
  then
    FREEPSPACE_ALL=$(echo "${FREEPSPACE_ALL} / 1024" | bc)
    MESSAGE_ERROR="${MESSAGE_ERROR} Less than ${LOW_HDD_ERROR_MB} MB of free space is left on the drive. ${FREEPSPACE_ALL} MB left."
  fi

  if
    [[ "${FREEPSPACE_BOOT}" -lt "${LOW_HDD_BOOT_ERROR_KB}" ]] ||
      [[ "${TEST_OUTPUT}" -eq 1 ]]
  then
    FREEPSPACE_BOOT=$(echo "${FREEPSPACE_BOOT} / 1024" | bc)
    MESSAGE_ERROR="${MESSAGE_ERROR} Less than ${LOW_HDD_BOOT_ERROR_MB} MB of free space is left in the boot folder. ${FREEPSPACE_BOOT} MB left."
  fi

  if [[ -z "${MESSAGE_ERROR}" ]]; then
    if
      [[ "${FREEPSPACE_ALL}" -lt "${LOW_HDD_WARN_KB}" ]] ||
        [[ "${TEST_OUTPUT}" -eq 1 ]]
    then
      FREEPSPACE_ALL=$(echo "${FREEPSPACE_ALL} / 1024" | bc)
      MESSAGE_WARNING="${MESSAGE_WARNING} Less than ${LOW_HDD_WARN_MB} MB of free space is left on the drive. ${FREEPSPACE_ALL} MB left."
    fi

    if
      [[ "${FREEPSPACE_BOOT}" -lt "${LOW_HDD_BOOT_WARN_KB}" ]] ||
        [[ "${TEST_OUTPUT}" -eq 1 ]]
    then
      FREEPSPACE_BOOT=$(echo "${FREEPSPACE_BOOT} / 1024" | bc)
      MESSAGE_WARNING="${MESSAGE_WARNING} Less than ${LOW_HDD_BOOT_WARN_MB} MB of free space is left in the boot folder. ${FREEPSPACE_BOOT} MB left."
    fi
  fi

  if [[ -n "${MESSAGE_ERROR}" ]]; then
    MESSAGE_ERROR=":floppy_disk: :fire: ${MESSAGE_ERROR} :fire: :floppy_disk:"
  fi
  if [[ -n "${MESSAGE_WARNING}" ]]; then
    MESSAGE_WARNING=":floppy_disk: ${MESSAGE_WARNING} :floppy_disk:"
  fi

  if [[ "${DEBUG_OUTPUT}" -eq 1 ]]; then
    echo "Freespace all: ${FREEPSPACE_ALL}"
    echo "Freespace boot: ${FREEPSPACE_BOOT}"
    echo
  fi

  RECOVERED_MESSAGE_SUCCESS="Hard drive has ${FREEPSPACE_ALL} MB Free; boot folder has ${FREEPSPACE_BOOT} MB Free."
  RECOVERED_TITLE_SUCCESS="Low diskspace issue has been resolved."
  PROCESS_MESSAGES "${NAME}" "${MESSAGE_ERROR}" "${MESSAGE_WARNING}" "${MESSAGE_INFO}" "${MESSAGE_SUCCESS}" "${RECOVERED_MESSAGE_SUCCESS}" "${RECOVERED_TITLE_SUCCESS}" "${DISCORD_WEBHOOK_USERNAME_DEFAULT}" "${DISCORD_WEBHOOK_AVATAR_DEFAULT}"
}

CHECK_CPU_LOAD() {
  NAME='cpu_usage'
  MESSAGE_ERROR=''
  MESSAGE_WARNING=''
  MESSAGE_INFO=''
  MESSAGE_SUCCESS=''
  LOAD=$(uptime |
    grep -oE 'load average: [0-9]+([.][0-9]+)?' |
    grep -oE '[0-9]+([.][0-9]+)?')
  CPU_COUNT=$(grep -c 'processor' /proc/cpuinfo)
  LOAD_PER_CPU="$(printf "%.3f\n" "$(bc -l <<<"${LOAD} / ${CPU_COUNT}")")"

  if
    [[ "$(echo "${LOAD_PER_CPU} >= ${CPU_LOAD_ERROR}" | bc -l)" -gt 0 ]] ||
      [[ "${TEST_OUTPUT}" -eq 1 ]]
  then
    MESSAGE_ERROR=" :desktop: :fire:  CPU LOAD is over ${CPU_LOAD_ERROR}: ${LOAD_PER_CPU} :fire: :desktop: "
  elif
    [[ "$(echo "${LOAD_PER_CPU} > ${CPU_LOAD_WARN}" | bc -l)" -gt 0 ]] ||
      [[ "${TEST_OUTPUT}" -eq 1 ]]
  then
    MESSAGE_WARNING=" :desktop: CPU LOAD is over ${CPU_LOAD_WARN}: ${LOAD_PER_CPU} :desktop: "
  fi

  if [[ "${DEBUG_OUTPUT}" -eq 1 ]]; then
    echo "Load: ${LOAD}"
    echo "CPU Count: ${CPU_COUNT}"
    echo "Load per CPU: ${LOAD_PER_CPU}"
    echo
  fi

  RECOVERED_MESSAGE_SUCCESS="Load per CPU is ${LOAD_PER_CPU}."
  RECOVERED_TITLE_SUCCESS="CPU Load is back to normal."
  PROCESS_MESSAGES "${NAME}" "${MESSAGE_ERROR}" "${MESSAGE_WARNING}" "${MESSAGE_INFO}" "${MESSAGE_SUCCESS}" "${RECOVERED_MESSAGE_SUCCESS}" "${RECOVERED_TITLE_SUCCESS}" "${DISCORD_WEBHOOK_USERNAME_DEFAULT}" "${DISCORD_WEBHOOK_AVATAR_DEFAULT}"
}

CHECK_SWAP() {
  NAME='swap_free'
  MESSAGE_ERROR=''
  MESSAGE_WARNING=''
  MESSAGE_INFO=''
  MESSAGE_SUCCESS=''
  SWAP_FREE_MB=$(free -wm | grep -i 'Swap:' | awk '{print $4}')

  if
    [[ $(echo "${SWAP_FREE_MB} < ${LOW_SWAP_ERROR_MB}" | bc) -gt 0 ]] ||
      [[ "${TEST_OUTPUT}" -eq 1 ]]
  then
    MESSAGE_ERROR=":desktop: :fire: Swap is under ${LOW_SWAP_ERROR_MB} MB: ${SWAP_FREE_MB} MB :fire: :desktop: "
  fi

  if
    ([[ $(echo "${SWAP_FREE_MB} >= ${LOW_SWAP_ERROR_MB}" | bc) -gt 0 ]] &&
      [[ $(echo "${SWAP_FREE_MB} < ${LOW_SWAP_WARN_MB}" | bc) -gt 0 ]]) ||
      [[ "${TEST_OUTPUT}" -eq 1 ]]
  then
    MESSAGE_WARNING=":desktop: Swap is under ${LOW_SWAP_WARN_MB} MB: ${SWAP_FREE_MB} MB :desktop: "
  fi

  if [[ "${DEBUG_OUTPUT}" -eq 1 ]]; then
    echo "Swap Free MB: ${SWAP_FREE_MB}"
    echo
  fi

  RECOVERED_MESSAGE_SUCCESS="Free Swap space is ${SWAP_FREE_MB} MB."
  RECOVERED_TITLE_SUCCESS="Free sawp space is back to normal."
  PROCESS_MESSAGES "${NAME}" "${MESSAGE_ERROR}" "${MESSAGE_WARNING}" "${MESSAGE_INFO}" "${MESSAGE_SUCCESS}" "${RECOVERED_MESSAGE_SUCCESS}" "${RECOVERED_TITLE_SUCCESS}" "${DISCORD_WEBHOOK_USERNAME_DEFAULT}" "${DISCORD_WEBHOOK_AVATAR_DEFAULT}"
}

CHECK_RAM() {
  NAME='ram_free'
  MESSAGE_ERROR=''
  MESSAGE_WARNING=''
  MESSAGE_INFO=''
  MESSAGE_SUCCESS=''

  MEM_TOTAL=$(sudo cat /proc/meminfo |
    grep -i 'MemTotal:' |
    awk '{print $2}' |
    head -n 1)
  MEM_AVAILABLE=$(sudo cat /proc/meminfo |
    grep -i 'MemAvailable:\|MemFree:' |
    awk '{print $2}' |
    tail -n 1)
  MEM_AVAILABLE_MB=$(echo "${MEM_AVAILABLE} / 1024" | bc)
  PERCENT_FREE=$(echo "${MEM_AVAILABLE} / ${MEM_TOTAL}" | bc -l)
  PERCENT_FREE=$(echo "${PERCENT_FREE} * 100" | bc -l)

  if
    [[ "${TEST_OUTPUT}" -eq 1 ]] ||
      ([[ $(echo "${PERCENT_FREE} < ${LOW_MEM_ERROR_PERCENT}" | bc -l) -eq 1 ]] &&
        [[ $(echo "${MEM_AVAILABLE_MB} < ${LOW_MEM_ERROR_MB}" | bc) -gt 0 ]])
  then
    MESSAGE_ERROR=":desktop: :fire: Free RAM is under ${LOW_MEM_ERROR_MB} MB: ${MEM_AVAILABLE_MB} MB Percent Free: ${PERCENT_FREE}% :fire: :desktop: "
  elif
    [[ "${TEST_OUTPUT}" -eq 1 ]] ||
      ([[ $(echo "${PERCENT_FREE} < ${LOW_MEM_WARN_PERCENT}" | bc -l) -eq 1 ]] &&
        [[ $(echo "${MEM_AVAILABLE_MB} < ${LOW_MEM_WARN_MB}" | bc) -gt 0 ]])
  then
    MESSAGE_WARNING=":desktop: Free RAM is under ${LOW_MEM_WARN_MB} MB: ${MEM_AVAILABLE_MB} MB. Percent Free: ${PERCENT_FREE}% :desktop: "
  fi

  if [[ "${DEBUG_OUTPUT}" -eq 1 ]]; then
    echo "Ram Free MB: ${MEM_AVAILABLE_MB}"
    echo "Percent Free: ${PERCENT_FREE}"
    echo
  fi

  RECOVERED_MESSAGE_SUCCESS="Free RAM is now at ${MEM_AVAILABLE_MB} MB."
  RECOVERED_TITLE_SUCCESS="Free RAM is back to normal."
  PROCESS_MESSAGES "${NAME}" "${MESSAGE_ERROR}" "${MESSAGE_WARNING}" "${MESSAGE_INFO}" "${MESSAGE_SUCCESS}" "${RECOVERED_MESSAGE_SUCCESS}" "${RECOVERED_TITLE_SUCCESS}" "${DISCORD_WEBHOOK_USERNAME_DEFAULT}" "${DISCORD_WEBHOOK_AVATAR_DEFAULT}"
}

CHECK_OOM_KILLS() {
  LAST_OOM_TIME_CHECK=$(SQL_QUERY "SELECT value FROM variables WHERE key == 'last_oom_time_check' ")

  if [[ -z "${LAST_OOM_TIME_CHECK}" ]]; then
    LAST_OOM_TIME_CHECK=0
  fi

  UNIX_TIME=$(date -u +%s)

  while read -r DATE_1 DATE_2 DATE_3 LINE; do
    if [[ -z "${LINE}" ]]; then
      continue
    fi

    UNIX_TIME_LOG=$(date -u --date="${DATE_1} ${DATE_2} ${DATE_3}" +%s)

    if [[ "${LAST_OOM_TIME_CHECK}" -gt "${UNIX_TIME_LOG}" ]]; then
      continue
    fi

    ERRORS=$(SEND_ERROR \
      "${DATE_1} ${DATE_2} ${DATE_3} ${LINE}" \
      " :skull_crossbones: :fire: Process killed due to low memory :fire: :skull_crossbones: ")

    if [[ -n "${ERRORS}" ]]; then
      echo "ERROR: ${ERRORS}"
    elif [[ "${TEST_OUTPUT}" -eq 0 ]]; then
      SQL_QUERY "REPLACE INTO variables (key,value) VALUES ('last_oom_time_check','${UNIX_TIME}');"
    fi
  done <<<"$(grep -i 'out of memory' /var/log/kern.log)"
}

CHECK_CLOCK() {
  # Get the last time this check was ran.
  CHECK_CLOCK_LAST_RUN=$(SQL_QUERY "SELECT value FROM variables WHERE key == 'system_clock_last_run' ")

  if [[ -z "${CHECK_CLOCK_LAST_RUN}" ]]; then
    CHECK_CLOCK_LAST_RUN=0
  fi

  UNIX_TIME=$(date -u +%s)
  # Only run once every 30 min.
  CHECK_CLOCK_LAST_RUN=$((CHECK_CLOCK_LAST_RUN + 1800))

  if [[ "${CHECK_CLOCK_LAST_RUN}" -gt "${UNIX_TIME}" ]]; then
    if [[ "${DEBUG_OUTPUT}" -eq 1 ]]; then
      echo "System clock check was already ran. ${CHECK_CLOCK_LAST_RUN} -gt ${UNIX_TIME}"
      echo
    fi
    return
  fi

  NAME='system_clock_check'
  MESSAGE_ERROR=''
  MESSAGE_WARNING=''
  MESSAGE_INFO=''
  MESSAGE_SUCCESS=''

  if [[ "${DEBUG_OUTPUT}" -eq 1 ]]; then
    echo 'Checking system clock'
  fi

  TIME_OFFSET=$(ntpdate -q pool.ntp.org |
    tail -n 1 |
    grep -o 'offset.*' |
    awk '{print $2 }' |
    tr -d '-')

  if
    [[ $(echo "${TIME_OFFSET} > 1" | bc) -gt 0 ]] ||
      [[ "${TEST_OUTPUT}" -eq 1 ]]
  then
    MESSAGE_ERROR=":watch: :fire: System Clock is off by over 1 second. Offset: ${TIME_OFFSET} seconds :fire: :watch: "
  fi

  if
    [[ $(echo "${TIME_OFFSET} > 0.1" | bc) -gt 0 ]] ||
      [[ "${TEST_OUTPUT}" -eq 1 ]]
  then
    MESSAGE_WARNING=":watch: System Clock is off by over 0.1 seconds. Offset: ${TIME_OFFSET} seconds :watch: "
  fi

  if [[ "${DEBUG_OUTPUT}" -eq 1 ]]; then
    echo "System clock offset: ${TIME_OFFSET}"
    echo
  fi

  RECOVERED_MESSAGE_SUCCESS="System clock is now at ${TIME_OFFSET} seconds."
  RECOVERED_TITLE_SUCCESS="System clock is back to normal."
  PROCESS_MESSAGES \
    "${NAME}" \
    "${MESSAGE_ERROR}" \
    "${MESSAGE_WARNING}" \
    "${MESSAGE_INFO}" \
    "${MESSAGE_SUCCESS}" \
    "${RECOVERED_MESSAGE_SUCCESS}" \
    "${RECOVERED_TITLE_SUCCESS}" \
    "${DISCORD_WEBHOOK_USERNAME_DEFAULT}" \
    "${DISCORD_WEBHOOK_AVATAR_DEFAULT}"
  SQL_QUERY "REPLACE INTO variables (key, value)
    VALUES ('system_clock_last_run', '${UNIX_TIME}');"
}

CHECK_DEBSUMS() {
  # Get the last time this check was ran.
  DEBSUMS_LAST_RUN=$(SQL_QUERY "SELECT value FROM variables WHERE key == 'debsums_last_run' ")

  if [[ -z "${DEBSUMS_LAST_RUN}" ]]; then
    DEBSUMS_LAST_RUN=0
  fi

  UNIX_TIME=$(date -u +%s)
  # Only run once every 2 hours.
  DEBSUMS_LAST_RUN=$((DEBSUMS_LAST_RUN + 7200))

  if [[ "${DEBSUMS_LAST_RUN}" -gt "${UNIX_TIME}" ]]; then
    if [[ "${DEBUG_OUTPUT}" -eq 1 ]]; then
      echo "Debsums was already ran. ${DEBSUMS_LAST_RUN} -gt ${UNIX_TIME}"
      echo
    fi
    return
  fi

  if [[ "${DEBUG_OUTPUT}" -eq 1 ]]; then
    echo 'Running debsums'
  fi

  NAME='debsums_check'
  MESSAGE_ERROR=''
  MESSAGE_WARNING=''
  MESSAGE_INFO=''
  MESSAGE_SUCCESS=''
  RECOVERED_MESSAGE_SUCCESS="debsums doesn't show any errors."
  RECOVERED_TITLE_SUCCESS="debsums is good."
  DEBSUMS_OUTPUT=$(sudo debsums -c 2>&1)

  # Debug Output
  if [[ "${DEBUG_OUTPUT}" -eq 1 ]]; then
    echo "Timing: ${DEBSUMS_LAST_RUN} -gt ${UNIX_TIME}"
    echo "Debsums Output: ${DEBSUMS_OUTPUT}"
    echo
  fi

  if [[ -n "${DEBSUMS_OUTPUT}" ]]; then
    BROKEN_PACKAGES=$(echo "${DEBSUMS_OUTPUT}" | grep -P -o '/.*?\s' | xargs dpkg -S | cut -d : -f 1)
    OUTPUT=$(echo "${BROKEN_PACKAGES}" | xargs apt-get install --reinstall)
    DEBSUMS_OUTPUT=$(sudo debsums -c 2>&1)

    if [[ -n "${DEBSUMS_OUTPUT}" ]]; then
      MESSAGE_ERROR="There are still issues with the 'debsums -c' command:
${DEBSUMS_OUTPUT}"
    else
      MESSAGE_WARNING="The following packages were reinstalled:
${BROKEN_PACKAGES}"
    fi

    # Debug Output
    if [[ "${DEBUG_OUTPUT}" -eq 1 ]]; then
      echo "NEW Debsums Output: ${DEBSUMS_OUTPUT}"
      echo "Broken Packages: ${BROKEN_PACKAGES}"
      echo "Reinstall Output: ${OUTPUT}"
      echo
    fi
  fi

  PROCESS_MESSAGES \
    "${NAME}" \
    "${MESSAGE_ERROR}" \
    "${MESSAGE_WARNING}" \
    "${MESSAGE_INFO}" \
    "${MESSAGE_SUCCESS}" \
    "${RECOVERED_MESSAGE_SUCCESS}" \
    "${RECOVERED_TITLE_SUCCESS}" \
    "${DISCORD_WEBHOOK_USERNAME_DEFAULT}" \
    "${DISCORD_WEBHOOK_AVATAR_DEFAULT}"
  SQL_QUERY "REPLACE INTO variables (key, value)
    VALUES ('debsums_last_run', '${UNIX_TIME}');"
}

CHECK_RKHUNTER() {
  # Get the last time this check was ran.
  RKHUNTER_LAST_RUN=$(SQL_QUERY "SELECT value FROM variables WHERE key == 'rkhunter_last_run' ")

  if [[ -z "${RKHUNTER_LAST_RUN}" ]]; then
    RKHUNTER_LAST_RUN=0
  fi

  UNIX_TIME=$(date -u +%s)
  # Only run once every 2 hours.
  RKHUNTER_LAST_RUN=$((RKHUNTER_LAST_RUN + 7200))

  if [[ "${RKHUNTER_LAST_RUN}" -gt "${UNIX_TIME}" ]]; then
    if [[ "${DEBUG_OUTPUT}" -eq 1 ]]; then
      echo "RK Hunter was already ran. ${RKHUNTER_LAST_RUN} -gt ${UNIX_TIME}"
      echo
    fi
    return
  fi

  if [[ "${DEBUG_OUTPUT}" -eq 1 ]]; then
    echo 'Running rkhunter'
  fi

  sudo rkhunter --propupd >/dev/null

  if
    [[ "${RKHUNTER_LAST_RUN}" -eq 0 ]] &&
      [[ "$(sudo rkhunter -c --enable system_configs_ssh --rwo |
        grep -ic root)" -gt 0 ]]
  then
    echo 'RK Hunter adjusted for root login.'
    echo 'ALLOW_SSH_ROOT_USER=yes' | sudo tee -a /etc/rkhunter.conf >/dev/null
  fi

  sudo rkhunter -C >/dev/null
  NAME='rkhunter_check'
  MESSAGE_ERROR=''
  MESSAGE_WARNING=''
  MESSAGE_INFO=''
  MESSAGE_SUCCESS=''
  RECOVERED_MESSAGE_SUCCESS="rkhunter doesn't show any errors."
  RECOVERED_TITLE_SUCCESS="rkhunter is good."
  RKHUNTER_OUTPUT=$(sudo rkhunter -c --rwo 2>&1)
  # Debug Output

  if [[ "${DEBUG_OUTPUT}" -eq 1 ]]; then
    echo "Timing: ${RKHUNTER_LAST_RUN} -gt ${UNIX_TIME}"
    echo "RK Hunter Output: ${RKHUNTER_OUTPUT}"
    echo
  fi

  if [[ -n "${RKHUNTER_OUTPUT}" ]]; then
    MESSAGE_ERROR="There are issues with the 'rkhunter -c --rwo' command:
${RKHUNTER_OUTPUT}"
  fi

  PROCESS_MESSAGES \
    "${NAME}" \
    "${MESSAGE_ERROR}" \
    "${MESSAGE_WARNING}" \
    "${MESSAGE_INFO}" \
    "${MESSAGE_SUCCESS}" \
    "${RECOVERED_MESSAGE_SUCCESS}" \
    "${RECOVERED_TITLE_SUCCESS}" \
    "${DISCORD_WEBHOOK_USERNAME_DEFAULT}" \
    "${DISCORD_WEBHOOK_AVATAR_DEFAULT}"
  SQL_QUERY "REPLACE INTO variables (key, value)
    VALUES ('rkhunter_last_run','${UNIX_TIME}');"
}

REPORT_INFO_ABOUT_NODE() {
  USRNAME=${1}
  DAEMON_BIN=${2}
  DATADIR=${3}
  MASTERNODE=${4}
  MNINFO=${5}
  GETBALANCE=${6}
  GETTOTALBALANCE=${7}
  STAKING=${8}
  GETCONNECTIONCOUNT=${9}
  GETBLOCKCOUNT=${10}
  UPTIME=${11}
  UPTIME_MONITOR=${12}
  DAEMON_PID=${13}
  NETWORKHASHPS=${14}
  MNWIN=${15}
  VERSION=${16}

  if [[ -z "${USRNAME}" ]]; then
    return
  fi

  if [[ ! ${MASTERNODE} =~ ${RE} ]]; then
    return
  fi

  DISCORD_WEBHOOK_AVATAR=''
  DISCORD_WEBHOOK_USERNAME=''
  EXTRA_INFO=$(echo "${DAEMON_BIN_LUT}" | grep -E "^${DAEMON_BIN} ")

  if [[ -n "${EXTRA_INFO}" ]]; then
    DISCORD_WEBHOOK_AVATAR=$(echo "${EXTRA_INFO}" | cut -d ' ' -f2)
    DISCORD_WEBHOOK_USERNAME=$(echo "${EXTRA_INFO}" | cut -d ' ' -f3-)
  fi

  MIN_STAKE=0
  STAKE_REWARD=0
  MASTERNODE_REWARD=0
  MN_REWARD_FACTOR=0
  NET_HASH_FACTOR=0
  TICKER_NAME='NRG'
  STAKE_REWARD_UPPER=0
  BLOCKTIME_SECONDS=60
  UPTIME_HUMAN=$(DISPLAYTIME "${UPTIME}")
  EXTRA_INFO=$(echo "${DAEMON_BALANCE_LUT}" | grep -E "^${DAEMON_BIN} ")

  if [[ -n "${EXTRA_INFO}" ]]; then
    MIN_STAKE=$(echo "${EXTRA_INFO}" | cut -d ' ' -f2)
    STAKE_REWARD=$(echo "${EXTRA_INFO}" | cut -d ' ' -f3)
    MN_REWARD_FACTOR=$(echo "${EXTRA_INFO}" | cut -d ' ' -f4)
    NET_HASH_FACTOR=$(echo "${EXTRA_INFO}" | cut -d ' ' -f7)
    TICKER_NAME=$(echo "${EXTRA_INFO}" | cut -d ' ' -f8)
    BLOCKTIME_SECONDS=$(echo "${EXTRA_INFO}" | cut -d ' ' -f9)
    STAKE_REWARD_UPPER=$(echo "${STAKE_REWARD} + 0.3" | bc -l)
  fi

  # Report on connection count.
  if [[ ${GETCONNECTIONCOUNT} =~ ${RE} ]]; then
    if [[ "${GETCONNECTIONCOUNT}" -lt 2 ]]; then
      PROCESS_NODE_MESSAGES "${mnShortAddress}" "connection_count" "1" "__${USRNAME} ${DAEMON_BIN}__
  Connection Count (${GETCONNECTIONCOUNT}) is very low!" "" "${DISCORD_WEBHOOK_USERNAME}" "${DISCORD_WEBHOOK_AVATAR}"
    elif [[ "${GETCONNECTIONCOUNT}" -lt 8 ]]; then
      PROCESS_NODE_MESSAGES "${mnShortAddress}" "connection_count" "2" "__${USRNAME} ${DAEMON_BIN}__
  Connection Count (${GETCONNECTIONCOUNT}) is low!" "" "${DISCORD_WEBHOOK_USERNAME}" "${DISCORD_WEBHOOK_AVATAR}"
    else
      PROCESS_NODE_MESSAGES "${mnShortAddress}" "connection_count" "5" "__${USRNAME} ${DAEMON_BIN}__
  Connection count has been restored (${GETCONNECTIONCOUNT})" "Connection Count Normal" "${DISCORD_WEBHOOK_USERNAME}" "${DISCORD_WEBHOOK_AVATAR}"
    fi
  fi

  # Get last checked block from database
  LASTCHKBLOCK=$(SQL_QUERY "SELECT value FROM variables
    WHERE key = 'last_block_checked';")

  # Get list of accounts from core node
  if [[ -z ${LISTACCOUNTS} ]]; then
    LISTACCOUNTS=$(${COMMAND} "personal.listAccounts" 2>/dev/null | jq -r '.[]')
  fi

  # save miner in array
  CHKBLOCK=${LASTCHKBLOCK}

  while [[ $(echo "$CHKBLOCK < $CURRENTBLKNUM" | bc -l) -eq 1 ]]; do
    MINER[${CHKBLOCK}]=$(${COMMAND} "nrg.getBlock($CHKBLOCK).miner" 2>/dev/null |
      jq -r '.' |
      tr '[:upper:]' '[:lower:]')
    ((CHKBLOCK++))
  done

  # Get total network difficulty
  NDCHKBLOCK=${LASTCHKBLOCK}

  while [[ $(echo "$NDCHKBLOCK < $CURRENTBLKNUM" | bc -l) -eq 1 ]]; do
    DIFFICULTY=$(${COMMAND} "nrg.getBlock($NDCHKBLOCK).difficulty" 2>/dev/null)
    SQL_QUERY "INSERT INTO net_difficulty (blockNum, difficulty)
      VALUES ('${NDCHKBLOCK}', '${DIFFICULTY}');"
    ((NDCHKBLOCK++))
  done

  # Keep last 120 rows
  SQL_QUERY "DELETE FROM net_difficulty WHERE blockNum NOT IN (
    SELECT blockNum FROM net_difficulty ORDER BY blockNum DESC LIMIT 120
  );"
  # Set parameters
  GETTOTALBALANCE=0
  GETBALANCE=0
  ACCTBALANCE=0
  NRGMKTPRICE=''
  STAKING=${STAKING:-0}
  MASTERNODE=0
  NETWORKDIFF=0

  # Loop through all the addresses
  for ADDR in ${LISTACCOUNTS}; do
    # Reset parameter
    STARTMNBLK=''
    ENDMNBLK=''
    REWARDTIME=''
    # Change address to lower case
    ADDR=$(printf '%s' "${ADDR}" | tr '[:upper:]' '[:lower:]')
    SHORTADDR="${ADDR:2:6}"
    # Start from last checked block for ADDR
    CHKBLOCK=${LASTCHKBLOCK}
    # Get total staking account balance
    ACCTBALANCE=$($COMMAND "web3.fromWei(nrg.getBalance('$ADDR'), 'energi')" \
      2>/dev/null)
    GETBALANCE=$(printf '%s\n' "$GETBALANCE + $ACCTBALANCE" | bc -l)

    # Check if ADDR is a masternode
    if [[ ${MASTERNODE} -ne 1 ]]; then
      MNCOLLATERAL=$($COMMAND \
        "web3.fromWei(masternode.masternodeInfo('$ADDR').collateral, 'energi')" \
        2>/dev/null |
        jq -r '.')

      if [[ ${MNCOLLATERAL} -eq 0 ]]; then
        # Zero collatoral indicates not a masternode (Disabled)
        MASTERNODE=0
        MNINFO=0
        mnShortAddress=''
        isActiveMn="false"
        isAliveMn="false"
      else
        # ADDR is a masternode
        MASTERNODE=1
        # Assume NOT Active (inactive)
        MNINFO=0
        # Set for reporting
        mnShortAddress=${SHORTADDR}
        isActiveMn=$(${COMMAND} "masternode.masternodeInfo('$ADDR').isActive" \
          2>/dev/null |
          jq '.')

        if [[ "${isActiveMn}" == true ]]; then
          # Not Alive (Offline)
          MNINFO=1
          isAliveMn=$(${COMMAND} "masternode.masternodeInfo('$ADDR').isAlive" \
            2>/dev/null |
            jq '.')

          if [[ "${isAliveMn}" == true ]]; then
            # Masternode Alive and Active (Alive)
            MNINFO=2
          fi
        fi
      fi
    fi

    # For every ADDR check every blocks
    while [[ $(printf '%s\n' "$CHKBLOCK < $CURRENTBLKNUM" | bc -l) -eq 1 ]]; do
      BLOCKMINER=${MINER[${CHKBLOCK}]}

      # Update database if stake received
      if [[ ${ADDR} == "${BLOCKMINER}" ]]; then
        STAKERWD=Y
        REWARDTIME=$(${COMMAND} "nrg.getBlock($CHKBLOCK).timestamp" 2>/dev/null)
        market_price "${REWARDTIME}"
        # No way to determine at the time. Assume default
        REWARDAMT=2.28
        SQL_QUERY "INSERT INTO stake_rewards (
          stakeAddress, rewardTime, blockNum, Reward, balance, nrgPrice
        ) VALUES (
          '${ADDR}',
          '${REWARDTIME}',
          '${CHKBLOCK}',
          '${REWARDAMT}',
          '${ACCTBALANCE}',
          '${NRGMKTPRICE}'
        );"
        log "${SHORTADDR}: *** Stake received ***"

        if [[ ${NETWORKDIFF} -eq 0 ]]; then
          NETWORKDIFF=$(SQL_QUERY "SELECT AVG(difficulty) FROM net_difficulty;")
        fi

        # Coeeficient factor
        k=1
        #COEFF=1.5
        COEFF=0.1
        BLOCKTIME_SECONDS=60
        COOLDOWNTIME=3600
        # Get average staking times for masternode and staking rewards.
        COINS_STAKED_TOTAL_NETWORK=$(printf '%s\n' "${k} * ${NETWORKDIFF}" |
          bc -l)
        SEC_TO_AVG_STAKE_PER_BAL=$(printf '%s / %s * %s * %s\n' \
          "${COINS_STAKED_TOTAL_NETWORK}" \
          "${ACCTBALANCE}" \
          "${BLOCKTIME_SECONDS}" \
          "${COEFF}" | bc -l | sed "${REMOVE_TRALING_DECIMAL_ZEROS_PATTERN}")

        # Max of COOLDOWNTIME and SEC_TO_AVG_STAKE_PER_BAL

        if
          [[ $(printf '%s\n' "${COOLDOWNTIME} > ${SEC_TO_AVG_STAKE_PER_BAL}" |
            bc -l) -gt 0 ]]
        then
          SEC_TO_AVG_STAKE=${COOLDOWNTIME}
        else
          SEC_TO_AVG_STAKE=${SEC_TO_AVG_STAKE_PER_BAL}
        fi

        TIME_TO_STAKE=$(DISPLAYTIME "${SEC_TO_AVG_STAKE}")

        # Debug Output
        if [[ "${DEBUG_OUTPUT}" -eq 1 ]]; then
          printf '%s\n%s\n%s\n' \
            "Staking Balance: ${ACCTBALANCE}" \
            "Avg Difficulty: ${NETWORKDIFF}" \
            "Next Stake ETA: ${TIME_TO_STAKE}"
        fi

        #Network Diff: ${NETWORKDIFF}
        # Create payload for stake reward
        _PAYLOAD="$(printf '%s\n%s\n%s\n%s\n%s\n%s' \
          "__Account: ${SHORTADDR}__" \
          "Market Price: ${CURRENCY} ${NRGMKTPRICE}" \
          "$(stake_reward_info "${REWARDAMT}")" \
          "$(new_balance_info "${ACCTBALANCE}")" \
          "Block Number: ${CHKBLOCK}" \
          "Next Stake ETA: ${TIME_TO_STAKE}")"
        # Post message
        PROCESS_NODE_MESSAGES \
          "${SHORTADDR}" \
          "stake_reward" \
          "4" \
          "${_PAYLOAD}" \
          "" \
          "${DISCORD_WEBHOOK_USERNAME}" \
          "${DISCORD_WEBHOOK_AVATAR}"

        # Send EMAIL / SMS if set in nodemon.conf
        if [[ "${SENDEMAIL}" = "Y" ]]; then
          SEND_EMAIL "Stake received"
        fi

        if [[ "${SENDSMS}" = "Y" ]]; then
          SEND_SMS "Stake received"
        fi
      fi

      # If Address is a masternode
      if [[ "${isAliveMn}" == true ]] && [[ -z ${ENDMNBLK} ]]; then
        MNCHKDONE=$(SQL_QUERY \
          "SELECT mnBlocksReceived FROM mn_blocks WHERE mnAddress = '${ADDR}';")

        if [[ ${MNCHKDONE} == N ]]; then
          MNTOTALNRG=$(SQL_QUERY \
            "SELECT mnTotalReward FROM mn_blocks WHERE mnAddress = '${ADDR}';")
          STARTMNBLK=$(SQL_QUERY \
            "SELECT startMnBlk FROM mn_blocks WHERE mnAddress = '${ADDR}';")
          ENDMNBLK=''
        fi

        # Call txlistinternal API to get internal transactions
        TXLSTINT=$(curl \
          -H "accept: application/json" \
          -s "${NRGAPI}?module=account&action=txlistinternal&address=${ADDR}&startblock=${CHKBLOCK}&endblock=${CHKBLOCK}")
        if [[ $(echo "$TXLSTINT" | jq -r '.message') == OK ]]; then
          if [[ -z $STARTMNBLK ]]; then
            STARTMNBLK=$CHKBLOCK
            MNRWD=Y
          fi

          market_price
          # Add rewards for block
          BLOCKSUMWEI=$(printf '%.0f' \
            "$(printf '%s' "${TXLSTINT}" |
              jq -r '.result | map(.value | tonumber) | add ')")
          BLOCKSUMNRG=$(printf ' %s / 1000000000000000000\n' "${BLOCKSUMWEI}" |
            bc -l |
            sed "${REMOVE_TRALING_DECIMAL_ZEROS_PATTERN}")
          # Masternode reward based on collateral
          MASTERNODE_REWARD=$(
            printf '%s * %s / 1000\n' "${MN_REWARD_FACTOR}" "${MNCOLLATERAL}" |
              bc -l |
              sed "${REMOVE_TRALING_DECIMAL_ZEROS_PATTERN}"
          )

          # Time of block generation
          if [[ -z ${REWARDTIME} ]]; then
            REWARDTIME=$(${COMMAND} \
              "nrg.getBlock($CHKBLOCK).timestamp" 2>/dev/null)
          fi

          # Update database
          SQL_QUERY "INSERT INTO mn_rewards (
            mnAddress, rewardTime, blockNum, Reward, balance, nrgPrice
          ) VALUES (
            '${ADDR}',
            '${REWARDTIME}',
            '${CHKBLOCK}',
            '${BLOCKSUMNRG}',
            '${MNCOLLATERAL}',
            '${NRGMKTPRICE}'
            );"
          MNTOTALNRG=$(printf ' %s + %s \n' "${MNTOTALNRG}" "${BLOCKSUMNRG}" |
            bc -l |
            sed "${REMOVE_TRALING_DECIMAL_ZEROS_PATTERN}")
          SQL_QUERY "REPLACE INTO mn_blocks (
            mnAddress, mnBlocksReceived, startMnBlk, endMnBlk, mnTotalReward
          ) VALUES ('${ADDR}', 'N', '${STARTMNBLK}', '0', '${MNTOTALNRG}');"
        elif
          [[ -n $STARTMNBLK ]] &&
            [[ -z ${ENDMNBLK} ]] &&
            [[ $(printf '%s' "${TXLSTINT}" |
              jq '.message' |
              awk '{print $2}') == internal ]]
        then
          # All consecutive masternode payout blocks were found
          ENDMNBLK=$CHKBLOCK

          if [[ -n $MNTOTALNRG ]]; then
            SQL_QUERY "REPLACE INTO mn_blocks (
                mnAddress, mnBlocksReceived, startMnBlk, endMnBlk, mnTotalReward
              ) VALUES (
                '${ADDR}','Y', '${STARTMNBLK}', '${ENDMNBLK}', '${MNTOTALNRG}'
              );"
            log "${SHORTADDR}: *** Mn Reward received ***"
            market_price
            _MNREWARDS=$(SQL_REPORT \
              "SELECT blockNum,Reward FROM mn_rewards
              WHERE blockNum BETWEEN ${STARTMNBLK} and ${ENDMNBLK};")
            SEC_TO_MNREWARD=$(printf '(%s) / 10000000000000000000000 * 60 \n' \
              "$(printf '%.0f' "$(
                ${COMMAND} "masternode.stats().activeCollateral" 2>/dev/null
              )")" | bc -l | sed "${REMOVE_TRALING_DECIMAL_ZEROS_PATTERN}")
            _PAYLOAD="$(printf '%s\n%s\n%s\n%s\n%s\n%s\n\n%s' \
              "__Account: ${SHORTADDR}__" \
              "Market Price: ${CURRENCY} ${NRGMKTPRICE}" \
              "$(masternode_reward_info "${MNTOTALNRG}")" \
              "$(new_balance_info \
                "$(total_node_balance "${GETBALANCE}" "${MNCOLLATERAL}")")" \
              "Masternode Collateral: ${MNCOLLATERAL} NRG" \
              "$(printf 'Next Reward ETA: %s' \
                "$(DISPLAYTIME "${SEC_TO_MNREWARD}")")" \
              "${_MNREWARDS}")"
            # Post message
            PROCESS_NODE_MESSAGES \
              "${mnShortAddress}" \
              "mn_reward" \
              "4" \
              "${_PAYLOAD}" \
              "" \
              "${DISCORD_WEBHOOK_USERNAME}" \
              "${DISCORD_WEBHOOK_AVATAR}"

            # Send EMAIL / SMS if set in ngrmon.conf
            if [[ "${SENDEMAIL}" = "Y" ]]; then
              SEND_EMAIL "Mn Rwd received"
            fi

            if [[ "${SENDSMS}" = "Y" ]]; then
              SEND_SMS "Mn Rwd received"
            fi
          fi
        fi
      fi
      ((CHKBLOCK++))
    done

    if [[ ! ${STAKERWD} == Y ]] || [[ ! ${MNRWD} == Y ]]; then
      log "${SHORTADDR}: No stake reward"
    fi
  done

  # Update last_block_checked for next iteration
  SQL_QUERY "REPLACE INTO variables (key, value)
    VALUES ('last_block_checked', '${CURRENTBLKNUM}');"
  # Get total on node
  GETTOTALBALANCE=$(total_node_balance "${GETBALANCE}" "${MNCOLLATERAL}")

  # Check staking status.
  STAKING_TEXT='Disabled'
  GETSTAKINGSTATUS="false"

  if [[ $(printf '%s\n' "${GETBALANCE} >= 1" | bc -l) -gt 0 ]]; then
    GETSTAKINGSTATUS=$(${COMMAND} "miner.stakingStatus().staking" 2>/dev/null)

    if [[ "${GETSTAKINGSTATUS}" == true ]]; then
      STAKING=1
      STAKING_TEXT='Enabled'
    fi
  fi

  if
    [[ -n "${GETBALANCE}" ]] &&
      [[ "$(printf '%s\n' "${GETBALANCE} > 0.0" | bc -l)" -gt 0 ]]
  then
    first_row="__${USRNAME} ${DAEMON_BIN}__"

    if [[ "$(echo "${MIN_STAKE} > ${GETBALANCE}" | bc -l)" -gt 0 ]]; then
      PROCESS_NODE_MESSAGES \
        "${DATADIR}" \
        "staking_balance" \
        "2" \
        "$(printf '%s\n%s\n%s' \
          "${first_row}" \
          "$(printf 'Balance (%s) is below the minimum staking threshold (%s).\n' \
            "${GETBALANCE}" \
            "${MIN_STAKE}")" \
          "${ACCTBALANCE} < ${MIN_STAKE} ")" \
        "" \
        "${DISCORD_WEBHOOK_USERNAME}" \
        "${DISCORD_WEBHOOK_AVATAR}"
    else
      PROCESS_NODE_MESSAGES \
        "${DATADIR}" \
        "staking_balance" \
        "5" \
        "$(printf '%s\nHas enough coins to stake now!' "${first_row}")" \
        "Balance is above the minimum" \
        "${DISCORD_WEBHOOK_USERNAME}" \
        "${DISCORD_WEBHOOK_AVATAR}"

      if [[ "${STAKING}" -eq 0 ]]; then
        PROCESS_NODE_MESSAGES \
          "${DATADIR}" \
          "staking_status" \
          "2" \
          "$(printf '%s\nStaking status is DISABLED' "${first_row}")" \
          "Staking is DISABLED" \
          "" \
          "" \
          "" \
          "${DISCORD_WEBHOOK_USERNAME}" \
          "${DISCORD_WEBHOOK_AVATAR}"
      fi

      if [[ "${STAKING}" -eq 1 ]]; then
        PROCESS_NODE_MESSAGES \
          "${DATADIR}" \
          "staking_status" \
          "5" \
          "$(printf '%s\nStaking status is now ENABLED!' "${first_row}")" \
          "Staking is ENABLED" \
          "${DISCORD_WEBHOOK_USERNAME}" \
          "${DISCORD_WEBHOOK_AVATAR}"
      fi
    fi
  fi

  # Masternode Status.
  if [[ ${MASTERNODE} -eq 1 ]]; then
    if [[ ${MNINFO} -eq 0 ]]; then
      PROCESS_NODE_MESSAGES \
        "${mnShortAddress}" \
        "masternode_status" \
        "1" \
        "__Account: ${mnShortAddress}__
Masternode is Offline" \
        "Masternode Offline" \
        "${DISCORD_WEBHOOK_USERNAME}" \
        "${DISCORD_WEBHOOK_AVATAR}"
    elif [[ ${MNINFO} -eq 1 ]]; then
      PROCESS_NODE_MESSAGES \
        "${mnShortAddress}" \
        "masternode_status" \
        "1" \
        "__Account: ${mnShortAddress}__
Masternode is Inactive" \
        "Masternode NOT Alive" \
        "${DISCORD_WEBHOOK_USERNAME}" \
        "${DISCORD_WEBHOOK_AVATAR}"
    elif [[ ${MNINFO} -eq 2 ]]; then
      PROCESS_NODE_MESSAGES \
        "${mnShortAddress}" \
        "masternode_status" \
        "5" \
        "__Account: ${mnShortAddress}__
Masternode is Active and Alive!" \
        "Masternode Alive" \
        "${DISCORD_WEBHOOK_USERNAME}" \
        "${DISCORD_WEBHOOK_AVATAR}"
    fi
  fi

  # Report on uptime
  PAST_UPTIME=$(SQL_QUERY "SELECT value FROM variables WHERE key = '${DATADIR}:uptime';")

  if [[ -z "${PAST_UPTIME}" ]]; then
    PAST_UPTIME="${UPTIME}"
  fi

  printf "uptime: %s\npast uptime: %s\n" "${UPTIME}" "${PAST_UPTIME}"

  if [[ "${UPTIME}" -lt "${PAST_UPTIME}" ]]; then
    PAST_UPTIME_HUMAN=$(DISPLAYTIME "${PAST_UPTIME}")

    if [[ "${PAST_UPTIME}" -lt 300 ]]; then
      SEND_ERROR \
        "__${USRNAME} ${DAEMON_BIN}__
Daemon was restarted mutiple times in the last 5 minutes
Past uptime: ${PAST_UPTIME_HUMAN}
New uptime: ${UPTIME_HUMAN} " \
        "" \
        "${DISCORD_WEBHOOK_USERNAME}" \
        "${DISCORD_WEBHOOK_AVATAR}"
    else
      SEND_WARNING \
        "__${USRNAME} ${DAEMON_BIN}__
Daemon was restarted
Past uptime: ${PAST_UPTIME_HUMAN}
New uptime: ${UPTIME_HUMAN}" \
        "" \
        "${DISCORD_WEBHOOK_USERNAME}" \
        "${DISCORD_WEBHOOK_AVATAR}"
    fi
  fi

  PAST_UPTIME_MONITOR=$(SQL_QUERY \
    "SELECT value FROM variables WHERE key = '${DATADIR}:uptime-monitor';")

  if [[ -z "${PAST_UPTIME_MONITOR}" ]]; then
    PAST_UPTIME_MONITOR=${UPTIME_MONITOR}
  fi

  printf "monitor uptime: %s\npast monitor uptime: %s\n" \
    "${UPTIME_MONITOR}" \
    "${PAST_UPTIME_MONITOR}"

  if [[ "${UPTIME_MONITOR}" -lt "${PAST_UPTIME_MONITOR}" ]]; then
    if [[ "${PAST_UPTIME_MONITOR}" -lt 300 ]]; then
      function='SEND_ERROR'
      message='Node Monitor was restarted mutiple times in the last 5 minutes'
    else
      function='SEND_WARNING'
      message='Node Monitor was restarted'
    fi

    ${function} \
      "$(printf '%s\n%s\nPast uptime: %s\nNew uptime: %s' \
        "__${USRNAME} ${DAEMON_BIN}__" \
        "${message}" \
        "$(DISPLAYTIME "${PAST_UPTIME_MONITOR}")" \
        "$(DISPLAYTIME "${UPTIME_MONITOR}")")" \
      "" \
      "${DISCORD_WEBHOOK_USERNAME}" \
      "${DISCORD_WEBHOOK_AVATAR}"
  fi

  SQL_QUERY "REPLACE INTO variables (key, value) \
    VALUES ('${DATADIR}:uptime', '${UPTIME}'), \
    ('${DATADIR}:uptime-monitor', '${UPTIME_MONITOR}');"
  # Update & report on balance.
  PAST_BALANCE=$(SQL_QUERY "SELECT value FROM variables
    WHERE key = '${DATADIR}:balance';")

  if [[ -z "${PAST_BALANCE}" ]]; then
    PAST_BALANCE=0
    SQL_QUERY "REPLACE INTO variables (key, value)
      VALUES ('${DATADIR}:balance', '${GETTOTALBALANCE}');"
  else
    SQL_QUERY "REPLACE INTO variables (key, value)
      VALUES ('${DATADIR}:balance', '${GETTOTALBALANCE}');"
  fi

  BALANCE_DIFF="$(printf '%f' \
    "$(printf '%f - %f\n' "${GETTOTALBALANCE}" "${PAST_BALANCE}" | bc -l)" |
    sed "${REMOVE_TRALING_DECIMAL_ZEROS_PATTERN}")"

  # Empty Wallet.
  if [[ $(echo "${BALANCE_DIFF} != 0 " | bc -l) -eq 0 ]]; then
    : # Do nothing.
  # Wallet has been drained.
  elif
    [[ -z "${GETTOTALBALANCE}" ]] ||
      [[ $(echo "${GETTOTALBALANCE} < 0.1" | bc -l) -eq 1 ]]
  then
    SEND_ERROR "$(
      printf '%s\n%s\n%s\n%s' \
        "__${USRNAME} ${DAEMON_BIN}__" \
        "Balance is now near zero ${TICKER_NAME}!" \
        "$(nrg_amount_info Before "${PAST_BALANCE}")" \
        "$(nrg_amount_info After "${GETTOTALBALANCE}")"
    )" "" "${DISCORD_WEBHOOK_USERNAME}" "${DISCORD_WEBHOOK_AVATAR}"
  # Larger amount has been moved off this wallet.
  elif [[ $(echo "${BALANCE_DIFF} < -1" | bc -l) -gt 0 ]]; then
    SEND_WARNING "$(
      printf '%s\n%s\n%s\n%s' \
        "__${USRNAME} ${DAEMON_BIN}__" \
        "Balance has decreased by over 1 ${TICKER_NAME}" \
        "$(nrg_difference_info "${BALANCE_DIFF}")" \
        "$(new_balance_info "${GETTOTALBALANCE}")"
    )" "" "${DISCORD_WEBHOOK_USERNAME}" "${DISCORD_WEBHOOK_AVATAR}"
  # Small amount has been moved.
  elif [[ $(printf '%f < 1\n' "${BALANCE_DIFF}" | bc -l) -gt 0 ]]; then
    SEND_INFO "$(
      printf '%s\n%s\n%s\n%s' \
        "__${USRNAME} ${DAEMON_BIN}__" \
        "Small amount of ${TICKER_NAME} has been transfered" \
        "$(nrg_difference_info "${BALANCE_DIFF}")" \
        "$(new_balance_info "${GETTOTALBALANCE}")"
    )" "" "${DISCORD_WEBHOOK_USERNAME}" "${DISCORD_WEBHOOK_AVATAR}"
  # More than 1 Coin has been added.
  elif [[ $(echo "${BALANCE_DIFF} >= 1" | bc -l) -gt 0 ]]; then
    if
      [[ $(echo "${BALANCE_DIFF} == ${MASTERNODE_REWARD}" | bc -l) -eq 1 ]]
    then
      return
    elif
      [[ $(echo "${BALANCE_DIFF} >= ${STAKE_REWARD}" | bc -l) -gt 0 ]] &&
        [[ $(echo "${BALANCE_DIFF} < ${STAKE_REWARD_UPPER}" | bc -l) -gt 0 ]]
    then
      return
    else
      SEND_SUCCESS "$(
        printf '%s\n%s\n%s\n%s' \
          "__${USRNAME} ${DAEMON_BIN}__" \
          "Larger amount of ${TICKER_NAME} has been transfered" \
          "$(nrg_difference_info "${BALANCE_DIFF}")" \
          "$(new_balance_info "${GETTOTALBALANCE}")"
      )" "" "${DISCORD_WEBHOOK_USERNAME}" "${DISCORD_WEBHOOK_AVATAR}"
    fi
  fi

  # Report on chain splits
  NODEHASH=$(${COMMAND} "nrg.getBlock($CURRENTBLKNUM).hash" 2>/dev/null |
    jq -r '.')
  NODEAPIHASH=$(${NODEAPICOMMAND} \
    "web3.nrg.getBlock($CURRENTBLKNUM).hash" 2>/dev/null | jq -r '.')
  SYNCSTATUS=$(${COMMAND} "nrg.syncing" 2>/dev/null | jq '.')

  if [[ "${SYNCSTATUS}" == false ]]; then
    NODEINSYNC="Node is in Sync"
  else
    NODEINSYNC="Node is NOT in Sync"
  fi

  if
    [[ ${NODEHASH} != "${NODEAPIHASH}" ]] &&
      [[ -n ${NODEHASH} ]] &&
      [[ -n ${NODEAPIHASH} ]]
  then
    FIRSTNODEHASH=${NODEHASH:2:8}
    LASTNODEHASH=${NODEHASH:${#NODEHASH}-8}
    FIRSTNODEAPIHASH=${NODEAPIHASH:2:8}
    LASTNODEAPIHASH=${NODEAPIHASH:${#NODEAPIHASH}-8}
    _PAYLOAD="__${USRNAME} ${DAEMON_BIN}__
Chain Split detected.
${NODEINSYNC}
Block Height Checked: ${CURRENTBLKNUM}
Local Hash: ${FIRSTNODEHASH}...${LASTNODEHASH}
NodeAPI Hash: ${FIRSTNODEAPIHASH}...${LASTNODEAPIHASH}
Block Height: ${GETBLOCKCOUNT}
Connections: ${GETCONNECTIONCOUNT}"
    PROCESS_NODE_MESSAGES \
      "${DATADIR}" \
      "chain_split" \
      "2" \
      "${_PAYLOAD}" \
      ":warning: Warning Chain :link: Split :warning:" \
      "${DISCORD_WEBHOOK_USERNAME}" \
      "${DISCORD_WEBHOOK_AVATAR}"
  elif [[ ${NODEHASH} == "${NODEAPIHASH}" ]]; then
    FIRSTNODEHASH=${NODEHASH:2:8}
    LASTNODEHASH=${NODEHASH:${#NODEHASH}-8}
    FIRSTNODEAPIHASH=${NODEAPIHASH:2:8}
    LASTNODEAPIHASH=${NODEAPIHASH:${#NODEAPIHASH}-8}
    _PAYLOAD="__${USRNAME} ${DAEMON_BIN}__
Chain back to normal.
${NODEINSYNC}
Block Height Checked: ${CURRENTBLKNUM}
Local Hash: ${FIRSTNODEHASH}...${LASTNODEHASH}
NodeAPI Hash: ${FIRSTNODEAPIHASH}...${LASTNODEAPIHASH}
Block Height: ${GETBLOCKCOUNT}
Connections: ${GETCONNECTIONCOUNT}"
    PROCESS_NODE_MESSAGES \
      "${DATADIR}" \
      "chain_split" \
      "5" \
      "${_PAYLOAD}" \
      "Chain :link: is normal" \
      "${DISCORD_WEBHOOK_USERNAME}" \
      "${DISCORD_WEBHOOK_AVATAR}"
  fi

  # Report on daemon info.
  MASTERNODE_TEXT='Disabled'

  if [[ ${MASTERNODE} -eq 1 ]]; then
    MASTERNODE_TEXT='Inactive'

    if [[ ${MNINFO} -eq 1 ]]; then
      MASTERNODE_TEXT='Offline'
    elif [[ ${MNINFO} -eq 2 ]]; then
      MASTERNODE_TEXT='Enabled'
    fi
  fi

  # Check Github for URL of latest version
  GIT_VERSION=$(curl -s ${GITAPI_URL} | jq -r '.tag_name')
  # Extract latest version number without the 'v'
  GIT_LATEST="$(printf '%s' "${GIT_VERSION}" | sed 's/v//g')"

  if _version_gt "${GIT_LATEST}" "${VERSION}"; then
    UPGRADE_TEXT="YES"
    PROCESS_NODE_MESSAGES "${DATADIR}" "node_version" "2" "__${USRNAME} ${DAEMON_BIN}__
Upgrade REQUIRED. Installed Version: ${VERSION}. Git Version: ${GIT_LATEST}" "Upgrade REQUIRED" "" "" "" "${DISCORD_WEBHOOK_USERNAME}" "${DISCORD_WEBHOOK_AVATAR}"
  else
    UPGRADE_TEXT="No"
    PROCESS_NODE_MESSAGES "${DATADIR}" "node_version" "5" "__${USRNAME} ${DAEMON_BIN}__
Running most recent version: ${VERSION}" "Node version current" "${DISCORD_WEBHOOK_USERNAME}" "${DISCORD_WEBHOOK_AVATAR}"
  fi

  _PAYLOAD="$(printf '%s\n%s\n%s\n%s\n%s\n%s\n%s\n%s\n%s' \
    "__${USRNAME} ${DAEMON_BIN}__" \
    "Block Height: ${GETBLOCKCOUNT}" \
    "Connections: ${GETCONNECTIONCOUNT}" \
    "Staking Status: ${STAKING_TEXT}" \
    "Masternode Status: ${MASTERNODE_TEXT}" \
    "Upgrade Required: ${UPGRADE_TEXT}" \
    "PID: ${DAEMON_PID}" \
    "Uptime: $(DISPLAYTIME "${UPTIME}")" \
    "Monitor uptime: $(DISPLAYTIME "${UPTIME_MONITOR}")")"

  if value_to_bool "${MARKET_PRICE_IN_INFORMATION}"; then
    market_price
    _PAYLOAD="$(printf '%s\nMarket price: %s %s' \
      "${_PAYLOAD}" \
      "${CURRENCY}" \
      "${NRGMKTPRICE}")"
  fi

  PROCESS_NODE_MESSAGES \
    "${DATADIR}" \
    'node_info' \
    3 \
    "${_PAYLOAD}" \
    '' \
    "${DISCORD_WEBHOOK_USERNAME}" \
    "${DISCORD_WEBHOOK_AVATAR}"
}

GET_INFO_ON_THIS_NODE() {
  USRNAME=${1}
  BIN_LOC=${2}
  DAEMON_BIN=${3}
  DATADIR=${4}
  DAEMON_PID=${5}
  UPTIME=${6}
  UPTIME_MONITOR=${7}
  GETBALANCE=0
  GETTOTALBALANCE=0

  # is the daemon running.
  if [[ -z "${DAEMON_PID}" ]]; then
    REPORT_INFO_ABOUT_NODE "${USRNAME}" "${DAEMON_BIN}" "${DATADIR}" "-1" "This node is not running."

    return
  fi

  # setup vars.
  GETBLOCKCOUNT=$(${COMMAND} "nrg.blockNumber" 2>/dev/null | jq -r '.')
  GETCONNECTIONCOUNT=$(${COMMAND} "net.peerCount" 2>/dev/null | jq -r '.')

  if [[ -z ${DATADIR} ]]; then
    DATADIR=$(ps -ef |
      grep datadir |
      grep -v "grep datadir" |
      grep -v "color" |
      awk -F'datadir' '{print $2}' |
      awk -F' ' '{print $1}')
  fi

  if [[ -z "${GETBLOCKCOUNT}" ]] && [[ -z "${GETCONNECTIONCOUNT}" ]]; then
    REPORT_INFO_ABOUT_NODE \
      "${USRNAME}" \
      "${DAEMON_BIN}" \
      "${DATADIR}" \
      "-2" \
      "This node is frozen. PID: ${DAEMON_PID}"

    return
  fi

  # Get the version number.
  VERSION=$(${ENERGI_EXEC} version 2>/dev/null |
    grep "^Version:" |
    sed 's/[^0-9.]*\([0-9.]*\).*/\1/')

  if [[ -z "${VERSION}" ]]; then
    VERSION=$(${COMMAND} "admin.nodeInfo.name" 2>/dev/null |
      awk -F\/ '{print $2}' |
      sed 's/[^0-9.]*\([0-9.]*\).*/\1/')
  fi

  if [[ -z ${LISTACCOUNTS} ]]; then
    LISTACCOUNTS=$(${COMMAND} "personal.listAccounts" 2>/dev/null | jq -r '.[]')
  fi

  ALL_STAKE_INPUTS_BALANCE_COUNT=''
  if [[ $(printf '%s > 0\n' "${GETBALANCE}" | bc -l) -gt 0 ]]; then
    NUMBER_OF_ACCOUNTS=$(echo "${LISTACCOUNTS}" | wc -w)
    ALL_STAKE_INPUTS_BALANCE_COUNT="${STAKE_INPUTS_BALANCE} ${NUMBER_OF_ACCOUNTS}"
  fi

  # Check networkhashps
  GETNETHASHRATE=$(${COMMAND} "miner.getHashrate()" 2>/dev/null |
    grep -Eo '[+-]?[0-9]+([.][0-9]+)?' 2>/dev/null)

  if [[ -z "${GETNETHASHRATE}" ]]; then
    GETNETHASHRATE=0
  fi

  # Output info.
  REPORT_INFO_ABOUT_NODE \
    "${USRNAME}" \
    "${DAEMON_BIN}" \
    "${DATADIR}" \
    0 \
    0 \
    "${GETBALANCE}" \
    "${GETTOTALBALANCE}" \
    "${STAKING:-0}" \
    "${GETCONNECTIONCOUNT}" \
    "${GETBLOCKCOUNT}" \
    "${UPTIME}" \
    "${UPTIME_MONITOR}" \
    "${DAEMON_PID}" \
    "${GETNETHASHRATE}" \
    "${MNWIN}" \
    "${VERSION}"
}

GET_NODE_INFO() {
  DAEMON_BIN_FILTER="${1}"
  FILENAME_WITH_FUNCTIONS=''

  if [[ -r /var/multi-masternode-data/.bashrc ]]; then
    FILENAME_WITH_FUNCTIONS='/var/multi-masternode-data/.bashrc'
  elif [[ -r /root/.bashrc ]]; then
    FILENAME_WITH_FUNCTIONS='/root/.bashrc'
  elif [[ -r "${STAKER_HOME}/.bashrc" ]]; then
    FILENAME_WITH_FUNCTIONS="${STAKER_HOME}/.bashrc"
  elif [[ -r /home/ubuntu/.bashrc ]]; then
    FILENAME_WITH_FUNCTIONS='/home/ubuntu/.bashrc'
  fi

  USR_HOME_DIR=$(grep "${USRNAME}" /etc/passwd | awk -F: '{print $6}')

  if [[ "${USR_HOME_DIR}" == 'X' ]]; then
    USR_HOME_DIR=${USR_HOME_DIR_ALT}
  fi

  MN_USRNAME=$(basename "${USR_HOME_DIR}")
  DAEMON_BIN=''
  CONTROLLER_BIN=''
  CONF_LOCATIONS=${DATADIR}

  if [[ -z "${CONF_LOCATIONS}" ]]; then
    : # Do nothing
  fi

  CONF_FOLDER=$(dirname "${CONF_LOCATIONS}")
  # Get daemon bin name and pid from lock in toml folder.
  CONF_FOLDER=$(dirname "${CONF_LOCATION}")
  DAEMON_BIN="${ENERGI_EXEC}"
  CONTROLLER_BIN="${DAEMON_BIN}"
  DAEMON_PID=$(ps -ef |
    grep nodemon_cron.sh |
    grep -v "grep nodemon_cron.sh" |
    grep -v "grep --color=auto nodemon_cron.sh" |
    grep -v "attach" |
    awk '{print $2}')

  # Get path to daemon bin.
  if [[ -n "${DAEMON_PID}" ]]; then
    DAEMON_BIN_LOC=$(which "${DAEMON_BIN}")
    CONTROLLER_BIN_LOC="${DATADIR}"
    COMMAND_FOLDER=$(dirname "${DAEMON_BIN_LOC}")
    CONTROLLER_BIN_FOLDER=$(find "${COMMAND_FOLDER}" -executable -type f 2>/dev/null | grep -Ei "${DAEMON_BIN}$")

    if [[ -n "${CONTROLLER_BIN_FOLDER}" ]]; then
      CONTROLLER_BIN_LOC="${CONTROLLER_BIN_FOLDER}"
    fi
  fi

  CONF_LOCATION=${CONTROLLER_BIN_LOC}
  UPTIME=0

  if [[ -n "${DAEMON_PID}" ]]; then
    uptime() {
      ps_list=${1}
      daemon_pid=${2}
      printf '%s' "$(printf '%s' "${ps_list}" |
        cut -c 32- |
        grep " ${daemon_pid} " |
        awk '{print $2}' |
        head -n 1 |
        awk '{print $1}' |
        grep -o '[0-9]*')"
    }

    # Command to get a list of processes with uptime
    ps_uptime='ps --no-headers -axo user:32,pid,etimes,command'
    # Get the uptime of the Core container.
    core_daemon_pid="$(ssh core "pgrep ${DAEMON_BIN}")"
    UPTIME="$(uptime "$(ssh core "${ps_uptime}")" "${core_daemon_pid}")"
    # Get the uptime of the Node Monitor container.
    UPTIME_MONITOR="$(uptime "$(${ps_uptime})" "${DAEMON_PID}")"
  fi

  # Skip if filtered out
  if
    [[ -n "${DAEMON_BIN_FILTER}" ]] &&
      [[ "${DAEMON_BIN_FILTER}" != "${DAEMON_BIN}" ]]
  then
    return
  fi

  if [[ "${DEBUG_OUTPUT}" -eq 1 ]]; then
    printf '\n+++++++++++++++++++++++++++++\n'
    printf 'Username: %s\n' "${USRNAME}"
    printf 'MN Username: %s\n' "${MN_USRNAME}"
    printf 'Daemon: %s %s\n' "${DAEMON_BIN}" "${DAEMON_BIN_LOC}"
    printf 'Conf Location: %s\n' "${DATADIR}"
    printf 'PID: %s\n' "${DAEMON_PID}"
    printf 'Uptime: %s\n' "${UPTIME}"
    printf 'Monitor Uptime: %s\n\n' "${UPTIME_MONITOR}"
  fi

  GET_INFO_ON_THIS_NODE \
    "${USRNAME}" \
    "${CONTROLLER_BIN_LOC}" \
    "${DAEMON_BIN}" \
    "${DATADIR}" \
    "${DAEMON_PID}" \
    "${UPTIME}" \
    "${UPTIME_MONITOR}"
}

NOT_CRON_WORKFLOW() {
  if [[ -z ${DAEMON_BIN} ]]; then
    DAEMON_BIN="${ENERGI_EXEC}"
  fi

  printf '\nInteractive Section. Press enter to use defaults.\n'
  SERVER_ALIAS=$(SQL_QUERY "SELECT value FROM variables WHERE key = 'server_alias';")

  if
    [[ -z "${SERVER_ALIAS}" ]] ||
      [[ "${SERVER_ALIAS}" != "${ECNM_SERVER_ALIAS:=$(hostname)}" ]]
  then
    SERVER_ALIAS="${ECNM_SERVER_ALIAS}"
  fi

  printf "Current alias for this server: "
  override_read "${SERVER_ALIAS}"
  SQL_QUERY "REPLACE INTO variables (key,value) VALUES ('server_alias','${REPLY}');"
  printf '\nIP Address: '
  ip_address
  SHOW_IP=$(SQL_QUERY "SELECT value FROM variables WHERE key = 'show_ip';")

  if
    value_to_bool "${ECNM_SHOW_IP}" ||
      (value_to_bool "${SHOW_IP:-${ECNM_SHOW_IP:=no}}" &&
        value_to_bool "${ECNM_SHOW_IP}")
  then
    SHOW_IP='y'
  else
    SHOW_IP='n'
  fi

  printf "Display IP in logs (y/n)? "
  override_read ${SHOW_IP}
  REPLY=${REPLY,,} # tolower

  if [[ "${REPLY}" == y ]]; then
    SQL_QUERY "REPLACE INTO variables (key,value) VALUES ('show_ip','1');"
  else
    SQL_QUERY "REPLACE INTO variables (key,value) VALUES ('show_ip','0');"
  fi

  echo
  PREFIX='Setup'
  REPLY='y'
  DISCORD_WEBHOOK_URL=$(SQL_QUERY "SELECT value FROM variables
    WHERE key = 'discord_webhook_url_error';")

  if
    ! value_to_bool "${INTERACTIVE}" &&
      [[ -z "${DISCORD_WEBHOOK_ERROR}" || -z \
      "${DISCORD_WEBHOOK_INFORMATION}" || -z \
      "${DISCORD_WEBHOOK_SUCCESS}" || -z \
      "${DISCORD_WEBHOOK_WARNING}" ]]
  then
    REPLY='n'
  fi

  if [[ -n "${DISCORD_WEBHOOK_URL}" ]]; then
    REPLY='n'
    PREFIX='Redo'
  fi

  if
    ! value_to_bool "${INTERACTIVE}" &&
      value_to_bool "${DISCORD_WEBHOOK_CHANGE}"
  then
    REPLY='y'
    PREFIX='Change'
  fi

  printf '%s Discord Bot webhook URLs (y/n)? ' "${PREFIX}"
  override_read ${REPLY}
  REPLY=${REPLY,,} # tolower

  if [[ "${REPLY}" == 'y' ]]; then
    GET_DISCORD_WEBHOOKS
    echo "Discord setup complete!"
  fi

  echo
  PREFIX='Setup'
  REPLY='y'
  DISCORD_WEBHOOK_URL=$(SQL_QUERY "SELECT value FROM variables
    WHERE key = 'discord_webhook_url_error';")
  CHAT_ID=$(SQL_QUERY "SELECT value FROM variables
    WHERE key = 'telegram_chatid';")

  if
    (! value_to_bool "${INTERACTIVE}" && [[ -z "${TELEGRAM_BOT_TOKEN}" ]]) ||
      (value_to_bool "${INTERACTIVE}" && [[ -n "${DISCORD_WEBHOOK_URL}" ]])
  then
    REPLY='n'
  fi

  if [[ -n "${CHAT_ID}" ]]; then
    REPLY='n'
    PREFIX='Redo'
  fi

  if
    ! value_to_bool "${INTERACTIVE}" &&
      value_to_bool "${TELEGRAM_BOT_TOKEN_CHANGE}"
  then
    REPLY='y'
    PREFIX='Change'
  fi

  printf '%s Telegram Bot token (y/n)? ' "${PREFIX}"
  override_read "${REPLY}"
  REPLY=${REPLY,,} # tolower

  if [[ "${REPLY}" == y ]]; then
    TELEGRAM_SETUP
    echo "Telegram setup complete!"
  fi

  return 1 2>/dev/null || exit 1
}

# Main
if [[ "${RESET}" == 'y' ]]; then
  RESET_NODEMON
fi

if [[ "${arg1}" == 'node_run' ]]; then
  GET_NODE_INFO "${arg2}" "${arg3}"
elif [[ "${arg1}" != 'cron' ]]; then
  NOT_CRON_WORKFLOW
else
  GET_LATEST_LOGINS
  CHECK_DISK
  CHECK_CPU_LOAD
  CHECK_SWAP
  CHECK_RAM
  CHECK_OOM_KILLS
  CHECK_CLOCK
  CHECK_DEBSUMS
  CHECK_RKHUNTER
  GET_NODE_INFO
fi
