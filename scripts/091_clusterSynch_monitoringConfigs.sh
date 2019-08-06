#!/bin/bash

# Script action: 
# Syncronize various configuration files and folders required for monitoring among nodes using rpm function 
#
# Contents to be synchronized:
# - /etc/freetds.conf

echo "[+] 091: Cluster-Sync of configuration files and folders (i.e.:/etc/freetds.conf)"

# Load the rpm-functions into runtime and perform folder sync
. /usr/share/neteye/scripts/rpm-functions.sh

# Synchronize: /etc/freetds.conf
FILENAME="/etc/freetds.conf"
cluster_file_sync ${FILENAME}

echo "[i] 091: Done."
