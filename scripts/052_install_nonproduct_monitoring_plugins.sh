#!/bin/bash

# Script action: 
# Copy NON-product monitoring plugins into PluginsContribDir/ folder
#

# MONITORING_PLUGINS_CONTRIB_DIR="/neteye/local/monitoring/plugins"
MONITORING_PLUGINS_CONTRIB_DIR="$1"
DATE=`date +%Y%m%d`

#Define the monitoring-plugins from GIT to copy into PluginsContribDir/

# Plugin 1: check_interfaces
# Details : C-Based light script for interface traffic monitoring without any use of cache files
INTERFACES_SRC="./monitoring/monitoring-plugins/network-devices/interfaces/check_interfaces"
INTERFACES_FILE="check_interfaces"

# Plugin 2: check_mem.pl
# Details : Memory check (local) Linux/Unix systems
MEMORY_SRC="./monitoring/monitoring-plugins/linux_unix/check_mem.pl"
MEMORY_FILE="check_mem.pl"

# Valiation: Check existency of folder PluginsContrib
if [ ! -d "${MONITORING_PLUGINS_CONTRIB_DIR}" ]
then
   mkdir -p ${MONITORING_PLUGINS_CONTRIB_DIR}
fi


# Loop trough all Plugins
# Register all prefixes of Plugins to copy here
echo "[+] 052: install nonproduct monitoring plugins into PluginsContribDir/"

ELEMENTS=( INTERFACES MEMORY )

for PLUGIN in ${ELEMENTS[@]}
do
   PLUGIN_SRC=$PLUGIN\_SRC
   PLUGIN_FILE=$PLUGIN\_FILE
   echo "[+] Copying Monitoring Plugin ${!PLUGIN_FILE} from git to Plugins contrib dir: ${MONITORING_PLUGINS_CONTRIB_DIR}"

   # Check if Plugin already exists. If yes: backup first
   if [ -f ${MONITORING_PLUGINS_CONTRIB_DIR}/${!PLUGIN_FILE} ]
   then
	#Verify if existing version is already up-to-date
	diff ${MONITORING_PLUGINS_CONTRIB_DIR}/${!PLUGIN_FILE} ${!PLUGIN_SRC} > /dev/null
	RES=$?
	if [ $RES -eq 0 ]
	then
	   continue
	fi

        #echo "[+] Creating Backup of ${!PLUGIN_FILE}"
        cp --force ${MONITORING_PLUGINS_CONTRIB_DIR}/${!PLUGIN_FILE} ${MONITORING_PLUGINS_CONTRIB_DIR}/${!PLUGIN_FILE}.${DATE}_bak
   fi
   cp ${!PLUGIN_SRC} ${MONITORING_PLUGINS_CONTRIB_DIR}
   #echo "[i] Copied ${!PLUGIN_FILE}"

done


echo "[i] 052: Done."
