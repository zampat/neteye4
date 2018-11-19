#!/bin/bash

# Activate selected monitoring Plugins in contrib foler
MONITORING_PLUGINS_CONTRIB_DIR="$1"

#Define Variables
CHECK_INTERFACES="./monitoring/monitoring-plugins/network-devices/check_interfaces"
CHECK_INTERFACES_FILE="check_interfaces"

CHECK_MEM="./monitoring/monitoring-plugins/linux_unix/check_mem.pl"
CHECK_MEM_FILE="check_mem.pl"

# Check existency of folder PluginsContrib
if [ ! -d "${MONITORING_PLUGINS_CONTRIB_DIR}" ]
then
   mkdir -p ${MONITORING_PLUGINS_CONTRIB_DIR}
fi


# Copy some Plugins from GIT monitoring to PluginsContribDir
if [ -d ${MONITORING_PLUGINS_CONTRIB_DIR} ]
then
   echo "[i] Copying Monitoring Plugins from git to Plugins contrib dir: ${MONITORING_PLUGINS_CONTRIB_DIR}"

   # PLUGIN check_interfaces
   if [ -f ${MONITORING_PLUGINS_CONTRIB_DIR}/${CHECK_INTERFACES_FILE} ]
   then
	echo "[+] Creating Backup of ${CHECK_INTERFACES_FILE}"
	cp --force ${MONITORING_PLUGINS_CONTRIB_DIR}/${CHECK_INTERFACES_FILE} ${MONITORING_PLUGINS_CONTRIB_DIR}/${CHECK_INTERFACES_FILE}.bak
   fi
   cp ${CHECK_INTERFACES} ${MONITORING_PLUGINS_CONTRIB_DIR}
   echo "[i] Copied ${CHECK_INTERFACES_FILE}"


   # PLUGIN check_mem.pl
   if [ -f ${MONITORING_PLUGINS_CONTRIB_DIR}/${CHECK_MEM_FILE} ]
   then
        echo "[+] Creating Backup of ${CHECK_MEM_FILE}"
        cp --force ${MONITORING_PLUGINS_CONTRIB_DIR}/${CHECK_MEM_FILE} ${MONITORING_PLUGINS_CONTRIB_DIR}/${CHECK_MEM_FILE}.bak
   fi
   cp ${CHECK_MEM} ${MONITORING_PLUGINS_CONTRIB_DIR}
   echo "[i] Copied ${CHECK_MEM_FILE}"
fi
