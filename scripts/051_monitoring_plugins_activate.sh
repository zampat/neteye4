#!/bin/bash

# Activate selected monitoring Plugins in contrib foler
MONITORING_PLUGINS_CONTRIB_DIR="$1"

#Define Variables
CHECK_INTERFACES="./monitoring/monitoring-plugins/network-devices/check_interfaces"


# Clone Git Repo
if [ -d ${MONITORING_PLUGINS_CONTRIB_DIR} ]
then
   echo "[i] Copying Monitoring Plugins from git to Plugins contrib dir: ${MONITORING_PLUGINS_CONTRIB_DIR}"

   # PLUGIN check_interfaces
   PLUGIN="/check_interfaces"
   if [ -f ${MONITORING_PLUGINS_CONTRIB_DIR}${PLUGIN} ]
   then
	echo "[+] Creating Backup of ${PLUGIN}"
	cp --force ${MONITORING_PLUGINS_CONTRIB_DIR}/${PLUGIN} ${MONITORING_PLUGINS_CONTRIB_DIR}/${PLUGIN}.bak
   fi
   cp ${CHECK_INTERFACES} ${MONITORING_PLUGINS_CONTRIB_DIR}
   echo "[i] Copied ${PLUGIN}"

fi
