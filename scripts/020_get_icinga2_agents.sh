#!/bin/bash

FOLDER_MONITORING_AGENT_MICROSOFT="$1/agents/microsoft/icinga"
CURRENT_VERSION=$(rpm -qf /neteye/shared/share/icinga2/downloads/icinga2.msi | cut -d - -f3 | cut -d _ -f 1)
ICINGA2_AGENT_PS_SCRIPT="/Icinga2Agent.psm1"
SRC_GIT_AGENT_SCRIPTS_FOLDER="./monitoring/agents/microsoft/icinga"


if [ ! -f "${FOLDER_MONITORING_AGENT_MICROSOFT}/Icinga2-v$CURRENT_VERSION-x86_64.msi" ]
then
   mkdir -p $FOLDER_MONITORING_AGENT_MICROSOFT
   echo "[i] 020: Installing Icinga Monitoring Agent Version $CURRENT_VERSION for Microsoft"
   cp /neteye/shared/share/icinga2/downloads/icinga2.msi ${FOLDER_MONITORING_AGENT_MICROSOFT}/Icinga2-v$CURRENT_VERSION-x86_64.msi   
else
   echo "[ ] 020: Icinga2 agent already installed"
fi


# Sync the Icinga2 Agent deployment scripts
if [ -d "${FOLDER_MONITORING_AGENT_MICROSOFT}" ]
then
   echo "[i] 020: Synchronizing Icinga2 Agent deployment scripts to neteyeshare (to ${FOLDER_MONITORING_AGENT_MICROSOFT})"
   /usr/bin/rsync -av ${SRC_GIT_AGENT_SCRIPTS_FOLDER}/* ${FOLDER_MONITORING_AGENT_MICROSOFT}/
   /usr/bin/rsync -av ${SRC_GIT_AGENT_SCRIPTS_FOLDER}/deployment_batch ${FOLDER_MONITORING_AGENT_MICROSOFT}/
   /usr/bin/rsync -av ${SRC_GIT_AGENT_SCRIPTS_FOLDER}/deployment_remexec ${FOLDER_MONITORING_AGENT_MICROSOFT}/
   /usr/bin/rsync -av ${SRC_GIT_AGENT_SCRIPTS_FOLDER}/icinga2-powershell-module/Icinga2Agent/Icinga2Agent.psm1 ${FOLDER_MONITORING_AGENT_MICROSOFT}/icinga2-powershell-module/Icinga2Agent.psm1

else
   echo "[-] 020: Failed synchronization of Icinga2 agent deployment scripts. Folder: ${FOLDER_MONITORING_AGENT_MICROSOFT} does not exist."
fi

