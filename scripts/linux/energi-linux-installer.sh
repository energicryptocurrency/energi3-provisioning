#!/bin/bash

######################################################################
# Copyright (c) 2021
# All rights reserved.
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND.
#
# Desc:   Batch script to download and setup Energi v3 on Linux. The
#         script will upgrade an existing installation. 
# 
# Version:
#   1.2.9  20200309  ZA Initial Script
#   1.2.12 20200311  ZA added removedb to upgrade
#   1.2.14 20200312  ZA added create keystore if not downloading
#   1.2.15 20200423  ZA bug in _add_nrgstaker
#   1.3.0  20200521  ZA migrate to energi binary name; merge RPi
#   1.3.1  20210120  ZA update keystore download
#   1.3.2  20210121  ZA update to set API_URL externally
#   1.3.3  20200129  ZA bug fix and enhancements; supports both v3.0.x and v3.1+
#   1.3.4  20200204  ZA systemd service filename for v3.0.x updated
#   1.3.5  20200205  ZA Updated --help
#   1.3.6  20200208  ZA Add: create log directory in systemd
#   1.3.7  20200209  ZA MR Comments
#   1.3.8  20200212  ZA Bug in 2FA set up
#   1.3.9  20210407  ZA Update --mine to --mine=1 for v3.0.8
#   1.3.10 20210817  ZA Update for v3.1.0; no change in binary name
#
: '
# Run the script to get started:
```
bash -ic "$(wget -4qO- -o- raw.githubusercontent.com/energicryptocurrency/energi3-provisioning/master/scripts/linux/energi-linux-installer.sh)" ['' arguments]; source ~/.bashrc

Syntax: energi-linux-installer.sh ['' arguments]
Energi installer arguments (optional):
    -b  --bootstrap           : Sync node using Bootstrap
    -t  --testnet             : Setup testnet
    -r  --rsa                 : Setup token based login
    -f  --2fa                 : Setup 2-Factor Authentication
    -rf --rm2fa               : Remove 2-Factor Authentication
    -h  --help                : Display this help text
    -d  --debug               : Debug mode
```
'
######################################################################


### ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ ###
# Global Variables
### ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ ###

# Check if we have enough memory
if [[ $(LC_ALL=C free -m | awk '/^Mem:/{print $2}') -lt 850 ]]; then
  echo "This installation requires at least 1GB of RAM.";
  exit 1
fi

# OS Settings
export DEBIAN_FRONTEND=noninteractive 

# Locations of Repositories and Guide
export API_URL=${API_URL:-"https://api.github.com/repos/energicryptocurrency/energi3/releases/latest"}
# Production
export BASE_URL=${BASE_URL:-"raw.githubusercontent.com/energicryptocurrency/energi3-provisioning/master/scripts"}
#==> For testing set environment variable
#BASE_URL="raw.githubusercontent.com/zalam003/EnergiCore3/master/production/scripts"
SCRIPT_URL="${BASE_URL}/linux"
TP_URL="${BASE_URL}/thirdparty"
DOC_URL="https://support.energi.world/"
export S3URL=${S3URL:-"https://s3-us-west-2.amazonaws.com/download.energi.software/releases/energi3"}

# Externalize NODE_MAX_PEERS
export NODE_MAX_PEERS=${NODE_MAX_PEERS:-128}

# Set Executables & Configuration
export ENERGI_CONF=energi.toml
export ENERGI_IPC=energi3.ipc
# Check Github for URL of latest version
if [ -z "${GIT_VERSION_NUM}" ]
then
  GITHUB_LATEST=$( curl -s ${API_URL} )
  GIT_VERSION_TAG=$( echo "${GITHUB_LATEST}" | jq -r '.tag_name' )
  
  # Extract latest version number without the 'v'
  GIT_VERSION_NUM=$( echo ${GIT_VERSION_TAG} | sed 's/v//g' )
fi

# Set colors
BLUE=`tput setaf 4`
RED=`tput setaf 1`
GREEN=`tput setaf 2`
YELLOW=`tput setaf 2`
NC=`tput sgr0`

# Wait times
WAIT_LOGO=0.2
WAIT_EXEC=0.3
WAIT_DISPLAY=0.5

### ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ ###
# Functions
### ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ ###

_os_arch () {

  # Check Architecture
  OSNAME=`grep ^NAME /etc/os-release | awk -F\" '{ print $2 }'`
  OSVERSIONLONG=`grep ^VERSION_ID /etc/os-release | awk -F\" '{ print $2 }'`
  OSVERSION=`echo ${OSVERSIONLONG} | awk -F\. '{ print $1 }'`
  echo -n "${OSNAME} ${OSVERSIONLONG} is  "
  if [ "${OSNAME}" = "Ubuntu" ] && [ ${OSVERSION} -ge 18 ]
  then
    echo "${GREEN}supported${NC}"
  elif [ "${OSNAME}" = "Raspbian GNU/Linux" ]
  then
    echo "${GREEN}supported${NC}"
  else
    echo "${RED}not supported${NC}"
    exit 0
  fi
  
  echo -n "OS architecture "
  OSPLATFORM=`uname -m`
  if [ "${OSPLATFORM}" = "x86_64" ]
  then
    echo "${GREEN}${OSPLATFORM} is supported${NC}"
    OSARCH=amd64
    sleep ${WAIT_EXEC}
  elif [ "${OSPLATFORM}" = "i686" ]
  then
    echo "${GREEN}${OSPLATFORM} is supported${NC}"
    OSARCH=i686
    sleep ${WAIT_EXEC}
  elif [ "${OSPLATFORM}" = "aarch64" ]
  then
    echo "${GREEN}${OSPLATFORM} is supported${NC}"
    OSARCH=armv8
    sleep ${WAIT_EXEC}
  elif [ "${OSPLATFORM}" = "armv7l" ]
  then
    echo "${GREEN}${OSPLATFORM} is supported${NC}"
    OSARCH=armv7
    sleep ${WAIT_EXEC}
  else
    echo "${RED}${OSPLATFORM} is not supported with the installer${NC}"
    echo "Please check our website for supported platforms."
    echo
    echo "   https://support.energi.world/hc/en-us/articles/360049082491-Energi-Core-Node-Downloads"
    echo
    exit 0
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

_version_gt() { 

  # Check if FIRST version is greater than SECOND version
  test "$(printf '%s\n' "$@" | sort -V | head -n 1)" != "$1"; 
  
}

_add_nrgstaker () {
  
  # Check if user nrgstaker exists if not add the user
  
  CHKPASSWD=`grep ${USRNAME} /etc/passwd`
  
  if [ "${CHKPASSWD}" == "" ]
  then
      if [ ! -x "$( command -v pwgen )" ]
      then
        echo "Installing missing package to generate random password"
        ${SUDO} apt-get update
        ${SUDO} apt-get upgrade -y
        ${SUDO} apt-get install -yq pwgen
      fi
      
      USRPASSWD=`pwgen 12 1`
      clear
      echo
      echo "The following username / password is needed for future login."
      echo "Please write down the following before continuing!!!"
      echo "  Username: ${GREEN}${USRNAME}${NC}"
      echo "  Password: ${GREEN}${USRPASSWD}${NC}"
      echo
      REPLY=''
      read -p "Did you write down the username and password? y/[n]: "
      REPLY=${REPLY,,} # tolower
      if [[ "${REPLY}" == "n" ]] || [[ -z "${REPLY}" ]]
      then
        echo
        echo "Exiting script without creating the user account!!!"
        echo
        exit 0
      fi
      
      ${SUDO} adduser --gecos "Energi Staking Account" --disabled-password --quiet ${USRNAME}
      echo -e "${USRPASSWD}\n${USRPASSWD}" | ${SUDO} passwd ${USRNAME} 2>/dev/null
  fi

  export USRHOME=`grep "^${USRNAME}:" /etc/passwd | awk -F: '{print $6}'`
  export ENERGI_HOME=${USRHOME}/${ENERGI_EXE}
  
  ${SUDO} usermod -aG sudo ${USRNAME}
  ${SUDO} touch /home/${USRNAME}/.sudo_as_admin_successful
  ${SUDO} chmod 644 /home/${USRNAME}/.sudo_as_admin_successful
  
  if [[ ! -f /etc/sudoers.d/${USRNAME} ]]
  then
    cat << SUDO_CONF | sudo tee /etc/sudoers.d/${USRNAME} >/dev/null
${USRNAME} ALL=NOPASSWD: ALL
SUDO_CONF

  fi
  
  if [[ ${EUID} = 0 ]]
  then
      chown ${USRNAME}:${USRNAME} /home/${USRNAME}/.sudo_as_admin_successful
  fi

  # Check if there PATH variable is set
  CHKBASHRC=`grep "${ENERGIPATH} PATH" "${USRHOME}/.bashrc"`
  if [ -z "${CHKBASHRC}" ]
  then
    echo "" >> "${USRHOME}/.bashrc"
    echo "# ${ENERGIPATH} PATH" >> "${USRHOME}/.bashrc"
    echo "export PATH=\${PATH}:\${HOME}/${ENERGI_EXE}/bin" >> "${USRHOME}/.bashrc"
    echo
    echo "  .bashrc updated with PATH variable"
    if [[ $EUID != 0 ]]
    then
      source ${USRHOME}/.bashrc
    fi
  else
    echo "  .bashrc up to date. Nothing to add"
  fi
  
  echo
  echo "${GREEN}*** User ${USRNAME} created and added to sudoer group                       ***${NC}"
  echo "${GREEN}*** User ${USRNAME} will be used to install the software and configurations ***${NC}"
  sleep ${WAIT_EXEC}
  
}

_check_install () {

  # Check if run as root or user has sudo privilidges
  
  _check_runas
  
  CHKV3USRTMP=/tmp/chk_v3_usr.tmp
  >${CHKV3USRTMP}
  ${SUDO} find /home -name nodekey | awk -F\/ '{print $3}' > ${CHKV3USRTMP}
  ${SUDO} find /root -name nodekey | awk -F\/ '{print $3}' >> ${CHKV3USRTMP}
  V3USRCOUNT=`wc -l ${CHKV3USRTMP} | awk '{ print $1 }'`
  
  case ${V3USRCOUNT} in
  
    0)
      
      # New Installation:
      #   * No energi3.ipc file on the computer
      #   * No energi.conf or energid on the computer
      #
      echo "${YELLOW}Not installed${NC}"
      echo

      # Set username
      export USRNAME=nrgstaker
      INSTALLTYPE=new
      
      _add_nrgstaker
      ;;
      
    1)
      
      # Upgrade existing version of Energi:
      #   * One instance of Energi is already installed
      #   * nodekey file exists
      #   * Version on computer is older than version in Github
      
      export USRNAME=`cat ${CHKV3USRTMP}`
      INSTALLTYPE=upgrade
      echo "The script will upgrade to the latest version of energi from Github"
      echo "if available as user: ${GREEN}${USRNAME}${NC}"
      sleep ${WAIT_EXEC}
      
      export USRHOME=`grep "^${USRNAME}:" /etc/passwd | awk -F: '{print $6}'`
      export ENERGI_HOME=${USRHOME}/${ENERGI_EXE}
      ;;
  
    *)
      
      # Upgrade existing version of Energi:
      #   * More than one instance of Energi is already installed
      #   * energi3.ipc file exists
      #   * Version on computer is older than version in Github
      #   * User selects which instance to upgrade
      
      I=1
      for U in `cat ${CHKV3USRTMP}`
      do
        #echo "${U}"
        USR[${I}]=${U}
        echo "${I}: ${USR[${I}]}"
        ((I=I+1))
        if [ ${I} = ${V3USRCOUNT} ]
        then
          break
        fi
      done
      REPLY=""
      read -p "Select with user name to upgrade: " REPLY
      
      if [ ${REPLY} -le ${V3USRCOUNT} ]
      then
        export USRNAME=${USR[${REPLY}]}
        
        if [[ "${USRNAME}" -ne "${RUNAS}" ]]
        then
          clear
          echo "You have to run the script as root or ${USRNAME}"
          echo "Login as ${USRNAME} and run the script again"
          echo "Exiting script..."
          exit 0
        fi
              
        INSTALLTYPE=upgrade
        
        export USRHOME=`grep "^${USRNAME}:" /etc/passwd | awk -F: '{print $6}'`
        export ENERGI_HOME=${USRHOME}/${ENERGI_EXE}

      else
        echo "${RED}Invalid entry:${NC} Enter a number less than or equal to ${V3USRCOUNT}"
        echo "               Starting over"
        _check_install
      fi
      
      echo "Upgrading Energi as ${USRNAME}"
      ;;
  
  esac
  
  # Clean-up temporary file
  rm ${CHKV3USRTMP}

}

_setup_appdir () {

  # Check Github for URL of latest version
  if [ -z "${GIT_VERSION_NUM}" ]
  then
    GITHUB_LATEST=$( curl -s ${API_URL} )
    GIT_VERSION=$( echo "${GITHUB_LATEST}" | jq -r '.tag_name' )
    
    # Extract latest version number without the 'v'
    GIT_VERSION_NUM=$( echo ${GIT_VERSION} | sed 's/v//g' )
  
    # Check if v3.1+ is available on Github - Keep same for v3.1.0
    #if _version_gt ${GIT_VERSION_NUM} 3.0.99; then
    #  ENERGI_EXE=energi
    #  ENERGI_HOME=${USRHOME}/${ENERGI_EXE}    
    #
    #else
    ENERGI_EXE=energi3
    ENERGI_HOME=${USRHOME}/${ENERGI_EXE}
    #fi
  fi

  # Setup application directories if does not exist  
  echo "Energi will be installed in ${ENERGI_HOME}"
  sleep ${WAIT_DISPLAY}
  # Set application directories
  export BIN_DIR=${ENERGI_HOME}/bin
  export ETC_DIR=${ENERGI_HOME}/etc
  export JS_DIR=${ENERGI_HOME}/js
  export PW_DIR=${ENERGI_HOME}/.secure
  export TMP_DIR=${ENERGI_HOME}/tmp

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
  echo "Changing ownership of ${ENERGI_HOME} to ${USRNAME}"
  if [[ ${EUID} = 0 ]]
  then
    chown -R ${USRNAME}:${USRNAME} ${ENERGI_HOME}
  fi
  
}

_set_ismainnet () {

  # Default: Mainnet
  # If -t or --testnet argument is passed, isMainnet=n
  
  if [[ "${INSTALLTYPE}" == "new" ]]
  then
    if [[ "${isMainnet}" == 'y' ]] || [[ -z "${isMainnet}" ]]
    then
      export CONF_DIR=${USRHOME}/.energicore3
      export FWPORT=39797
      export APPARG=''
      export BOOTSTRAP_URL="https://s3-us-west-2.amazonaws.com/download.energi.software/releases/chaindata/mainnet/gen3-chaindata.tar.gz"
      export NEXUS_URL="https://nexus.energi.network/"
      echo "Core Node will be setup for Mainnet"
    else
      export CONF_DIR=${USRHOME}/.energicore3/testnet
      export FWPORT=49797
      export APPARG='--testnet'
      export isMainnet="n"
      export BOOTSTRAP_URL="https://s3-us-west-2.amazonaws.com/download.energi.software/releases/chaindata/testnet/gen3-chaindata.tar.gz"
      export NEXUS_URL="https://nexus.test.energi.network/"
      echo "Core Node will be setup for Testnet"
    fi

  elif [[ "${INSTALLTYPE}" == 'upgrade' ]]
  then
    if [[ -d "${USRHOME}/.energicore3/testnet" ]]
    then
      export CONF_DIR=${USRHOME}/.energicore3/testnet
      export FWPORT=49797
      export APPARG='--testnet'
      export isMainnet="n"
      export BOOTSTRAP_URL="https://s3-us-west-2.amazonaws.com/download.energi.software/releases/chaindata/testnet/gen3-chaindata.tar.gz"
      export NEXUS_URL="https://nexus.test.energi.network/"
      echo "Core Node will be setup for Testnet"
      
    else
      export CONF_DIR=${USRHOME}/.energicore3
      export FWPORT=39797
      export BOOTSTRAP_URL="https://s3-us-west-2.amazonaws.com/download.energi.software/releases/chaindata/mainnet/gen3-chaindata.tar.gz"
      export NEXUS_URL="https://nexus.energi.network/"
      echo "Core Node will be setup for Mainnet"
      
    fi

  fi
  echo
  sleep ${WAIT_EXEC}
}

_install_apt () {

  # Check if any apt packages need installing or upgrade
  # Setup server to auto updating security related packages automatically
  
  if [ ! -x "$( command -v aria2c )" ] || [ ! -x "$( command -v unattended-upgrade )" ] || [ ! -x "$( command -v ntpdate )" ] || [ ! -x "$( command -v google-authenticator )" ] || [ ! -x "$( command -v php )" ] || [ ! -x "$( command -v jq )" ]  || [ ! -x "$( command -v qrencode )" ]
  then
    echo
    echo "Updating linux first."
    echo "    Running apt-get update."
    sleep ${WAIT_DISPLAY}
    ${SUDO} apt-get update -yq 2> /dev/null
    echo "    Running apt-get upgrade."
    sleep ${WAIT_DISPLAY}
    ${SUDO} apt-get upgrade -yq 2> /dev/null
    echo "    Running apt-get dist-upgrade."
    sleep ${WAIT_DISPLAY}
    ${SUDO} apt-get -yq -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" dist-upgrade 2> /dev/null

    if [ ! -x "$( command -v unattended-upgrade )" ]
    then
      echo "    Running apt-get install unattended-upgrades php ufw."
      sleep ${WAIT_DISPLAY}
      ${SUDO} apt-get install -yq unattended-upgrades php ufw 2> /dev/null
      
      if [ ! -f /etc/apt/apt.conf.d/20auto-upgrades ]
      then
        # Enable auto updating of Ubuntu security packages.
        echo "Setting up server to update security related packages anytime they are available"
        sleep ${WAIT_EXEC}
        cat << UBUNTU_SECURITY_PACKAGES | ${SUDO} tee /etc/apt/apt.conf.d/20auto-upgrades >/dev/null
APT::Periodic::Enable "1";
APT::Periodic::Download-Upgradeable-Packages "1";
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";
UBUNTU_SECURITY_PACKAGES

      fi
    fi
  fi
  
  # Install missing programs if needed.
  if [ ! -x "$( command -v aria2c )" ]
  then
    echo "    Installing missing programs..."
    ${SUDO} apt-get install -yq \
      curl \
      lsof \
      util-linux \
      gzip \
      unzip \
      unrar \
      xz-utils \
      procps \
      htop \
      git \
      gpw \
      bc \
      pv \
      sysstat \
      glances \
      psmisc \
      at \
      subnetcalc \
      net-tools \
      sipcalc \
      python-yaml \
      html-xml-utils \
      apparmor \
      ack-grep \
      pcregrep \
      snapd \
      aria2 \
      dbus-user-session 2> /dev/null
  fi
  
  if [ ! -x "$( command -v jq )" ]
  then
    echo "    Installing jq"
    ${SUDO} apt-get install -yq jq 2> /dev/null
  fi
  echo "    Installing nodejs"
  ${SUDO} apt-get install -yq nodejs 2> /dev/null
  
  echo "    Removing apt files not required"
  ${SUDO} apt autoremove -y 2> /dev/null
  
}

_add_logrotate () {

  # Setup log rotate
  # Logs in $HOME/.energicore3 will rotate automatically when it reaches 100M
  if [ ! -f /etc/logrotate.d/${ENERGI_EXE} ]
  then
    echo "Setting up log maintenance for energi"
    if [[ ! -d ${CONF_DIR}/energi3/log ]]
    then
      mkdir ${CONF_DIR}/energi3/log
      if [[ ${EUID} = 0 ]]
      then
        chown -R ${USRNAME}:${USRNAME} ${CONF_DIR}/energi3/log
      fi
      sleep ${WAIT_EXEC}
    fi
    cat << ENERGI_LOGROTATE | ${SUDO} tee /etc/logrotate.d/${ENERGI_EXE} >/dev/null
${CONF_DIR}/energi3/log/*.log {
  su ${USRNAME} ${USRNAME}
  rotate 3
  minsize 100M
  copytruncate
  compress
  missingok
}
ENERGI_LOGROTATE

  logrotate -f /etc/logrotate.d/${ENERGI_EXE}
  
  fi
}

_add_systemd () {

  # Setup systemd for autostart

  if [ ! -f /lib/systemd/system/${ENERGI_EXE}.service ]
  then
    echo "Setting up systemctl to automatically start energi after reboot..."
    if [[ ! -d ${CONF_DIR}/energi3/log ]]
    then
        ${SUDO} mkdir -p ${CONF_DIR}/energi3/log
        ${SUDO} chown ${USRNAME}:${USRNAME} ${CONF_DIR}/energi3/log
        ${SUDO} touch ${CONF_DIR}/energi3/log/energi_stdout.log
        ${SUDO} chown ${USRNAME}:${USRNAME} ${CONF_DIR}/energi3/log/energi_stdout.log
        ${SUDO} chmod 640 ${CONF_DIR}/energi3/log/energi_stdout.log
        ${SUDO} chmod 750 ${CONF_DIR}/energi3/log
    fi
    sleep ${WAIT_EXEC}
    EXTIP=`curl -s https://ifconfig.me/`
    cat << SYSTEMD_CONF | ${SUDO} tee /lib/systemd/system/${ENERGI_EXE}.service >/dev/null
[Unit]
Description=Energi Core Node Service
After=syslog.target network.target

[Service]
SyslogIdentifier=${ENERGI_EXE}
PermissionsStartOnly=true
Type=simple
Restart=always
RestartSec=5
User=${USRNAME}
Group=${USRNAME}
UMask=0027
StandardOutput=file:${CONF_DIR}/energi3/log/energi_stdout.log
StandardError=file:${CONF_DIR}/energi3/log/energi_stdout.log
ExecStart=${BIN_DIR}/${ENERGI_EXE} ${APPARG} \\
  --datadir ${CONF_DIR} \\
  --gcmode archive \\
  --maxpeers ${NODE_MAX_PEERS} \\
  --masternode \\
  --mine=1 \\
  --nat extip:${EXTIP} \\
  --verbosity 0
WorkingDirectory=${USRHOME}

[Install]
WantedBy=multi-user.target
SYSTEMD_CONF

    if [[ ! -d ${CONF_DIR}/energi3/log ]]
    then
      mkdir -p ${CONF_DIR}/energi3/log
      touch ${CONF_DIR}/energi3/log/energi_stdout.log
      ${SUDO} chown -R ${USRNAME}:${USRNAME} ${CONF_DIR}/energi3/log
    fi
    echo "    Enabling energi service"
    ${SUDO} systemctl enable energi

  fi
}

_install_energi () {

  # Download and install node software and supporting scripts

  # Name of scripts
  JS_SCRIPT=utils.js
  
  # Check Github for URL of latest version
  if [ -z "${GIT_VERSION_NUM}" ]
  then
    GITHUB_LATEST=$( curl -s ${API_URL} )
    GIT_VERSION=$( echo "${GITHUB_LATEST}" | jq -r '.tag_name' )
    
    # Extract latest version number without the 'v'
    GIT_VERSION_NUM=$( echo ${GIT_VERSION} | sed 's/v//g' )
  
    # Check if v3.1+ is available on Github
    #if _version_gt ${GIT_VERSION_NUM} 3.0.99; then
    #  ENERGI_EXE=energi
    #  ENERGI_HOME=${USRHOME}/${ENERGI_EXE}
    #else
    ENERGI_EXE=energi3
    ENERGI_HOME=${USRHOME}/${ENERGI_EXE}
    #fi
  fi
  
  # Download from repositogy
  echo "Downloading Energi Core Node v${GIT_VERSION_NUM} and scripts"
  
  cd ${USRHOME}
  # Download energi from Amazon S3
  wget -4qo- "${S3URL}/${GIT_VERSION_NUM}/${ENERGI_EXE}-${GIT_VERSION_NUM}-linux-${OSARCH}.tgz" --show-progress --progress=bar:force:noscroll 2>&1
  sleep ${WAIT_EXEC}
  
  tar xvfz ${ENERGI_EXE}-${GIT_VERSION_NUM}-linux-${OSARCH}.tgz
  sleep ${WAIT_EXEC}
  
  # Copy latest energi and cleanup
  if [[ -x "${BIN_DIR}/${ENERGI_EXE}" ]]
  then
    mv ${ENERGI_EXE}-${GIT_VERSION_NUM}-linux-${OSARCH}/bin/${ENERGI_EXE} ${BIN_DIR}/.
    rm -rf ${ENERGI_EXE}-${GIT_VERSION_NUM}-linux-${OSARCH}
  else
    mv ${ENERGI_EXE}-${GIT_VERSION_NUM}-linux-${OSARCH} ${ENERGI_EXE}
  fi
  rm ${ENERGI_EXE}-${GIT_VERSION_NUM}-linux-${OSARCH}.tgz
  
  # Check if software downloaded
  if [ ! -d ${BIN_DIR} ]
  then
    echo "${RED}ERROR: ${ENERGI_EXE} did not install${NC}"
    sleep 5
  fi
  
  # Create missing app directories
  _setup_appdir
  
  cd ${BIN_DIR}

  chmod 755 ${ENERGI_EXE}
  if [[ ${EUID} = 0 ]]
  then
    chown ${USRNAME}:${USRNAME} ${ENERGI_EXE}
  fi
  
  # Clean-up
  if [[ -d ${ENERGI_HOME}.old ]]
  then
    rm -rf ${ENERGI_HOME}.old
  fi
  
  # Change to install directory
  cd
  
}

_upgrade_energi () {
  
  # Check Github for URL of latest version
  if [ -z "${GIT_VERSION_NUM}" ]
  then
    GITHUB_LATEST=$( curl -s ${API_URL} )
    GIT_VERSION=$( echo "${GITHUB_LATEST}" | jq -r '.tag_name' )
    
    # Extract latest version number without the 'v'
    GIT_VERSION_NUM=$( echo ${GIT_VERSION} | sed 's/v//g' )
  fi
  
  # Check if v3.1+ is available on Github
  #if _version_gt ${GIT_VERSION_NUM} 3.0.99; then

    # Rename energi3 if 3.1.x and above is released
    #if [[ -d ${USRHOME}/energi3 ]]
    #then
    #        
    #  export ENERGI_EXE=energi
    #  export ENERGI_HOME="${USRHOME}/${ENERGI_EXE}"
    #  
    #  mv ${USRHOME}/energi3/bin/energi3 ${USRHOME}/energi3/bin/energi
    #  mv ${USRHOME}/energi3 ${USRHOME}/energi
    #  if [[ -f /etc/logrotate.d/energi3 ]]
    #  then
    #    ${SUDO} rm /etc/logrotate.d/energi3
    #  fi
    #  
    #  if [[ -f /lib/systemd/system/energi3.service ]]
    #  then
    #    ${SUDO} systemctl disable energi3.service
    #    ${SUDO} rm /lib/systemd/system/energi3.service
    #  fi
    #  
    #  # Update PATH variable for Energi
    #  CHKBASHRC=`grep "Energi3 PATH" "${USRHOME}/.bashrc"`
    #  if [ ! -z "${CHKBASHRC}" ]
    #  then
    #    sed -i 's/Energi3/Energi/g' "${USRHOME}/.bashrc"
    #    sed -i 's/energi3/energi/g' "${USRHOME}/.bashrc"
    #    source ${USRHOME}/.bashrc
    #  fi
    #fi
    
  #else
  ENERGI_EXE=energi3
  ENERGI_HOME=${USRHOME}/${ENERGI_EXE}
    
  #fi 
  
  # Set PATH to energi
  export BIN_DIR=${ENERGI_HOME}/bin
  
  # Installed Version
  INSTALL_VERSION=$( ${BIN_DIR}/${ENERGI_EXE} version 2>/dev/null | grep "^Version" | awk '{ print $2 }' | awk -F\- '{ print $1 }' )
  if [[ -z ${INSTALL_VERSION} ]]
  then
  
    # Cannot determine install version
    echo "${RED}Cannot determine the version installed on the VPS."
    echo "${RED}Exiting installer.${NC}"
    exit 10
  
  fi
  
  # Check if the version in Github requires removedb
  if _version_gt ${GIT_VERSION_NUM} ${INSTALL_VERSION}
  then
    echo "Installing newer version ${GIT_VERSION} from Github"
    if [[ -f "${CONF_DIR}/removedb-list.db" ]]
    then
      rm -f ${CONF_DIR}/removedb-list.db
      wget -4qo- "${BASE_URL}/utils/removedb-list.db?dl=1" -O "${CONF_DIR}/removedb-list.db" --show-progress --progress=bar:force:noscroll 2>&1
    else
      wget -4qo- "${BASE_URL}/utils/removedb-list.db?dl=1" -O "${CONF_DIR}/removedb-list.db" --show-progress --progress=bar:force:noscroll 2>&1 
    fi
    
    if [[ $EUID = 0 ]]
    then
      chown ${USRNAME}:${USRNAME} ${CONF_DIR}/removedb-list.db
    fi
    
    _install_energi
    
  else
    echo "Latest version of Energi is installed: ${INSTALL_VERSION}"
    echo "Nothing to install"
    sleep ${WAIT_EXEC}
    
  fi

}

_restrict_logins() {

  # Secure server by restricting who can login
  
  # Have linux passwords show stars.
  if [[ -f /etc/sudoers ]] && [[ $( ${SUDO} grep -c 'env_reset,pwfeedback' /etc/sudoers ) -eq 0 ]]
  then
    echo "Show password feeback."
    ${SUDO} cat /etc/sudoers | sed -r 's/^Defaults(\s+)env_reset$/Defaults\1env_reset,pwfeedback/' | sudo EDITOR='tee ' visudo >/dev/null
    echo "Restarting ssh."
    ${SUDO} systemctl restart sshd
    sleep ${WAIT_EXEC}
    SSHSTATUS=`${SUDO} systemctl status sshd | grep Active | awk '{print $2}'`
    if [ "${SSHSTATUS}" != "active" ]
    then
      echo "${RED}CRITICAL: sshd did not start correctly. Check configuration file${NC}"
      sleep ${WAIT_DISPLAY}
    fi
  fi

  USRS_THAT_CAN_LOGIN=$( whoami )
  USRS_THAT_CAN_LOGIN="root ${USRNAME} ${USRS_THAT_CAN_LOGIN}"
  USRS_THAT_CAN_LOGIN=$( echo "${USRS_THAT_CAN_LOGIN}" | xargs -n1 | sort -u | xargs )
  ALL_USERS=$( cut -d: -f1 /etc/passwd )

  BOTH_LISTS=$( sort <( echo "${USRS_THAT_CAN_LOGIN}" | tr " " '\n' ) <( echo "${ALL_USERS}" | tr " " '\n' ) | uniq -d | grep -Ev "^$" )
  if [[ $( grep -cE '^AllowUsers' /etc/ssh/sshd_config ) -gt 0 ]]
  then
    USRS_THAT_CAN_LOGIN_2=$( grep -E '^AllowUsers' /etc/ssh/sshd_config | sed -e 's/^AllowUsers //g' )
    BOTH_LISTS=$( echo ${USRS_THAT_CAN_LOGIN_2} ${BOTH_LISTS} | xargs -n1 | sort -u | xargs )
    MISSING_FROM_LISTS=$( join -v 2 <(sort <( echo "${USRS_THAT_CAN_LOGIN_2}" | tr " " '\n' ))  <(sort <( echo "${BOTH_LISTS}" | tr " " '\n' ) ))
  else
    MISSING_FROM_LISTS=${BOTH_LISTS}
  fi
  if [[ -z "${BOTH_LISTS}" ]]
  then
    echo "User login can not be restricted."
    return
  fi
  if [[ -z "${MISSING_FROM_LISTS}" ]]
  then
    # Do nothing if no users are missing.
    return
  fi
  echo
  echo ${BOTH_LISTS}
  REPLY='y'
#  read -p "Make it so only the above list of users can login via SSH ([y]/n)?: " -r
#  REPLY=${REPLY,,} # tolower
  echo "Only the above list of users can login via SSH"
  sleep ${WAIT_EXEC}
  if [[ "${REPLY}" == 'y' ]] || [[ -z "${REPLY}" ]]
  then
    if [[ $( grep -cE '^AllowUsers' /etc/ssh/sshd_config ) -eq 0 ]]
    then
      ${SUDO} echo "AllowUsers "${BOTH_LISTS} >> /etc/ssh/sshd_config
    else
      ${SUDO} sed -ie "/AllowUsers/ s/$/ ${MISSING_FROM_LISTS} /" /etc/ssh/sshd_config
    fi
    USRS_THAT_CAN_LOGIN=$( grep -E '^AllowUsers' /etc/ssh/sshd_config | sed -e 's/^AllowUsers //g' | tr " " '\n' )
    echo "Restarting ssh."
    ${SUDO} systemctl restart sshd
    sleep ${WAIT_EXEC}
    SSHSTATUS=`${SUDO} systemctl status sshd | grep Active | awk '{print $2}'`
    if [ "${SSHSTATUS}" != "active" ]
    then
      echo "${RED}CRITICAL: sshd did not start correctly. Check configuration file${NC}"
      sleep ${WAIT_DISPLAY}
    fi
    echo "List of users that can login via SSH (/etc/ssh/sshd_config):"
    echo ${USRS_THAT_CAN_LOGIN}
  fi
  
}

_secure_host() {

  # Enable Local Firewall
  if [[ ! -x "$( command -v ufw )" ]]
  then
    echo "Installing missing package to secure server"
    ${SUDO} apt-get install -yq ufw 2:/dev/null
  fi
  
  echo "Limiting secure shell (ssh) to access servers and RPC port ${FWPORT} to access Energi Node"
  ${SUDO} ufw allow ssh/tcp
  ${SUDO} ufw limit ssh/tcp
  if [ ! -z "${FWPORT}" ]
  then
    ${SUDO} ufw allow ${FWPORT}/tcp
    ${SUDO} ufw allow ${FWPORT}/udp
  fi
  ${SUDO} ufw logging on
  ${SUDO} ufw --force enable
  
}

_remove_two_factor() {

  local ETC_DIR=${USRHOME}/etc

  # Remove 2FA from USRHOME
  if [[ -f "${USRHOME}/.google_authenticator" ]]
  then
      rm -f "${USRHOME}/.google_authenticator"
      if [[ ! -f "${ETC_DIR}/otp.php" ]]
      then
          rm -rf "${ETC_DIR}"
      fi
      echo "2FA has been removed for user ${USRNAME}!"
  fi
  
}

_setup_two_factor() {

  # Setup 2FA for USRNAME
  ${SUDO} service apache2 stop 2>/dev/null
  ${SUDO} update-rc.d apache2 disable 2>/dev/null
  ${SUDO} update-rc.d apache2 remove 2>/dev/null
  
  local ETC_DIR=${USRHOME}/etc

  # Ask to review if .google_authenticator file already exists.
  if [[ -s "${USRHOME}/.google_authenticator" ]]
  then
    REPLY=''
    read -p "Review 2 factor authentication code for password SSH login (y/[n])?: " -r
    REPLY=${REPLY,,} # tolower
    if [[ "${REPLY}" == 'n' ]] || [[ -z "${REPLY}" ]]
    then
      return
    fi
  fi

  # Clear out an old failed run.
  if [[ -f "${USRHOME}/.google_authenticator.temp" ]]
  then
    rm "${USRHOME}/.google_authenticator.temp"
  fi

  # Install google-authenticator if not there.
  NEW_PACKAGES=''
  if [ ! -x "$( command -v google-authenticator )" ]
  then
    NEW_PACKAGES="${NEW_PACKAGES} libpam-google-authenticator"
  fi
  if [ ! -x "$( command -v php )" ]
  then
    NEW_PACKAGES="${NEW_PACKAGES} php-cli"
  fi
  if [ ! -x "$( command -v qrencode )" ]
  then
    NEW_PACKAGES="${NEW_PACKAGES} qrencode"
  fi
  if [[ ! -z "${NEW_PACKAGES}" ]]
  then
    echo "Installing ${NEW_PACKAGES}"
    ${SUDO} apt-get install -yq ${NEW_PACKAGES} 2>/dev/null

    ${SUDO} service apache2 stop 2>/dev/null
    ${SUDO} update-rc.d apache2 disable 2>/dev/null
    ${SUDO} update-rc.d apache2 remove 2>/dev/null
  fi

  if [[ ! -f "${ETC_DIR}/otp.php" ]]
  then
    if [[ ! -d "${ETC_DIR}" ]]
    then
        mkdir -p "${ETC_DIR}"
    fi
   
    cd ${ETC_DIR}
    echo "${TP_URL}/otp.php"
    wget -4qo- ${TP_URL}/otp.php -O "${ETC_DIR}/otp.php" --show-progress --progress=bar:force:noscroll 2>&1
    chmod 644 "${ETC_DIR}/otp.php"
    cd -
  fi
  
  if [[ ${EUID} = 0 ]]
  then
    chown -R ${USRNAME}:${USRNAME} "${ETC_DIR}"
  fi

  # Generate otp.
  IP_ADDRESS=$( timeout --signal=SIGKILL 10s curl -s http://ipinfo.io/ip )
  SECRET=''
  if [[ -f "${USRHOME}/.google_authenticator" ]]
  then
    SECRET=$( ${SUDO} head -n 1 "${USRHOME}/.google_authenticator" 2>/dev/null )
  fi
  if [[ -z "${SECRET}" ]]
  then
    if [[ ${EUID} = 0 ]]
    then
      su - ${USRNAME} -c 'google-authenticator -t -d -f -r 10 -R 30 -w 5 -q -Q UTF8 -l "ssh login for '${USRNAME}'"'
    else
      google-authenticator -t -d -f -r 10 -R 30 -w 5 -q -Q UTF8 -l "ssh login for '${USRNAME}'"
    fi  
    # Add 5 recovery digits.
    {
    head -200 /dev/urandom | cksum | tr -d ' ' | cut -c1-8 ;
    head -200 /dev/urandom | cksum | tr -d ' ' | cut -c1-8 ;
    head -200 /dev/urandom | cksum | tr -d ' ' | cut -c1-8 ;
    head -200 /dev/urandom | cksum | tr -d ' ' | cut -c1-8 ;
    head -200 /dev/urandom | cksum | tr -d ' ' | cut -c1-8 ;
    } | ${SUDO} tee -a  "${USRHOME}/.google_authenticator" >/dev/null
    SECRET=$( ${SUDO} head -n 1 "${USRHOME}/.google_authenticator" 2>/dev/null )
  fi
  
  if [[ -z "${SECRET}" ]]
  then
    echo "Google Authenticator install failed."
    return
  fi
  
  if [[ -f "${USRHOME}/.google_authenticator" ]]
  then
    mv "${USRHOME}/.google_authenticator" "${USRHOME}/.google_authenticator.temp"
    CHMOD_G_AUTH=$( stat --format '%a' ${USRHOME}/.google_authenticator.temp )
    chmod 666 "${USRHOME}/.google_authenticator.temp"
  else
    CHMOD_G_AUTH=400
  fi
  clear

  stty sane 2>/dev/null
  echo "Warning: pasting the following URL into your browser exposes the OTP secret to Google:"
  echo "https://www.google.com/chart?chs=200x200&chld=M|0&cht=qr&chl=otpauth://totp/ssh%2520login%2520for%2520'${USRNAME}'%3Fsecret%3D${SECRET}%26issuer%3D${IP_ADDRESS}"
  echo
  
  stty sane 2>/dev/null
  qrencode -l L -m 2 -t UTF8 "otpauth://totp/ssh%20login%20for%20'${USRNAME}'?secret=${SECRET}&issuer=${IP_ADDRESS}"
  stty sane 2>/dev/null
  
  echo "Scan the QR code with the Google Authenticator app; or manually enter"
  echo "Account: ${USRNAME}@${IP_ADDRESS}"
  echo "Key: ${SECRET}"
  echo "This is a time based code"
  echo "When logging into this VPS via password, a 6 digit code would also be required."
  echo "If you loose this code you can still use your wallet on your desktop."
  echo
  
  # Validate otp.
  while :
  do
    REPLY=''
    read -p "6 digit verification code (leave blank to disable & delete): " -r
    if [[ -z "${REPLY}" ]]
    then
      rm -f "${USRHOME}/.google_authenticator"
      rm -f "${USRHOME}/.google_authenticator.temp"
      echo "Not going to use google authenticator."
      return
    fi

    KEY_CHECK=$( php "${ETC_DIR}/otp.php" "${REPLY}" "${USRHOME}/.google_authenticator.temp" )
    if [[ ! -z "${KEY_CHECK}" ]]
    then
      echo "${KEY_CHECK}"
      if [[ $( echo "${KEY_CHECK}" | grep -ic 'Key Verified' ) -gt 0 ]]
      then
        break
      fi
    fi
  done

  if [[ -f "${USRHOME}/.google_authenticator.temp" ]]
  then
    chmod "${CHMOD_G_AUTH}" "${USRHOME}/.google_authenticator.temp"
    if [[ ${EUID} = 0 ]]
    then
      chown ${USRNAME}:${USRNAME} "${USRHOME}/.google_authenticator.temp"
    fi
    mv "${USRHOME}/.google_authenticator.temp" "${USRHOME}/.google_authenticator"
  fi

  echo "Your emergency scratch codes are (write these down in a safe place):"
  grep -oE "[0-9]{8}" "${USRHOME}/.google_authenticator" | awk '{print "  " $1 }'

  read -r -p $'Use this 2 factor code \e[7m(y/n)\e[0m? ' -e 2>&1
  REPLY=${REPLY,,} # tolower
  if [[ "${REPLY}" == 'y' ]]
  then
    if [[ $( grep -c 'auth required pam_google_authenticator.so nullok' /etc/pam.d/sshd ) -eq 0 ]]
    then
      echo "auth required pam_google_authenticator.so nullok" | ${SUDO} tee -a "/etc/pam.d/sshd" >/dev/null
    fi
    ${SUDO} sed -ie 's/ChallengeResponseAuthentication no/ChallengeResponseAuthentication yes/g' /etc/ssh/sshd_config
    ${SUDO} systemctl restart sshd.service
    echo
    echo "If using Bitvise select keyboard-interactive with no submethods selected."
    echo

    # Allow for 20 bad root login attempts before killing the ip.
    if [[ -f /etc/denyhosts.conf ]]
    then
      ${SUDO} sed -ie 's/DENY_THRESHOLD_ROOT \= 1/DENY_THRESHOLD_ROOT = 5/g' /etc/denyhosts.conf
      ${SUDO} sed -ie 's/DENY_THRESHOLD_RESTRICTED \= 1/DENY_THRESHOLD_RESTRICTED = 5/g' /etc/denyhosts.conf
      ${SUDO} sed -ie 's/DENY_THRESHOLD_ROOT \= 1/DENY_THRESHOLD_ROOT = 20/g' /etc/denyhosts.conf
      ${SUDO} sed -ie 's/DENY_THRESHOLD_RESTRICTED \= 1/DENY_THRESHOLD_RESTRICTED = 20/g' /etc/denyhosts.conf
      ${SUDO} systemctl restart denyhosts
    fi
    sleep 5
    clear
  else
    rm -f "${USRHOME}/.google_authenticator"
  fi

}

_add_rsa_key() {
  while :
  do
    TEMP_RSA_FILE=$( mktemp )
    printf "Enter the PUBLIC ssh key (starts with ssh-rsa AAAA) and press [ENTER]:\n\n"
    read -r SSH_RSA_PUBKEY
    if [[ "${#SSH_RSA_PUBKEY}" -lt 10 ]]
    then
      echo "Quiting without adding rsa key."
      echo
      break
    fi
    echo "${SSH_RSA_PUBKEY}" >> "${TEMP_RSA_FILE}"
    SSH_TEST=$( ssh-keygen -l -f "${TEMP_RSA_FILE}"  2>/dev/null )
    if [[ "${#SSH_TEST}" -gt 10 ]]
    then
      if [[ ! -d "${USRHOME}/.ssh" ]]
      then
        mkdir -p "${USRHOME}/.ssh"
      fi
      touch "${USRHOME}/.ssh/authorized_keys"
      chmod 644 "${USRHOME}/.ssh/authorized_keys"
      echo "${SSH_RSA_PUBKEY}" >> "${USRHOME}/.ssh/authorized_keys"
      if [[ ${EUID} = 0 ]]
      then
        chown -R ${USRNAME}:${USRNAME} "${USRHOME}/.ssh"
        chmod 700 "${USRHOME}/.ssh"
      fi
      echo "Added ${SSH_TEST}"
      echo
      break
    fi

    rm -rf "${TEMP_RSA_FILE}"
  done
}

_check_clock() {
  if [ ! -x "$( command -v ntpdate )" ]
  then
    echo "Installing ntpdate"
    ${SUDO} apt-get install -yq ntpdate 2>/dev/null
  fi
  echo "Checking system clock..."
  ${SUDO} ntpdate -q pool.ntp.org | tail -n 1 | grep -o 'offset.*' | awk '{print $1 ": " $2 " " $3 }' 2>/dev/null
}

_add_swap () {
  # Add 2GB additional swap
  if [ ! -f /var/swapfile ]
  then
    echo "Adding additional swap"
    ${SUDO} fallocate -l 2G /var/swapfile
    ${SUDO} chmod 600 /var/swapfile
    ${SUDO} mkswap /var/swapfile
    ${SUDO} swapon /var/swapfile

    ${SUDO} echo -e "/var/swapfile\t none\t swap\t sw\t 0\t 0" >> /etc/fstab
    echo "Added 2GB swap space to the server"
  else
    echo "Swap already exists. No additional swap space added."
  fi
}

_copy_keystore() {

  # Copy Energi keystore file to computer
  while :
  do
    TEMP_KS_FILE=$( mktemp )
    printf "Copy and Paste the content of your keystore file and press [ENTER]:\n\n"
    read -r KEYSTORECONTENT
    if [[ "${#KEYSTORECONTENT}" -lt 10 ]]
    then
      echo "Quiting without adding keystore file."
      echo
      break
    fi
    echo "${KEYSTORECONTENT}" >> "${TEMP_KS_FILE}"
    
    KEYSTOREACCT=$( cat "${TEMP_KS_FILE}" | jq -r '.address' )
    KEYSTOREFILE="UTC--`date --utc +%Y-%m-%dT%H-%M-%S.%NZ`--${KEYSTOREACCT}"
    
    # Create keystore directory if needed
    if [ -d ${CONF_DIR}/keystore ]
    then
      # Temporarily change permissions
      ${SUDO} chmod 777 ${CONF_DIR}/keystore
      KEYSTORE_EXIST=`find ${CONF_DIR}/keystore -name "*${KEYSTOREACCT}" -print`
    else
      mkdir -p ${CONF_DIR}/keystore
      KEYSTORE_EXIST=''
    fi
    
    # Check if a keystore file is already present.
    if [[ ! -z "${KEYSTORE_EXIST}" ]]
    then
      echo "Backing up ${KEYSTORE_EXIST} file"
      mkdir -p ${ENERGI_HOME}/backups
      mv "${CONF_DIR}/keystore/${KEYSTORE_EXIST}" "${ENERGI_HOME}/backups/${KEYSTORE_EXIST}.bak"
      if [[ ${EUID} = 0 ]]
      then      
        chown "${USRNAME}":"${USRNAME}" ${ENERGI_HOME}/backups
      fi
    fi
    
    # Move and rename key file
    mv "${TEMP_KS_FILE}" "${CONF_DIR}/keystore/${KEYSTOREFILE}"

    # Check if file is installed
    ACCTNUM="0x`echo ${KEYSTOREACCT}`"
    if [[ -z "${CONF_DIR}/keystore/${KEYSTOREFILE}" ]]
    then
      echo "Copy failed; try again."
      REPLY=''
      continue
    else
      # Change ownership if installing as root
      if [[ ${EUID} = 0 ]]
      then
        chown -R "${USRNAME}":"${USRNAME}" "${CONF_DIR}"
      fi
      chmod 700 ${CONF_DIR}/keystore
      chmod 600 "${CONF_DIR}/keystore/${KEYSTOREFILE}"
    fi
    
    echo "Keystore Account ${ACCTNUM} copied to:"
    echo "${CONF_DIR}/keystore on VPS"
    echo
    
  done

}

_download_bootstrap () {
  
  # Download latest bootstrap and extract it
  echo "Downloading latest bootstrap..."
  sleep 5
  cd ${USRHOME}
  curl -s ${BOOTSTRAP_URL} | tar xvz

  # Change ownership if downloaded as root
  if [[ ${EUID} = 0 ]]
  then
    echo "  Changing ownership to ${USRNAME}"
    chown -R "${USRNAME}":"${USRNAME}" ${USRHOME}/.energicore3
  fi

}

_start_energi () {

  # Start energi
  
  if [[ -f /lib/systemd/system/energi.service ]]
  then
    SYSTEMCTLSTATUS=`systemctl status energi.service | grep "Active:" | awk '{print $2}'`
    if [[ "${SYSTEMCTLSTATUS}" != "active" ]]
    then
      echo "Starting Energi Core Node...."
      ${SUDO} systemctl daemon-reload
      sleep ${WAIT_EXEC}
      ${SUDO} systemctl start energi.service
    else
      echo "energi service is running..."
    fi
    
  elif [[ -f /lib/systemd/system/energi3.service ]]
  then
    SYSTEMCTLSTATUS=`systemctl status energi3.service | grep "Active:" | awk '{print $2}'`
    if [[ "${SYSTEMCTLSTATUS}" != "active" ]]
    then
      echo "Starting Energi Core Node...."
      ${SUDO} systemctl daemon-reload
      sleep ${WAIT_EXEC}
      ${SUDO} systemctl start energi3.service
    else
      echo "energi service is running..."
    fi  
  fi

}

_stop_energi () {

  # Check if energi process is running and stop it

  if [[ -f /lib/systemd/system/energi.service ]]
  then  
    
    SYSTEMCTLSTATUS=`systemctl status energi.service | grep "Active:" | awk '{print $2}'`
    if [[ "${SYSTEMCTLSTATUS}" = "active" ]]
    then
      echo "Stopping Energi Core Node..."
      ${SUDO} systemctl stop energi.service
      sleep ${WAIT_EXEC}
    else
      echo "energi service is not running..."
    fi
    
  elif [[ -f /lib/systemd/system/energi3.service ]]
  then  
    
    SYSTEMCTLSTATUS=`systemctl status energi3.service | grep "Active:" | awk '{print $2}'`
    if [[ "${SYSTEMCTLSTATUS}" = "active" ]]
    then
      echo "Stopping Energi3 Core Node..."
      ${SUDO} systemctl stop energi3.service
      sleep ${WAIT_EXEC}
    else
      echo "energi3 service is not running..."
    fi
  fi

}

_get_enode () {

  # Print enode of core node
  
  # Wait 60 sec or till energi3.ipc socket file is present
  I=1
  while [ ! -S ${CONF_DIR}/energi3.ipc ] || [ ${I} = 60 ]
  do
    sleep ${WAIT_DISPLAY}
    ((I++))
  done
  sleep ${WAIT_EXEC}
  
  if [[ ${EUID} = 0 ]] && [[ -S ${CONF_DIR}/energi3.ipc ]]
  then
    echo "${GREEN}To Announce Masternode go to:${NC} ${NEXUS_URL}"
    echo -n "Owner Address: "
    su - ${USRNAME} -c "${BIN_DIR}/${ENERGI_EXE} ${APPARG} attach -exec 'personal.listAccounts' " 2>/dev/null | jq -r '.[]' | head -1
    echo "Masternode enode URL: "
    su - ${USRNAME} -c "${BIN_DIR}/${ENERGI_EXE} ${APPARG} attach -exec 'admin.nodeInfo.enode' " 2>/dev/null | jq -r
  
  else
    echo "${GREEN}To Announce Masternode go to:${NC} ${NEXUS_URL}"
    echo -n "Owner Address: "
    ${ENERGI_EXE} ${APPARG} attach -exec "personal.listAccounts" 2>/dev/null | jq -r '.[]' | head -1
    echo "Masternode enode URL: "
    ${ENERGI_EXE} ${APPARG} attach -exec "admin.nodeInfo.enode" 2>/dev/null | jq -r
  
  fi
  
  # Add space
  echo

}

_stop_nodemon () {
  
  # Check if nodemon is running. If so, stop it
  
  NODEMONSTATUS=`systemctl status nodemon.timer | grep "Active:" | awk '{print $2}'`
  
  if [[ "${NODEMONSTATUS}" = "active" ]]
  then
    echo "Stopping nodemon service for Energi"
    ${SUDO} systemctl stop nodemon.timer

  fi

}

_start_nodemon () {
  
  # If nodemon is installed, start it
  if [ -f /etc/systemd/system/nodemon.timer ]
  then
    echo "Starting nodemon service for Energi"
    ${SUDO} systemctl daemon-reload
    ${SUDO} systemctl start nodemon.timer

  fi

}

_ascii_logo () {
  echo "${GREEN}"
  clear 2> /dev/null
  cat << "ENERGI"
      ___
     /\  \
    /::\  \
   /:/\:\__\
  /:/ /:/ _/_
 /:/ /:/ /\__\  ______ _   _ ______ _____   _____ _____ 
 \:\ \/ /:/  / |  ____| \ | |  ____|  __ \ / ____|_   _|
  \:\  /:/  /  | |__  |  \| | |__  | |__) | |  __  | |  
   \:\/:/  /   |  __| | . ` |  __| |  _  /| | |_ | | |  
    \::/  /    | |____| |\  | |____| | \ \| |__| |_| |_ 
     \/__/     |______|_| \_|______|_|  \_\\_____|_____|
ENERGI
echo -n ${NC}
}

_ascii_logo_bottom () {
  echo "${GREEN}"
  clear 2> /dev/null
  cat << "ENERGI"
      ___
     /\  \
    /::\  \
   /:/\:\__\
  /:/ /:/ _/_
 /:/ /:/ /\__\  ______ _   _ ______ _____   _____ _____ 
 \:\ \/ /:/  / |  ____| \ | |  ____|  __ \ / ____|_   _|
  \:\  /:/  /  | |__  |  \| | |__  | |__) | |  __  | |  
   \:\/:/  /   |  __| | . ` |  __| |  _  /| | |_ | | |  
    \::/  /    | |____| |\  | |____| | \ \| |__| |_| |_ 
     \/__/     |______|_| \_|______|_|  \_\\_____|_____|
ENERGI
echo -n ${NC}
}

_ascii_logo_2 () {
  echo "${GREEN}"
  clear 2> /dev/null
  cat << "ENERGI"
      ___
     /\  \
    /::\  \
   /:/\:\__\
  /:/ /:/ _/_   ______ _   _ ______ _____   _____ _____ 
 /:/ /:/ /\__\ |  ____| \ | |  ____|  __ \ / ____|_   _|
 \:\ \/ /:/  / | |__  |  \| | |__  | |__) | |  __  | |  
  \:\  /:/  /  |  __| | . ` |  __| |  _  /| | |_ | | |  
   \:\/:/  /   | |____| |\  | |____| | \ \| |__| |_| |_ 
    \::/  /    |______|_| \_|______|_|  \_\\_____|_____|
     \/__/     
ENERGI
echo -n ${NC}
}

_ascii_logo_3 () {
  echo "${GREEN}"
  clear 2> /dev/null
  cat << "ENERGI"
      ___
     /\  \
    /::\  \
   /:/\:\__\    ______ _   _ ______ _____   _____ _____ 
  /:/ /:/ _/_  |  ____| \ | |  ____|  __ \ / ____|_   _|
 /:/ /:/ /\__\ | |__  |  \| | |__  | |__) | |  __  | |  
 \:\ \/ /:/  / |  __| | . ` |  __| |  _  /| | |_ | | |  
  \:\  /:/  /  | |____| |\  | |____| | \ \| |__| |_| |_ 
   \:\/:/  /   |______|_| \_|______|_|  \_\\_____|_____|
    \::/  /    
     \/__/     
ENERGI
echo -n ${NC}
}

_ascii_logo_4 () {
  echo "${GREEN}"
  clear 2> /dev/null
  cat << "ENERGI"
      ___
     /\  \
    /::\  \     ______ _   _ ______ _____   _____ _____ 
   /:/\:\__\   |  ____| \ | |  ____|  __ \ / ____|_   _|
  /:/ /:/ _/_  | |__  |  \| | |__  | |__) | |  __  | |  
 /:/ /:/ /\__\ |  __| | . ` |  __| |  _  /| | |_ | | |  
 \:\ \/ /:/  / | |____| |\  | |____| | \ \| |__| |_| |_ 
  \:\  /:/  /  |______|_| \_|______|_|  \_\\_____|_____|
   \:\/:/  /   
    \::/  /    
     \/__/     
ENERGI
echo -n ${NC}
}

_ascii_logo_5 () {
  echo "${GREEN}"
  clear 2> /dev/null
  cat << "ENERGI"
      ___
     /\  \      ______ _   _ ______ _____   _____ _____ 
    /::\  \    |  ____| \ | |  ____|  __ \ / ____|_   _|
   /:/\:\__\   | |__  |  \| | |__  | |__) | |  __  | |  
  /:/ /:/ _/_  |  __| | . ` |  __| |  _  /| | |_ | | |  
 /:/ /:/ /\__\ | |____| |\  | |____| | \ \| |__| |_| |_ 
 \:\ \/ /:/  / |______|_| \_|______|_|  \_\\_____|_____|
  \:\  /:/  /  
   \:\/:/  /   
    \::/  /    
     \/__/     
ENERGI
echo -n ${NC}
}

_ascii_logo_top () {
  echo "${GREEN}"
  clear 2> /dev/null
  cat << "ENERGI"
      ___       ______ _   _ ______ _____   _____ _____ 
     /\  \     |  ____| \ | |  ____|  __ \ / ____|_   _|
    /::\  \    | |__  |  \| | |__  | |__) | |  __  | |  
   /:/\:\__\   |  __| | . ` |  __| |  _  /| | |_ | | |  
  /:/ /:/ _/_  | |____| |\  | |____| | \ \| |__| |_| |_ 
 /:/ /:/ /\__\ |______|_| \_|______|_|  \_\\_____|_____| 
 \:\ \/ /:/  / 
  \:\  /:/  /  
   \:\/:/  /   
    \::/  /    
     \/__/     
ENERGI
echo -n ${NC}
}

_menu_option_new () {
  echo "${GREEN}"
  clear 2> /dev/null
  cat << "ENERGI"
      ___       ______ _   _ ______ _____   _____ _____ 
     /\  \     |  ____| \ | |  ____|  __ \ / ____|_   _|
    /::\  \    | |__  |  \| | |__  | |__) | |  __  | |  
   /:/\:\__\   |  __| | . ` |  __| |  _  /| | |_ | | |  
  /:/ /:/ _/_  | |____| |\  | |____| | \ \| |__| |_| |_ 
 /:/ /:/ /\__\ |______|_| \_|______|_|  \_\\_____|_____|
 \:\ \/ /:/  /
ENERGI
echo "${GREEN}  \:\  /:/  /  ${NC}Options:"
echo "${GREEN}   \:\/:/  /   ${NC}   a) New server installation of Energi"
echo "${GREEN}    \::/  /    ${NC}"
echo "${GREEN}     \/__/     ${NC}   x) Exit without doing anything"
echo ${NC}
}

_menu_option_upgrade () {
  echo "${GREEN}"
  clear 2> /dev/null
  cat << "ENERGI"
      ___       ______ _   _ ______ _____   _____ _____ 
     /\  \     |  ____| \ | |  ____|  __ \ / ____|_   _|
    /::\  \    | |__  |  \| | |__  | |__) | |  __  | |  
   /:/\:\__\   |  __| | . ` |  __| |  _  /| | |_ | | |  
  /:/ /:/ _/_  | |____| |\  | |____| | \ \| |__| |_| |_ 
 /:/ /:/ /\__\ |______|_| \_|______|_|  \_\\_____|_____|
 \:\ \/ /:/  /
ENERGI
echo "${GREEN}  \:\  /:/  /  ${NC}Options:"
echo "${GREEN}   \:\/:/  /   ${NC}   a) Upgrade version of Energi"
echo "${GREEN}    \::/  /    ${NC}"
echo "${GREEN}     \/__/     ${NC}   x) Exit without doing anything"
echo ${NC}
}

_welcome_instructions () {
  echo "${GREEN}"
  clear 2> /dev/null
  cat << "ENERGI"
      ___       ______ _   _ ______ _____   _____ _____ 
     /\  \     |  ____| \ | |  ____|  __ \ / ____|_   _|
    /::\  \    | |__  |  \| | |__  | |__) | |  __  | |  
   /:/\:\__\   |  __| | . ` |  __| |  _  /| | |_ | | |  
  /:/ /:/ _/_  | |____| |\  | |____| | \ \| |__| |_| |_ 
 /:/ /:/ /\__\ |______|_| \_|______|_|  \_\\_____|_____|
 \:\ \/ /:/  /
ENERGI
echo "${GREEN}  \:\  /:/  /  ${NC}Welcome to the Energi Installer."
echo "${GREEN}   \:\/:/  /   ${NC}- New Install : No previous installs"
echo "${GREEN}    \::/  /    ${NC}- Upgrade     : Upgrade previous version"
echo "${GREEN}     \/__/ "
echo ${NC}
read -t 10 -p "Wait 10 sec or Press [ENTER] key to continue..."
}

_end_instructions () {
  echo "${GREEN}"
  clear 2> /dev/null
  cat << "ENERGI"
      ___       ______ _   _ ______ _____   _____ _____ 
     /\  \     |  ____| \ | |  ____|  __ \ / ____|_   _|
    /::\  \    | |__  |  \| | |__  | |__) | |  __  | |  
   /:/\:\__\   |  __| | . ` |  __| |  _  /| | |_ | | |  
  /:/ /:/ _/_  | |____| |\  | |____| | \ \| |__| |_| |_ 
 /:/ /:/ /\__\ |______|_| \_|______|_|  \_\\_____|_____|
 \:\ \/ /:/  /
ENERGI
echo "${GREEN}  \:\  /:/  /  ${NC}Please logout and log back in as ${USRNAME}"
echo "${GREEN}   \:\/:/  /   ${NC}To start energi: sudo systemctl start ${ENERGI_EXE}"
echo "${GREEN}    \::/  /    ${NC}To stop energi : sudo systemctl stop ${ENERGI_EXE}"
echo "${GREEN}     \/__/     ${NC}For status     : sudo systemctl status ${ENERGI_EXE}"
echo ${NC}"For instructions visit: ${DOC_URL}"
echo
}


### ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ ###
# Main Program
### ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ ###

# Make installer interactive and select normal mode by default.
isMainnet="y"
INTERACTIVE="y"
BOOTSTRAP="n"
POSITIONAL=()

# Check if v3.1+ is available on Github
#if _version_gt ${GIT_VERSION_NUM} 3.0.99; then
#  export ENERGI_EXE=energi
#  export ENERGIPATH=Energi
#else
export ENERGI_EXE=energi3
export ENERGIPATH=Energi3
#fi

# Check script arguments
while [[ $# -gt 0 ]]
do
  key="$1"
  shift

  case $key in
    -b|--bootstrap)
        clear 2> /dev/null
        if [[ EUID = 0 ]]
        then
          echo "Cannot run as root.  Exiting script."
          echo
          exit 10
        fi
        _check_install
        _set_ismainnet
        _stop_nodemon
        sleep ${WAIT_EXEC}
        _stop_energi
        sleep ${WAIT_EXEC}
        ${ENERGI_EXE} ${APPARG} removedb
        sleep ${WAIT_EXEC}
        _download_bootstrap
        sleep ${WAIT_EXEC}
        _start_energi
        sleep ${WAIT_EXEC}
        _start_nodemon
        exit 0
        ;;
    -t|--testnet|-testnet)
        isMainnet="n"
        ;;
    -r|--rsa)
        clear 2> /dev/null
        if [[ EUID = 0 ]]
        then
          echo "Cannot run as root.  Exiting script."
          echo
          exit 10
        fi
        _check_install
        _add_rsa_key
        exit 0
        ;;
    -f|--2fa)
        clear 2> /dev/null
        if [[ EUID = 0 ]]
        then
          echo "Cannot run as root.  Exiting script."
          echo
          exit 10
        fi
        _check_install
        _setup_two_factor
        exit 0
        ;;
    -rf|--rm2fa)
        clear 2> /dev/null
        if [[ EUID = 0 ]]
        then
          echo "Cannot run as root.  Exiting script."
          echo
          exit 10
        fi
        _check_install
        _remove_two_factor
        exit 0
        ;;
    -d|--debug)
        set -x
        ;;
    -h|--help)
        echo
        clear 2> /dev/null
        cat << HELPMSG

Syntax: energi-linux-installer.sh ['' arguments]

arguments (optional):
    -b  --bootstrap           : Sync node using Bootstrap
    -t  --testnet             : Setup testnet
    -r  --rsa                 : Setup token based login
    -f  --2fa                 : Setup 2-Factor Authentication
    -rf --rm2fa               : Remove 2-Factor Authentication
    -h  --help                : Display this help text
    -d  --debug               : Debug mode
HELPMSG
        echo
        
        exit 0
        
        ;;
    *)
        $0 -h
        ;;
  esac
done


#
# Clears screen and present Energi logo
_ascii_logo_bottom
sleep ${WAIT_LOGO}
_ascii_logo_2
sleep ${WAIT_LOGO}
_ascii_logo_3
sleep ${WAIT_LOGO}
_ascii_logo_4
sleep ${WAIT_LOGO}
_ascii_logo_5
sleep ${WAIT_LOGO}
_welcome_instructions

# Check architecture
_os_arch

# Check Install type and set ENERGI_HOME
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
    #   a) New server installation of Energi
    #   x) Exit without doing anything
    # ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

    _menu_option_new
    
    REPLY='x'
    read -p "Please select an option to get started (a or x): " -r
    REPLY=${REPLY,,} # tolower
    if [ "${REPLY}" = "" ]
    then
      REPLY='h'
    fi
    
    case ${REPLY} in
      a)
        # New server installation of Energi
        
        # ==> Run as root / sudo <==
        _install_apt
        _restrict_logins
        _set_ismainnet
        _secure_host
        _check_clock
        _add_swap
        _add_logrotate
        
        # Check if user wants to install 2FA
        clear 2> /dev/null
        echo "2-Factor Authentication (2FA) require you to enter a 6 digit one-time password"
        echo "(OTP) after you login to the server. You need to install ${GREEN}Google Authenticator${NC}"
        echo "on your mobile to enable the 2FA. The OTP changes every 60 sec. This will secure"
        echo "your server and restrict who can login."
        echo
        
        REPLY=''
        read -p "Do you want to install 2-FA for user ${USRNAME} [Y/n]?: " -r
        REPLY=${REPLY,,} # tolower
        if [[ "${REPLY}" == 'y' ]] || [[ -z "${REPLY}" ]]
        then
          _setup_two_factor
        fi

        _install_energi
        _download_bootstrap
        
        # Check if user wants to copy keystore file to VPS
        clear 2> /dev/null
        echo "You can copy the keystore file of the account to the VPS" 
        echo "by copy and pasting the content of the keystore file."
        echo "Locate the keystore file and open it with a text editor."
        echo 
        REPLY=''
        read -p "Do you want to copy the keystore file to the VPS (y/[n])?: " -r
        REPLY=${REPLY,,} # tolower
        if [[ "${REPLY}" == 'y' ]]
        then
          _copy_keystore
        else
          if [ -d ${CONF_DIR}/keystore ]
          then
            mkdir -p ${CONF_DIR}/keystore
            chmod 700 ${CONF_DIR}/keystore
            if [[ ${EUID} = 0 ]]
            then
              chown -R "${USRNAME}":"${USRNAME}" "${CONF_DIR}"
            fi
          fi
        fi

        _add_systemd
        
        _start_energi
        
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
    #
    # Menu Options
    #   a) Upgrade version of Energi
    #   b) Instructions to install nodemon
    #   x) Exit without doing anything
    # ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    
    _menu_option_upgrade
    
    REPLY='x'
    read -p "Please select an option to get started (a or x): " -r
    REPLY=${REPLY,,} # tolower
    
    if [ "x${REPLY}" = "x" ]
    then
      REPLY='h'
    fi
    
    case ${REPLY} in
      a)
        # Upgrade version of Energi
        _stop_nodemon
        _stop_energi
        _install_apt
        _restrict_logins
        _set_ismainnet
        _secure_host
        _check_clock
        _add_swap
        _upgrade_energi
        
        if [[ -f ${CONF_DIR}/removedb-list.db ]]
        then
          for L in `cat ${CONF_DIR}/removedb-list.db`
          do
            if [[ ${L} = ${INSTALL_VERSION} ]]
            then
              echo "${GREEN}Vesion ${L} requires a reset of chaindata${NC}"
              ${BIN_DIR}/${ENERGI_EXE} removedb
              _download_bootstrap
              break
              
            elif [[ -f "${CONF_DIR}/energi3/chaindata/CURRENT" ]] && [[ ${BOOTSTRAP} = y ]]
            then
              echo "Removing chaindata..."
              rm -rf ${CONF_DIR}/energi3/chaindata/*
              _download_bootstrap
            fi
          done
        fi
        
        _add_logrotate
        _add_systemd
        _start_energi
        _start_nodemon
 
        ;;
      
      b)
        # Install nodemon
        echo
        echo
        echo "See nodemon installation guide for details"
        exit 0
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

# present enode information
_get_enode

# End of Script
##