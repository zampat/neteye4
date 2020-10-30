#!/bin/bash

# Script action: 
# Syncronize the whole folder PluginContribDir ("/neteye/local/monitoring/plugins") towards all members of cluster.
# Using rpm function: 
#

# MONITORING_PLUGINS_CONTRIB_DIR="/neteye/local/monitoring/plugins"
MONITORING_PLUGINS_CONTRIB_DIR="$1"

echo "[+] 090: Cluster-Sync of folder for PluginContribDir (${MONITORING_PLUGINS_CONTRIB_DIR})"

# Load the rpm-functions into runtime and perform folder sync
. /usr/share/neteye/scripts/rpm-functions.sh
cluster_folder_sync ${MONITORING_PLUGINS_CONTRIB_DIR}

echo "[i] 090: Done."
