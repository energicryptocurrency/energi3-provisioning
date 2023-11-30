#!/bin/bash

value_to_bool() {
  value="${1,,}"

  if
    [[ "${value}" == 'y' ]] ||
      [[ "${value}" == 'yes' ]] ||
      [[ "${value}" == 'true' ]] ||
      [[ "${value}" -eq 1 ]]
  then
    return 0
  fi

  return 1
}

ip_address() {
  if value_to_bool "${ECNM_SHOW_IP_EXTERNAL:-no}"; then
    IP_ADDRESS="$(wget -qO- https://api.ipify.org)"
  else
    IP_ADDRESS="$(hostname -i)"
  fi

  printf '%s' "${IP_ADDRESS}"
}

market_price() {
  if [[ -z "${NRGMKTPRICE}" ]]; then
    timestamp="${1}"
    endpoint="https://min-api.cryptocompare.com/data/price?fsym=NRG&tsyms=${CURRENCY}"

    if [[ -n "${timestamp}" ]]; then
      endpoint="${endpoint}&ts=${timestamp}"
    fi

    NRGMKTPRICE="$(curl \
      --connect-timeout 30 \
      --header "Accept: application/json" \
      --silent \
      "${endpoint}" |
      jq ".${CURRENCY}")"
  fi
}

message_date() {
  TZ="${MESSAGE_TIME_ZONE}" date -R
}

nrg_amount_info() {
  label="${1:?}"
  nrg_balance="${2:?}"
  balance_text="${label}: "
  balance_indentation="${#balance_text}"
  balance_text="$(printf '%s%s NRG\n' "${balance_text}" "${nrg_balance}")"
  market_price ''

  if value_to_bool "${NRG_AMOUNT_IN_CURRENCY}"; then
    balance_text="$(printf '%s\n%*s%s %s' \
      "${balance_text}" \
      "${balance_indentation}" \
      " " \
      "$(printf '%.2f' \
        "$(printf '%s * %s\n' "${nrg_balance}" "${NRGMKTPRICE}" | bc)")" \
      "${CURRENCY}")"
  fi

  printf '%s' "${balance_text}"
}

nrg_difference_info() {
  nrg_amount_info 'Difference' "${1:?}"
}

masternode_reward_info() {
  nrg_amount_info 'Masternode Reward' "${1:?}"
}

new_balance_info() {
  nrg_amount_info 'New Balance' "${1:?}"
}

override_read() {
  if value_to_bool "${INTERACTIVE}"; then
    printf '%s\n' "${1}"
    REPLY="${1}"
  else
    read -e -i "${1}" -r
  fi
}

stake_reward_info() {
  nrg_amount_info 'Stake Reward' "${1:?}"
}

total_node_balance() {
  masternode_collateral=${1}
  staking_balance=${2}
  printf '%s' "$(printf '%s\n' "${masternode_collateral} + ${staking_balance}" |
    bc -l |
    sed '/\./ s/\.\{0,1\}0\{1,\}$//')"
}
