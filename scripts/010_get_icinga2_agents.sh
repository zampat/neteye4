#!/bin/bash

FOLDER_MONITORING_AGENT_MICROSOFT="/data/neteyeshare/Monitoring/Agents/Microsoft/Icinga"
ICINGA2_AGENT_VERSION=$1

echo "[ ] Creating folder structure"
mkdir -p $FOLDER_MONITORING_AGENT_MICROSOFT

#Copy files
if [ ! -d /data/neteyeshare/Monitoring/Extra_Icinga2_Configs ]
then
   echo "[ ] Copy content of Extra_Icinga2_Configs"
   cp -r Monitoring/Extra_Icinga2_Configs /data/neteyeshare/Monitoring
fi

echo "[ ] Get Monitoring Agents: Microsoft"
#cd $FOLDER_MONITORING_AGENT_MICROSOFT

if [ ! -f $FOLDER_MONITORING_AGENT_MICROSOFT/Icinga2-v$ICINGA2_AGENT_VERSION-x86.msi ]
then
   wget https://packages.icinga.com/windows/Icinga2-v$ICINGA2_AGENT_VERSION-x86_64.msi -O ${FOLDER_MONITORING_AGENT_MICROSOFT}/Icinga2-v$ICINGA2_AGENT_VERSION-x86_64.msi
   wget https://packages.icinga.com/windows/Icinga2-v$ICINGA2_AGENT_VERSION-x86.msi -O ${FOLDER_MONITORING_AGENT_MICROSOFT}/Icinga2-v$ICINGA2_AGENT_VERSION-x86.msi
else
   echo "Icinga2 agent already installed"
fi

echo "[ ] Download latest version of Icinga2 Agent installation PS1 script for Windows"
echo "[!] Please rename Icinga2Agent.psm1 to Icinga2Agent.ps1"
echo "[!] Append Director self service API key and parameters at the end."
wget https://raw.githubusercontent.com/Icinga/icinga2-powershell-module/master/Icinga2Agent/Icinga2Agent.psm1 -O ${FOLDER_MONITORING_AGENT_MICROSOFT}/Icinga2Agent.psm1

