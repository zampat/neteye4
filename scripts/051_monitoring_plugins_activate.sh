#!/bin/bash

# Activate selected monitoring Plugins in contrib foler

#Define Variables
FILESHARE_MONITORING="/neteye/shared/neteyeshare/monitoring"
FILESHARE_MONIT_PLUGINS="${FILESHARE_MONITORING}/plugins-scripts/monitoring-plugins"

MONITORING_PLUGINS_CONTRIB_DIR="/neteye/shared/monitoring/plugins"


# Clone Git Repo
if [ -d ${FILESHARE_MONIT_PLUGINS} ]
then
   echo "[i] Copying Monitoring Plugins from git to Plugins contrib dir: ${MONITORING_PLUGINS_CONTRIB_DIR}"

   PLUGIN="check_interfaces"
   if [ -f ${FILESHARE_MONIT_PLUGINS}${PLUGIN} ]
   then
	cp --force ${FILESHARE_MONIT_PLUGINS}/${PLUGIN} ${FILESHARE_MONIT_PLUGINS}/${PLUGIN}.bak
   fi
   cp ${FILESHARE_MONIT_PLUGINS}/${PLUGIN} ${MONITORING_PLUGINS_CONTRIB_DIR}
   echo "[i] Copied ${PLUGIN}"

fi
