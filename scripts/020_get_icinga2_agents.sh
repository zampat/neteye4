#!/bin/bash

FOLDER_MONITORING_AGENT_MICROSOFT="$1/agents/microsoft/icinga"
ICINGA2_AGENT_VERSION=$2
ICINGA2_AGENT_PS_SCRIPT="/Icinga2Agent.psm1"
SRC_GIT_AGENT_SCRIPTS_FOLDER="./monitoring/agents/microsoft/icinga"


if [ ! -f "${FOLDER_MONITORING_AGENT_MICROSOFT}/Icinga2-v$ICINGA2_AGENT_VERSION-x86.msi" ]
then
   mkdir -p $FOLDER_MONITORING_AGENT_MICROSOFT
   echo "[i] 020: Installing Icinga Monitoring Agent Version $ICINGA2_AGENT_VERSION for Microsoft"
   wget https://packages.icinga.com/windows/Icinga2-v$ICINGA2_AGENT_VERSION-x86_64.msi -O ${FOLDER_MONITORING_AGENT_MICROSOFT}/Icinga2-v$ICINGA2_AGENT_VERSION-x86_64.msi
   wget https://packages.icinga.com/windows/Icinga2-v$ICINGA2_AGENT_VERSION-x86.msi -O ${FOLDER_MONITORING_AGENT_MICROSOFT}/Icinga2-v$ICINGA2_AGENT_VERSION-x86.msi
else
   echo "[ ] 020: Icinga2 agent already installed"
fi


# Sync the Icinga2 Agent deployment scripts
if [ -d "${FOLDER_MONITORING_AGENT_MICROSOFT}" ]
then
   echo "[i] 020: Synchronizing Icinga2 Agent deployment scripts to neteyeshare (to ${FOLDER_MONITORING_AGENT_MICROSOFT})"
   /usr/bin/rsync -av ${SRC_GIT_AGENT_SCRIPTS_FOLDER}/* ${FOLDER_MONITORING_AGENT_MICROSOFT}/
   /usr/bin/rsync -av ${SRC_GIT_AGENT_SCRIPTS_FOLDER}/deployment_scripts/* ${FOLDER_MONITORING_AGENT_MICROSOFT}/deployment_scripts/
   /usr/bin/rsync -av ${SRC_GIT_AGENT_SCRIPTS_FOLDER}/icinga2-powershell-module/Icinga2Agent/Icinga2Agent.psm1 ${FOLDER_MONITORING_AGENT_MICROSOFT}/deployment_scripts/Icinga2Agent.psm1

else
   echo "[-] 020: Failed synchronization of Icinga2 agent deployment scripts. Folder: ${FOLDER_MONITORING_AGENT_MICROSOFT} does not exist."
fi
