@echo OFF

::####################################################################
:: Description: This script is to start Energi 3.x aka Gen3 in
::              Windows environment
:: Replace:     "unlock" address
::              create a file named passwd.txt with password of address
:: Run script:  run_mn_windows.bat
::####################################################################

set "ENERGI3_HOME=%ProgramFiles%\Energi Gen 3"
set "BIN_DIR=%ENERGI3_HOME%\bin"
set "DATA_DIR=EnergiCore3\energi3"

%BIN_DIR%\energi3.exe version >version.tmp
findstr /B VERSION version.tmp
del version.tmp

set "LOG_DIR=%APPDATA%\EnergiCore3\log"

if not exist %LOG_DIR% (
  md %LOG_DIR%
  )

set "BLOCKCHAIN_DIR=%APPDATA%\%DATA_DIR%"

set "DEFAULT_EXE_LOCATION=%BIN_DIR%\energi3.exe"


set "JSHOME=%ENERGI3_HOME%\js"

curl -s https://ifconfig.me/ > ipaddr.tmp
set /p IP= < ipaddr.tmp
del ipaddr.tmp

@echo Changing to install directory
cd "%BIN_DIR%"

@echo Starting Energi Core Node %VERSION% for Masternode
::    --unlock %PERSONAL_ACCOUNT%^
::    --password passwd.txt^
%windir%\system32\cmd.exe /c %DEFAULT_EXE_LOCATION%^
    --masternode^
    --nat extip:${IP}^
    --mine^
    --preload %JSHOME%\utils.js^
    --rpc^
    --rpcport 39796^
    --rpcaddr "127.0.0.1"^
    --rpcapi admin,eth,web3,rpc,personal,energi^
    --ws^
    --wsaddr "127.0.0.1"^
    --wsport 39795^
    --wsapi admin,eth,net,web3,personal,energi^
    --verbosity 3 console 2>> %LOG_DIR%\energicore3.log