#!/bin/bash

######################################################################
# Copyright (c) 2020
# All rights reserved.
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND.
#
# Desc:   Batch script to download and setup Energi3 on MacOS. The
#         script will upgrade an existing installation.
# 
# Version:
#   1.0.0 20200212 ZA Initial Script
#
: '
# Run the script to get started:
```
bash -i <( curl -sL https://raw.githubusercontent.com/energicryptocurrency/energi3-provisioning/master/scripts/macos/energi3-macos-installer.sh )
```
'
######################################################################


### ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ ###
# Global Variables
### ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ ###

# Check if we have enough memory
FREE_BLOCKS=$(vm_stat | grep free | awk '{ print $3 }' | sed 's/\.//')
INACTIVE_BLOCKS=$(vm_stat | grep inactive | awk '{ print $3 }' | sed 's/\.//')
SPECULATIVE_BLOCKS=$(vm_stat | grep speculative | awk '{ print $3 }' | sed 's/\.//')

FREE=$((($FREE_BLOCKS+SPECULATIVE_BLOCKS)*4096/1048576))
INACTIVE=$(($INACTIVE_BLOCKS*4096/1048576))
TOTAL=$((($FREE+$INACTIVE)))

if [[ ${TOTAL} -lt 850 ]]; then
  echo "This installation requires at least 1GB of RAM.";
  exit 1
fi

# OS Settings
export DEBIAN_FRONTEND=noninteractive 

# Locations of Repositories and Guide
API_URL="https://api.github.com/repos/energicryptocurrency/energi3/releases/latest"
# Production
#BASE_URL="https://raw.githubusercontent.com/energicryptocurrency/energi3-provisioning/master/scripts"
# Test
BASE_URL="https://raw.githubusercontent.com/zalam003/EnergiCore3/master/production/scripts"
SCRIPT_URL="${BASE_URL}/linux"
TP_URL="${BASE_URL}/thirdparty"
DOC_URL="https://docs.energi.software"
#GITURL="https://raw.githubusercontent.com/energicryptocurrency/energi3-provisioning/"

# Energi3 Bootstrap Settings
#export BLK_HASH=gsaqiry3h1ho3nh
#export BOOTSTRAP_URL="https://www.dropbox.com/s/%BLK_HASH%/energi3bootstrap.tar.gz"

# Snapshot Block (need to update)
MAINNETSSBLOCK=1500000
TESTNETSSBLOCK=1500000

# Set Executables & Configuration
export ENERGI3_EXE=energi3
export ENERGI3_CONF=energi3.toml
export ENERGI3_IPC=energi3.ipc

# Set colors
BLUE=`tput setaf 4`
RED=`tput setaf 1`
GREEN=`tput setaf 2`
YELLOW=`tput setaf 2`
NC=`tput sgr0`

### ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ ###
# Functions
### ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ ###

_os_arch () {
  # Check Architecture
  OSNAME=`system_profiler SPSoftwareDataType | grep Kernel | awk '{print $3}'`
  OSVERSIONLONG=`sw_vers -productVersion`
  KERNELVERSION=`echo ${OSVERSIONLONG} | awk -F\. '{ print $1 }'`
  MAJORVERSION=`echo ${OSVERSIONLONG} | awk -F\. '{ print $2 }'`
  
  # 10.15 - Catalina
  # 10.14 - Mojave
  # 10.13 - High Sierra
  # 10.12 - Sierra
  # 10.11 - El Capitan
  
  echo -n "${OSNAME} ${OSVERSIONLONG} is  "
  if [ "${OSNAME}" = "Darwin" ] && [ ${KERNELVERSION} -ge 10 ] && [ ${MAJORVERSION} -ge 12 ]
  then
    echo "${GREEN}supported${NC}"
  else
    echo "${RED}not supported${NC}"
    exit 0
  fi
  
  echo -n "OS architecture "
  OSARCH=`uname -m`
  if [ "${OSARCH}" != "x86_64" ]
  then
    echo "${RED}${OSARCH} is not supported${NC}"
    echo "Please goto our website to check which platforms are supported."
    exit 0
  else
    echo "${GREEN}${OSARCH} is supported${NC}"
    sleep 0.3
  fi
  
}

_check_runas () {

  # Who is running the script
  # If root no sudo required
  # If user has sudo privilidges, run sudo when necessary

  RUNAS=`whoami`
  
  if [[ $EUID = 0 ]]
  then
    SUDO=""
  else
    ISSUDOER=`getent group sudo | grep ${RUNAS}`
    if [ ! -z "${ISSUDOER}" ]
    then
      SUDO='sudo'
    else
      echo "User ${RUNAS} does not have sudo permissions."
      echo "Run ${BLUE}sudo ls -l${NC} to set permissions if you know the user ${RUNAS} has sudo previlidges"
      echo "and then rerun the script"
      echo "Exiting script..."
      sleep 3
      exit 0
    fi
  fi
}

_check_install () {

  CHKV3USRTMP=/tmp/chk_v3_usr.tmp
  find ${HOME} -name energi3.ipc | awk -F\/ '{print $3}' > ${CHKV3USRTMP}
  V3USRCOUNT=`wc -l ${CHKV3USRTMP} | awk '{ print $1 }'`
  USRNAME=`whoami`
  cd
  export USRHOME=`pwd`
  export ENERGI3_HOME=${USRHOME}/energi3
  
  case ${V3USRCOUNT} in
  
    0)
      
      # New Installation:
      #   * No energi3.ipc file on the computer
      #   * No energi.conf or energid on the computer
      #
      # Migration Installation:
      #   * energi.conf and energid exists
      #   * No energi3.ipc file on the computer
      #   * energi3.ipc file exists on the computer
      #   * Keystore file does not exists
      #   * No $ENERGI3_HOME/etc/migrated_to_v3.log exists
      
      INSTALLTYPE=new

      ;;
      
    1)
      
      # Upgrade existing version of Energi 3:
      #   * One instance of Energi3 is already installed
      #   * energi3.ipc file exists
      #   * Version on computer is older than version in Github
      
      INSTALLTYPE=upgrade
      echo "The script will upgrade to the latest version of energi3 from Github"
      echo "if available as user: ${GREEN}${USRNAME}${NC}"
      
      ;;
  
    *)
      
      # Upgrade existing version of Energi3:
      #   * More than one instance of Energi3 is already installed
      #   * energi3.ipc file exists
      #   * Version on computer is older than version in Github
      #   * User selects which instance to upgrade
      
      INSTALLTYPE=upgrade

      ;;
  
  esac
  
  # Clean-up temporary file
  rm -rf ${CHKV3USRTMP}

}

_setup_appdir () {

  # Setup application directories if does not exist
  
  echo "Energi3 will be installed in ${ENERGI3_HOME}"
  sleep 0.5
  # Set application directories
  export BIN_DIR=${ENERGI3_HOME}/bin
  export ETC_DIR=${ENERGI3_HOME}/etc
  export JS_DIR=${ENERGI3_HOME}/js
  export PW_DIR=${ENERGI3_HOME}/.secure
  export TMP_DIR=${ENERGI3_HOME}/tmp

  # Create directories if it does not exist
  if [ ! -d ${BIN_DIR} ]
  then
    echo "    Creating directory: ${BIN_DIR}"
    mkdir -p ${BIN_DIR}
  fi
  if [ ! -d ${ETC_DIR} ]
  then
    echo "    Creating directory: ${ETC_DIR}"
    mkdir -p ${ETC_DIR}
  fi
  if [ ! -d ${JS_DIR} ]
  then
    echo "    Creating directory: ${JS_DIR}"
    mkdir -p ${JS_DIR}
  fi
  if [ ! -d ${TMP_DIR} ]
  then
    echo "    Creating directory: ${TMP_DIR}"
    mkdir -p ${TMP_DIR}
  fi
  
  echo
  echo "Changing ownership of ${ENERGI3_HOME} to ${USRNAME}"
  if [[ ${EUID} = 0 ]]
  then
    chown -R ${USRNAME}:${USRNAME} ${ENERGI3_HOME}
  fi
  
}

_check_ismainnet () {

  # Confirm Mainnet or Testnet
  # Default: Mainnet

  isMainnet=y
  export CONF_DIR=${USRHOME}/.energicore3
  export FWPORT=39797
  export APPARG=''
  export isMainnet=y
  echo "The application will be setup for Mainnet"

}

_install_energi3 () {

  # Download and install node software and supporting scripts

  # Name of scripts
  #NODE_SCRIPT=start_staking.sh
  #MN_SCRIPT=start_mn.sh
  NODE_SCRIPT=run_macos.sh
  MN_SCRIPT=run_mn_macos.sh
  JS_SCRIPT=utils.js
  
  # Check Github for URL of latest version
  if [ -z "${GITHUB_LATEST}" ]
  then
    GITHUB_LATEST=`curl -s ${API_URL}`
  fi
    if [[ ! -x "$(command -v wget)" ]]
  then
    brew install wget
  fi
  if [[ ! -x "$(command -v jq)" ]]
  then
    brew install jq
  fi
  BIN_URL=$( echo "${GITHUB_LATEST}" | jq -r '.assets[].browser_download_url' | grep -v debug | grep -v '.sig' | grep darwin )
 
  # Download from repositogy
  echo "Downloading Energi Core Node and scripts"
  cd ${BIN_DIR}
  if [ -f "${ENERGI3_EXE}" ]
  then
    mv ${ENERGI3_EXE} ${ENERGI3_EXE}.old
  fi
  #curl "${BIN_URL}" --output ${ENERGI3_EXE}
  wget -4qo- "${BIN_URL}" -O "${ENERGI3_EXE}" --show-progress --progress=bar:force:noscroll 2>&1
  sleep 0.3
  chmod 755 ${ENERGI3_EXE}
  if [[ ${EUID} = 0 ]]
  then
    chown ${USRNAME}:${USRNAME} ${ENERGI3_EXE}
  fi    
  
  if [ -f "${NODE_SCRIPT}" ]
  then
    mv ${NODE_SCRIPT} ${NODE_SCRIPT}.old
  fi  
  #curl -sL "${SCRIPT_URL}/${NODE_SCRIPT}" > ${NODE_SCRIPT}
  wget -4qo- "${SCRIPT_URL}/${NODE_SCRIPT}?dl=1" -O "${NODE_SCRIPT}" --show-progress --progress=bar:force:noscroll 2>&1
  sleep 0.3
  chmod 755 ${NODE_SCRIPT}
  if [[ ${EUID} = 0 ]]
  then
    chown ${USRNAME}:${USRNAME} ${NODE_SCRIPT}
  fi

  if [ -f "${MN_SCRIPT}" ]
  then
    mv ${MN_SCRIPT} ${MN_SCRIPT}.old
  fi  
  #curl -sL "${SCRIPT_URL}/${MN_SCRIPT}" > ${MN_SCRIPT}
  wget -4qo- "${SCRIPT_URL}/${MN_SCRIPT}?dl=1" -O "${MN_SCRIPT}" --show-progress --progress=bar:force:noscroll 2>&1
  sleep 0.3
  chmod 755 ${MN_SCRIPT}
  if [[ ${EUID} = 0 ]]
  then
    chown ${USRNAME}:${USRNAME} ${MN_SCRIPT}
  fi

  cd ${JS_DIR}
  if [ -f "${JS_SCRIPT}" ]
  then
    mv ${JS_SCRIPT} ${JS_SCRIPT}.old
  fi
  #curl -sL "${BASE_URL}/utils/${JS_SCRIPT}" > ${JS_SCRIPT}
  wget -4qo- "${BASE_URL}/utils/${JS_SCRIPT}?dl=1" -O "${JS_SCRIPT}" --show-progress --progress=bar:force:noscroll 2>&1
  sleep 0.3
  chmod 644 ${JS_SCRIPT}
  if [[ ${EUID} = 0 ]]
  then
    chown ${USRNAME}:${USRNAME} ${JS_SCRIPT}
  fi
  
  # Change to install directory
  cd
  
}

_version_gt() { 

  # Check if FIRST version is greater than SECOND version
  
  test "$(printf '%s\n' "$@" | sort -V | head -n 1)" != "$1"; 
  
}

_upgrade_energi3 () {

  # Check the latest version in Github 
  
  GITHUB_LATEST=$( curl -s ${API_URL} )
  GIT_VERSION=$( echo "${GITHUB_LATEST}" | jq -r '.tag_name' )
  
  # Extract latest version number without the 'v'
  GIT_LATEST=$( echo ${GIT_VERSION} | sed 's/v//g' )
  
  # Installed Version
  INSTALL_VERSION=$( ${BIN_DIR}/${ENERGI3_EXE} version | grep "^Version" | awk '{ print $2 }' | awk -F\- '{ print $1 }' 2>/dev/null )
  
  if _version_gt ${GIT_LATEST} ${INSTALL_VERSION}; then
    echo "Installing newer version ${GIT_VERSION} from Github"
    _install_energi3
  else
    echo "Latest version of Energi3 is installed: ${INSTALL_VERSION}"
    echo "Nothing to install"
    sleep 0.3
  fi

}

_copy_keystore() {

  # Copy Energi3 keystore file to computer
  if [[ ! -d "${HOME}/Library/EnergiCore3/keystore" ]]
  then
    mkdir -p "${HOME}/Library/EnergiCore3/keystore"
  fi
  clear
  echo
  echo "Copy the Gen 3 address file into the keystore directory.  You can open it by doing the following:"
  echo
  echo "Finder -> Menubar (top of screen) -> Go -> Utilities, open Terminal, type/paste in "
  echo "open \"${HOME}/Library/EnergiCore3/keystore\" "
  echo
  read -t 10 -p "Wait 10 sec or Press [ENTER] key to continue..."

}

_start_energi3 () {

  # Start energi3
  EXTERNALIP=`curl -s https://ifconfig.me/`


}

_stop_energi3 () {

  # Check if energi3 process is running and stop it
  
  ENERGI3PID=`ps -ef | grep energi3 | grep console | grep -v "grep energi3" | grep -v "color=auto" | awk '{print $2}' `
    

}


_ascii_logo () {
  echo "${GREEN}"
  clear 2> /dev/null
  cat << "ENERGI3"
      ___
     /\  \
    /::\  \
   /:/\:\__\
  /:/ /:/ _/_
 /:/ /:/ /\__\  ______ _   _ ______ _____   _____ _____ ____  
 \:\ \/ /:/  / |  ____| \ | |  ____|  __ \ / ____|_   _|___ \ 
  \:\  /:/  /  | |__  |  \| | |__  | |__) | |  __  | |   __) |
   \:\/:/  /   |  __| | . ` |  __| |  _  /| | |_ | | |  |__ < 
    \::/  /    | |____| |\  | |____| | \ \| |__| |_| |_ ___) |
     \/__/     |______|_| \_|______|_|  \_\\_____|_____|____/ 
ENERGI3
echo -n ${NC}
}

_ascii_logo_bottom () {
  echo "${GREEN}"
  clear 2> /dev/null
  cat << "ENERGI3"
      ___
     /\  \
    /::\  \
   /:/\:\__\
  /:/ /:/ _/_
 /:/ /:/ /\__\  ______ _   _ ______ _____   _____ _____ ____  
 \:\ \/ /:/  / |  ____| \ | |  ____|  __ \ / ____|_   _|___ \ 
  \:\  /:/  /  | |__  |  \| | |__  | |__) | |  __  | |   __) |
   \:\/:/  /   |  __| | . ` |  __| |  _  /| | |_ | | |  |__ < 
    \::/  /    | |____| |\  | |____| | \ \| |__| |_| |_ ___) |
     \/__/     |______|_| \_|______|_|  \_\\_____|_____|____/ 
ENERGI3
echo -n ${NC}
}

_ascii_logo_2 () {
  echo "${GREEN}"
  clear 2> /dev/null
  cat << "ENERGI3"
      ___
     /\  \
    /::\  \
   /:/\:\__\
  /:/ /:/ _/_   ______ _   _ ______ _____   _____ _____ ____  
 /:/ /:/ /\__\ |  ____| \ | |  ____|  __ \ / ____|_   _|___ \ 
 \:\ \/ /:/  / | |__  |  \| | |__  | |__) | |  __  | |   __) |
  \:\  /:/  /  |  __| | . ` |  __| |  _  /| | |_ | | |  |__ < 
   \:\/:/  /   | |____| |\  | |____| | \ \| |__| |_| |_ ___) |
    \::/  /    |______|_| \_|______|_|  \_\\_____|_____|____/ 
     \/__/     
ENERGI3
echo -n ${NC}
}

_ascii_logo_3 () {
  echo "${GREEN}"
  clear 2> /dev/null
  cat << "ENERGI3"
      ___
     /\  \
    /::\  \
   /:/\:\__\    ______ _   _ ______ _____   _____ _____ ____  
  /:/ /:/ _/_  |  ____| \ | |  ____|  __ \ / ____|_   _|___ \ 
 /:/ /:/ /\__\ | |__  |  \| | |__  | |__) | |  __  | |   __) |
 \:\ \/ /:/  / |  __| | . ` |  __| |  _  /| | |_ | | |  |__ < 
  \:\  /:/  /  | |____| |\  | |____| | \ \| |__| |_| |_ ___) |
   \:\/:/  /   |______|_| \_|______|_|  \_\\_____|_____|____/ 
    \::/  /    
     \/__/     
ENERGI3
echo -n ${NC}
}

_ascii_logo_4 () {
  echo "${GREEN}"
  clear 2> /dev/null
  cat << "ENERGI3"
      ___
     /\  \
    /::\  \     ______ _   _ ______ _____   _____ _____ ____  
   /:/\:\__\   |  ____| \ | |  ____|  __ \ / ____|_   _|___ \ 
  /:/ /:/ _/_  | |__  |  \| | |__  | |__) | |  __  | |   __) |
 /:/ /:/ /\__\ |  __| | . ` |  __| |  _  /| | |_ | | |  |__ < 
 \:\ \/ /:/  / | |____| |\  | |____| | \ \| |__| |_| |_ ___) |
  \:\  /:/  /  |______|_| \_|______|_|  \_\\_____|_____|____/ 
   \:\/:/  /   
    \::/  /    
     \/__/     
ENERGI3
echo -n ${NC}
}

_ascii_logo_5 () {
  echo "${GREEN}"
  clear 2> /dev/null
  cat << "ENERGI3"
      ___
     /\  \      ______ _   _ ______ _____   _____ _____ ____  
    /::\  \    |  ____| \ | |  ____|  __ \ / ____|_   _|___ \ 
   /:/\:\__\   | |__  |  \| | |__  | |__) | |  __  | |   __) |
  /:/ /:/ _/_  |  __| | . ` |  __| |  _  /| | |_ | | |  |__ < 
 /:/ /:/ /\__\ | |____| |\  | |____| | \ \| |__| |_| |_ ___) |
 \:\ \/ /:/  / |______|_| \_|______|_|  \_\\_____|_____|____/ 
  \:\  /:/  /  
   \:\/:/  /   
    \::/  /    
     \/__/     
ENERGI3
echo -n ${NC}
}

_ascii_logo_top () {
  echo "${GREEN}"
  clear 2> /dev/null
  cat << "ENERGI3"
      ___       ______ _   _ ______ _____   _____ _____ ____  
     /\  \     |  ____| \ | |  ____|  __ \ / ____|_   _|___ \ 
    /::\  \    | |__  |  \| | |__  | |__) | |  __  | |   __) |
   /:/\:\__\   |  __| | . ` |  __| |  _  /| | |_ | | |  |__ < 
  /:/ /:/ _/_  | |____| |\  | |____| | \ \| |__| |_| |_ ___) |
 /:/ /:/ /\__\ |______|_| \_|______|_|  \_\\_____|_____|____/ 
 \:\ \/ /:/  / 
  \:\  /:/  /  
   \:\/:/  /   
    \::/  /    
     \/__/     
ENERGI3
echo -n ${NC}
}

_menu_option_new () {
  echo "${GREEN}"
  clear 2> /dev/null
  cat << "ENERGI3"
      ___       ______ _   _ ______ _____   _____ _____ ____
     /\  \     |  ____| \ | |  ____|  __ \ / ____|_   _|___ \
    /::\  \    | |__  |  \| | |__  | |__) | |  __  | |   __) |
   /:/\:\__\   |  __| | . ` |  __| |  _  /| | |_ | | |  |__ <
  /:/ /:/ _/_  | |____| |\  | |____| | \ \| |__| |_| |_ ___) |
 /:/ /:/ /\__\ |______|_| \_|______|_|  \_\\_____|_____|____/
 \:\ \/ /:/  /
ENERGI3
echo "${GREEN}  \:\  /:/  /  ${NC}Options:"
echo "${GREEN}   \:\/:/  /   ${NC}   a) New server installation of Energi3"
echo "${GREEN}    \::/  /    ${NC}"
echo "${GREEN}     \/__/     ${NC}   x) Exit without doing anything"
echo ${NC}
}

_menu_option_mig () {
  echo "${GREEN}"
  clear 2> /dev/null
  cat << "ENERGI3"
      ___       ______ _   _ ______ _____   _____ _____ ____
     /\  \     |  ____| \ | |  ____|  __ \ / ____|_   _|___ \
    /::\  \    | |__  |  \| | |__  | |__) | |  __  | |   __) |
   /:/\:\__\   |  __| | . ` |  __| |  _  /| | |_ | | |  |__ <
  /:/ /:/ _/_  | |____| |\  | |____| | \ \| |__| |_| |_ ___) |
 /:/ /:/ /\__\ |______|_| \_|______|_|  \_\\_____|_____|____/
 \:\ \/ /:/  /
ENERGI3
echo "${GREEN}  \:\  /:/  /  ${NC}Options:"
echo "${GREEN}   \:\/:/  /   ${NC}   a) Upgrade Energi v2 to v3; automatic wallet migration"
echo "${GREEN}    \::/  /    ${NC}   b) Upgrade Energi v2 to v3; manual wallet migration"
echo "${GREEN}     \/__/     ${NC}   x) Exit without doing anything"
echo ${NC}
}

_menu_option_upgrade () {
  echo "${GREEN}"
  clear 2> /dev/null
  cat << "ENERGI3"
      ___       ______ _   _ ______ _____   _____ _____ ____
     /\  \     |  ____| \ | |  ____|  __ \ / ____|_   _|___ \
    /::\  \    | |__  |  \| | |__  | |__) | |  __  | |   __) |
   /:/\:\__\   |  __| | . ` |  __| |  _  /| | |_ | | |  |__ <
  /:/ /:/ _/_  | |____| |\  | |____| | \ \| |__| |_| |_ ___) |
 /:/ /:/ /\__\ |______|_| \_|______|_|  \_\\_____|_____|____/
 \:\ \/ /:/  /
ENERGI3
echo "${GREEN}  \:\  /:/  /  ${NC}Options:"
echo "${GREEN}   \:\/:/  /   ${NC}   a) Upgrade version of Energi3"
echo "${GREEN}    \::/  /    ${NC}"
echo "${GREEN}     \/__/     ${NC}   x) Exit without doing anything"
echo ${NC}
}

_welcome_instructions () {
  echo "${GREEN}"
  clear 2> /dev/null
  cat << "ENERGI3"
      ___       ______ _   _ ______ _____   _____ _____ ____
     /\  \     |  ____| \ | |  ____|  __ \ / ____|_   _|___ \
    /::\  \    | |__  |  \| | |__  | |__) | |  __  | |   __) |
   /:/\:\__\   |  __| | . ` |  __| |  _  /| | |_ | | |  |__ <
  /:/ /:/ _/_  | |____| |\  | |____| | \ \| |__| |_| |_ ___) |
 /:/ /:/ /\__\ |______|_| \_|______|_|  \_\\_____|_____|____/
 \:\ \/ /:/  /
ENERGI3
echo "${GREEN}  \:\  /:/  /  ${NC}Welcome to the Energi3 Installer."
echo "${GREEN}   \:\/:/  /   ${NC}- New Install : No previous installs"
echo "${GREEN}    \::/  /    ${NC}- Upgrade     : Upgrade previous version"
echo "${GREEN}     \/__/ "
echo ${NC}
read -t 10 -p "Wait 10 sec or Press [ENTER] key to continue..."
}

_end_instructions () {
  echo "${GREEN}"
  clear 2> /dev/null
  cat << "ENERGI3"
      ___       ______ _   _ ______ _____   _____ _____ ____
     /\  \     |  ____| \ | |  ____|  __ \ / ____|_   _|___ \
    /::\  \    | |__  |  \| | |__  | |__) | |  __  | |   __) |
   /:/\:\__\   |  __| | . ` |  __| |  _  /| | |_ | | |  |__ <
  /:/ /:/ _/_  | |____| |\  | |____| | \ \| |__| |_| |_ ___) |
 /:/ /:/ /\__\ |______|_| \_|______|_|  \_\\_____|_____|____/
 \:\ \/ /:/  /
ENERGI3
echo "${GREEN}  \:\  /:/  /  ${NC}Thank you for supporting Energi! Good luck staking."
echo "${GREEN}   \:\/:/  /   ${NC}Run the following script to start/stop the Node:"
echo "${GREEN}    \::/  /    ${NC}- start_node.sh    Use the script to start the Node"
echo "${GREEN}     \/__/     ${NC}- stop_node.sh     Use the script to stop the Node"
echo ${NC}
echo "For instructions visit: ${DOC_URL}"
echo
}


### ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ ###
# Main Program
### ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ ###

# Make installer interactive and select normal mode by default.

while [[ $# -gt 0 ]]
do
  key="$1"
  shift

  case $key in
    -a|--advanced)
        ADVANCED="y"
        ;;
    -n|--normal)
        ADVANCED="n"
        UFW="y"
        BOOTSTRAP="y"
        ;;
    -i|--externalip)
        EXTERNALIP="$2"
        ARGUMENTIP="y"
        shift
        ;;
    --bindip)
        BINDIP="$2"
        shift
        ;;
    -k|--privatekey)
        KEY="$2"
        shift
        ;;
    -b|--bootstrap)
        BOOTSTRAP="y"
        ;;
    --no-bootstrap)
        BOOTSTRAP="n"
        ;;
    --no-interaction)
        INTERACTIVE="n"
        ;;
    -d|--debug)
        set -x
        ;;
    -h|--help)
        cat << EOL

Energi3 installer arguments:
    -n --normal               : Run installer in normal mode
    -a --advanced             : Run installer in advanced mode
    --no-interaction          : Do not wait for wallet activation
    -i --externalip <address> : Public IP address of VPS
    --bindip <address>        : Internal bind IP to use
    -k --privatekey <key>     : Private key to use
    -b --bootstrap            : Sync node using Bootstrap
    --no-bootstrap            : Do not use Bootstrap
    -h --help                 : Display this help text
    -d --debug                : Debug mode

EOL
        exit
        ;;
    *)
        $0 -h
        ;;
  esac
done


#
# Clears screen and present Energi3 logo
_ascii_logo_bottom
sleep 0.2
_ascii_logo_2
sleep 0.2
_ascii_logo_3
sleep 0.2
_ascii_logo_4
sleep 0.2
_ascii_logo_5
sleep 0.2
_welcome_instructions

# Check architecture
_os_arch

# Check Install type and set ENERGI3_HOME
echo
echo "Checking system..."
_check_install
#read -t 10 -p "Wait 10 sec or Press [ENTER] key to continue..."

# Present menu to choose an option based on Installation Type determined
case ${INSTALLTYPE} in
  new)
    # ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    # Scenario:
    #   * No energi3.ipc file on the computer
    #   * No energi.conf file on the computer
    #
    # Menu Options
    #   a) New server installation of Energi3
    #   x) Exit without doing anything
    # ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

    _menu_option_new
    
    REPLY='x'
    read -p "Please select an option to get started (a or x): " -r
    REPLY=$( echo "${REPLY}" | tr '[:upper:]' '[:lower:]' )

    if [ "${REPLY}" = "" ]
    then
      REPLY='h'
    fi
    echo "test"
    case ${REPLY} in
      a)
        # New server installation of Energi3
        
        _setup_appdir
        _install_energi3
        
        REPLY=''
        read -p "Do you want to download keystore account file to the computer (y/[n])?: " -r
        REPLY=$( echo "${REPLY}" | tr '[:upper:]' '[:lower:]' )

        if [[ "${REPLY}" == 'y' ]]
        then
          _copy_keystore
        fi
        
        ;;
        
      x)
        # Exit - Nothing to do
        echo
        echo
        echo "Nothing to install.  Exiting from the installer."
        exit 0
    
        ;;
  
      h)
        echo
        echo
        echo "${RED}ERROR: ${NC}Need to select one of the options to continue..."
        echo
        echo "Restart the installer"
        exit 0
        ;;

    esac
      
    ;;
  
  upgrade)
    # ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    # Scenario:
    #   * energi3.ipc file exists
    #   * Keystore file exists
    #   * Version on computer is older than version in Github
    #   * $ENERGI3_HOME/etc/migrated_to_v3.log exists
    #
    # Menu Options
    #   a) Upgrade version of Energi3
    #   x) Exit without doing anything
    # ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    
    _menu_option_upgrade
    
    REPLY='x'
    read -p "Please select an option to get started (a or x): " -r
    REPLY=$( echo "${REPLY}" | tr '[:upper:]' '[:lower:]' )
    
    if [ "x${REPLY}" = "x" ]
    then
      REPLY='h'
    fi
    
    case ${REPLY} in
      a)
        # Upgrade version of Energi3
        
        _setup_appdir
        _upgrade_energi3
        
        ;;
      
      b)
        # Install monitoring on Discord and/or Telegram
        echo "Monitoring functionality to be added"
        ;;
        
      x)
        # Exit - Nothing to do
        echo
        echo
        echo "Nothing to install.  Exiting from the installer."
        exit 0
        ;;
  
      h)
        echo
        echo
        echo "${RED}ERROR: ${NC}Need to select one of the options to continue..."
        echo
        echo "Restart the installer"
        exit 0
        ;;
        
    esac
    ;;

esac

##
# End installer
##
_end_instructions


# End of Installer