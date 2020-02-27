@echo OFF

::####################################################################
:: Description: Script to start Energi Core Node 3.x on Windows
::
:: Run this script
:: start_staking.bat
::####################################################################

set "ENERGI3_HOME=%ProgramFiles%\Energi Gen 3"
set "BIN_DIR=%ENERGI3_HOME%\bin"
set "JSHOME=%ENERGI3_HOME%\js"

:: Determine Version of energi3 istalled
set "VERSION="
FOR /f "tokens=1*delims=: " %%a IN ('"%BIN_DIR%\energi3.exe" version' ) DO (
 IF "%%a"=="Version" SET "VERSION=%%b"
)

:: Check to see if running on testnet or mainnet
if "%1" == "-t" (
  set "ARG=-testnet"
  set "RPCPORT=49796"
  set "WSPORT=49795
  set "DATA_DIR=EnergiCore3\testnet\energi3"
  set "LOG_DIR=%APPDATA%\EnergiCore3\testnet\log"
  @echo Starting Energi Core Node %VERSION% for Staking in testnet
) else (
  set "ARG="
  set "RPCPORT=39796"
  set "WSPORT=39795
  set "DATA_DIR=EnergiCore3\energi3"
  set "LOG_DIR=%APPDATA%\EnergiCore3\log"
  @echo Starting Energi Core Node %VERSION% for Staking
)

:: Create LOG_DIR
if not exist %LOG_DIR% (
  md %LOG_DIR%
  )

:: Find Internet facing IP address
curl -s https://ifconfig.me/ > ipaddr.tmp
set /p IP= < ipaddr.tmp
del ipaddr.tmp

::
:: Main start script
::
@echo Changing to install directory
cd "%BIN_DIR%"

%DEFAULT_EXE_LOCATION%^
    %ARG%^
    --mine^
    --preload %JSHOME%\utils.js^
    --rpc^
    --rpcport %RPCPORT%^
    --rpcaddr "127.0.0.1"^
    --rpcapi admin,eth,web3,rpc,personal,energi^
    --ws^
    --wsaddr "127.0.0.1"^
    --wsport %WSPORT%^
    --wsapi admin,eth,net,web3,personal,energi^
    --verbosity 3 console 2>> %%LOG_DIR%\energicore3.log%

pause
