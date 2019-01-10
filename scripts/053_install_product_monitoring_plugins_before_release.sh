#!/bin/bash

# Script action: 
# Copy NON-product monitoring plugins into PluginsContribDir/ foler
#

#MONITORING_PLUGINS_CONTRIB_DIR="/neteye/shared/monitoring/plugins"
MONITORING_PLUGINS_CONTRIB_DIR="$1"
DATE=`date +%Y%m%d`

#Define the monitoring-plugins from GIT to copy into PluginsContribDir/

# Plugin 1: check_nwc_health
# Details : 
NWCHEALTH_SRC="./monitoring/monitoring-plugins/network-devices/check_nwc_health/check_nwc_health"
NWCHEALTH_FILE="check_nwc_health"


# Valiation: Check existency of folder PluginsContrib
if [ ! -d "${MONITORING_PLUGINS_CONTRIB_DIR}" ]
then
   mkdir -p ${MONITORING_PLUGINS_CONTRIB_DIR}
fi


# Loop trough all Plugins
# Register all prefixes of Plugins to copy here
ELEMENTS=( NWCHEALTH )

for PLUGIN in ${ELEMENTS[@]}
do
   PLUGIN_SRC=$PLUGIN\_SRC
   PLUGIN_FILE=$PLUGIN\_FILE
   echo "[i] Copying Monitoring Plugin ${!PLUGIN_FILE} from git to Plugins contrib dir: ${MONITORING_PLUGINS_CONTRIB_DIR}"

   # Check if Plugin already exists. If yes: backup first
   if [ -f ${MONITORING_PLUGINS_CONTRIB_DIR}/${!PLUGIN_FILE} ]
   then
        echo "[+] Creating Backup of ${!PLUGIN_FILE}"
        cp --force ${MONITORING_PLUGINS_CONTRIB_DIR}/${!PLUGIN_FILE} ${MONITORING_PLUGINS_CONTRIB_DIR}/${!PLUGIN_FILE}.${DATE}_bak
   fi
   cp ${!PLUGIN_SRC} ${MONITORING_PLUGINS_CONTRIB_DIR}
   echo "[i] Copied ${!PLUGIN_FILE}"

done


echo "[i] Done: Copied all Non-Product monitoring plugins"
