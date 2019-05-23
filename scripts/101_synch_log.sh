#!/bin/bash

# Script action:
# Synch LOG agents and dashboards to local neteyeshare folder "log"
#

# PluginsContribDir: i.e. /neteye/shared/neteyeshare/log
NETEYESHARE_LOG=$1

#Define Variables
#SRC_GIT_ITOA_AGENTS_FOLDER="./itoa/agents"
#SRC_GIT_ITOA_DASHBOARDS_FOLDER="./itoa/dashboards"
#DST_ITOA_FOLDER="${NETEYESHARE_LOG}/"
#
## Verify DST Folder exists
#if [ -d "${DST_ITOA_FOLDER}" ]
#then
#   echo "[i] 070: Synchronizing itoa agents and dashboards (to ${DST_ITOA_FOLDER})"
#   /usr/bin/rsync -av ${SRC_GIT_ITOA_AGENTS_FOLDER} ${DST_ITOA_FOLDER}/
#   /usr/bin/rsync -av ${SRC_GIT_ITOA_DASHBOARDS_FOLDER} ${DST_ITOA_FOLDER}/
#
#else
#   echo "[-] Abort installing itoa components. Folder does not exist: ${DST_MONIT_PLUGINS_FOLDER}"
#fi

