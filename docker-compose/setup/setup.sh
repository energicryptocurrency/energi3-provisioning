#!/bin/sh
# A helper script to do a one time setup to use `energi-docker-compose`
data_directory="$(basename "${ENERGI_CORE_DIR}")"
keystore_path="${data_directory}"/keystore
setup_keystore_path=setup/"${keystore_path}"
staker_keystore_path="${STAKER_HOME}/${keystore_path}"
user="$(basename "${STAKER_HOME}")"

mkdir --parent "${staker_keystore_path}" &&
  mv /"${setup_keystore_path}"/* "${staker_keystore_path}" ||
  (
    printf "Most probably the directory \`%s\` " "${setup_keystore_path}" &&
      printf "does not contain keystore file(s)\n" &&
      printf "Keystore file(s) must be copied to \`%s\` " \
        "${setup_keystore_path}" &&
      printf "before using \`./helper setup\`\n" &&
      exit 1
  ) || exit 1
chown -R "${user}:${user}" "${ENERGI_CORE_DIR}"

# Set up ssh key for nodemon to access instance
ssh-keygen -q -t rsa -N '' -f ../nodemon/.ssh/id_rsa <<<y >/dev/null 2>&1
cat ../nodemon/.ssh/id_rsa.pub >> ../.ssh/authorized_keys
