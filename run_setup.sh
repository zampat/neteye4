#!/bin/bash

FOLDER_MONITORING_AGENT_MICROSOFT="/data/neteyeshare/Monitoring/Agents/Microsoft/Icinga"
ICINGA2_AGENT_VERSION="2.9.2"

echo "[ ] Creating folder structure"
mkdir -p $FOLDER_MONITORING_AGENT_MICROSOFT

#Copy files
if [ ! -d /data/neteyeshare/Monitoring/Extra_Icinga2_Configs ]
then
   echo "[ ] Copy content of Extra_Icinga2_Configs"
   cp -r Monitoring/Extra_Icinga2_Configs /data/neteyeshare/Monitoring
fi

echo "[ ] Get Monitoring Agents: Microsoft"
cd $FOLDER_MONITORING_AGENT_MICROSOFT

if [ ! -f icinga2-v$ICINGA2_AGENT_VERSION-x86_64-symbols.zip ]
then
   wget https://packages.icinga.com/windows/icinga2-v$ICINGA2_AGENT_VERSION-x86_64-symbols.zip 
   wget https://packages.icinga.com/windows/icinga2-v$ICINGA2_AGENT_VERSION-x86-symbols.zip
else
   echo "Icinga2 agent already installed"
fi

echo "[ ] Download latest version of Icinga2 Agent installation PS1 script for Windows"
echo "[!] Please rename Icinga2Agent.psm1 to Icinga2Agent.ps1"
echo "[!] Append Director self service API key and parameters at the end."
wget https://raw.githubusercontent.com/Icinga/icinga2-powershell-module/master/Icinga2Agent/Icinga2Agent.psm1


