#!/bin/bash

FOLDER_MONITORING_AGENT_MICROSOFT="$1/agents/microsoft/icinga"
ICINGA2_AGENT_VERSION=$2
ICINGA2_AGENT_PS_SCRIPT="/Icinga2Agent.psm1"
SRC_GIT_AGENT_SCRIPTS_FOLDER="./monitoring/agents/microsoft/icinga"


if [ ! -f "${FOLDER_MONITORING_AGENT_MICROSOFT}/Icinga2-v$ICINGA2_AGENT_VERSION-x86.msi" ]
then
   mkdir -p $FOLDER_MONITORING_AGENT_MICROSOFT
   echo "[i] Installing Icinga Monitoring Agent Version $ICINGA2_AGENT_VERSION for Microsoft"
   wget https://packages.icinga.com/windows/Icinga2-v$ICINGA2_AGENT_VERSION-x86_64.msi -O ${FOLDER_MONITORING_AGENT_MICROSOFT}/Icinga2-v$ICINGA2_AGENT_VERSION-x86_64.msi
   wget https://packages.icinga.com/windows/Icinga2-v$ICINGA2_AGENT_VERSION-x86.msi -O ${FOLDER_MONITORING_AGENT_MICROSOFT}/Icinga2-v$ICINGA2_AGENT_VERSION-x86.msi
else
   echo "[ ] Icinga2 agent already installed"
fi

if [ ! -f "${FOLDER_MONITORING_AGENT_MICROSOFT}${ICINGA2_AGENT_PS_SCRIPT}" ]
then
   echo "[ ] Download latest version of Icinga2 Agent installation PS1 script for Windows"
   echo "[!] Please rename ${ICINGA2_AGENT_PS_SCRIPT} to kickstart_icinga2_agent.ps1"
   echo "[!] Append Director self service API key and parameters at the end."
   wget https://raw.githubusercontent.com/Icinga/icinga2-powershell-module/master/Icinga2Agent/Icinga2Agent.psm1 -O ${FOLDER_MONITORING_AGENT_MICROSOFT}/${ICINGA2_AGENT_PS_SCRIPT}
else
   echo "[i] The ${ICINGA2_AGENT_PS_SCRIPT} already present in ${FOLDER_MONITORING_AGENT_MICROSOFT}"
   echo "    To update rename ${ICINGA2_AGENT_PS_SCRIPT} to ${ICINGA2_AGENT_PS_SCRIPT}.bak"
fi


# Install the Icinga2 Agent deployment scripts
if [ -d "${FOLDER_MONITORING_AGENT_MICROSOFT}" ]
then
   echo "[i] Synchronizing Icinga2 Agent deployment scripts to neteyeshare (to ${FOLDER_MONITORING_AGENT_MICROSOFT})"
   /usr/bin/rsync -av ${SRC_GIT_AGENT_SCRIPTS_FOLDER}/* ${FOLDER_MONITORING_AGENT_MICROSOFT}/
   #echo "    Done: Host icons have been installed."

else
   echo "[-] Failed synchronization of Icinga2 agent deployment scripts. Folder: ${FOLDER_MONITORING_AGENT_MICROSOFT} does not exist."
fi
