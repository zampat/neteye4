#!/bin/bash

# Script action:
# Copy NON-product monitoring plugins from external GIT Repositories into neteyeshare/ folder
#

#Define Variables
NETEYESHARE_MONITORING="$1"
DATE=`date +%Y%m%d`

 
# Plugin 1: Nagios_Cluster.ps1
# Details : PS-Script to query info from MS-Cluster Manager
MSCLUSTER_DST_DIR="${NETEYESHARE_MONITORING}/monitoring-plugins/microsoft/failover_cluster"
MSCLUSTER_FILE="Nagios_Cluster.ps1"
MSCLUSTER_SRC="https://gist.githubusercontent.com/hpmmatuska/bc94b9e087655391b251/raw/6f634953b9399a496a2b44bdc1933c1dc099b099/Nagios_Cluster.ps1"
MSCLUSTER_REPLACE="0"



# Loop trough all Plugins
# Register all prefixes of Plugins to copy here
ELEMENTS=( MSCLUSTER )

for PLUGIN in ${ELEMENTS[@]}
do

   PLUGIN_DST_DIR=$PLUGIN\_DST_DIR
   PLUGIN_FILE=$PLUGIN\_FILE
   PLUGIN_SRC=$PLUGIN\_SRC
   PLUGIN_REPLACE=$PLUGIN\_REPLACE

   
   # Valiation: Check existency of folder PluginsContrib
   if [ ! -d "${!PLUGIN_DST_DIR}" ]
   then
      mkdir -p ${!PLUGIN_DST_DIR}
   fi

   # Check if Plugin already exists. If yes: backup first
   if [ -f ${!PLUGIN_DST_DIR}/${!PLUGIN_FILE} ]
   then
	if [ "${!PLUGIN_REPLACE}" -eq "1" ]
	then

	   echo "[+] Creating Backup of ${!PLUGIN_FILE}"
	   cp --force ${!PLUGIN_DST_DIR}/${!PLUGIN_FILE} ${!PLUGIN_DST_DIR}/${!PLUGIN_FILE}.${DATE}_bak

	   /usr/bin/wget ${!PLUGIN_SRC} -O ${!PLUGIN_DST_DIR}/${!PLUGIN_FILE}
	   echo "[i] Replaced Plugin ${!PLUGIN_FILE} from git to Plugins contrib dir: ${!PLUGIN_DST_DIR}"
	fi

   else 
      /usr/bin/wget ${!PLUGIN_SRC} -O ${!PLUGIN_DST_DIR}/${!PLUGIN_FILE}
      echo "[i] Copied Plugin ${!PLUGIN_FILE} from git to Plugins contrib dir: ${!PLUGIN_DST_DIR}"
   fi


done


echo "[i] 051: Done, copied all Non-Product monitoring plugins from GIT Repositories"

