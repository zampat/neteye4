#!/bin/bash

# Script action:
# Synch all Monitoring Plugins from GIT folder "monitoring-plugins" to local neteyeshare folder.
#

# PluginsContribDir: i.e. /neteye/shared/httpd/neteyeshare/monitoring
NETEYESHARE_MONITORING=$1

#Define Variables
SRC_GIT_MONIT_PLUGINS_FOLDER="./monitoring/monitoring-plugins"
DST_MONIT_PLUGINS_FOLDER="${NETEYESHARE_MONITORING}/"

# Verify DST Folder exists
if [ -d "${DST_MONIT_PLUGINS_FOLDER}" ]
then
   echo "[+] 060: Synchronizing monitoring plugins (to ${DST_MONIT_PLUGINS_FOLDER})"
   /usr/bin/rsync -av ${SRC_GIT_MONIT_PLUGINS_FOLDER} ${DST_MONIT_PLUGINS_FOLDER}/

else
   echo "[-] 060: Abort installing additional monitoring plugins. Folder does not exist: ${DST_MONIT_PLUGINS_FOLDER}"
fi

