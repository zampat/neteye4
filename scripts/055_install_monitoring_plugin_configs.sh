#!/bin/bash

#Define Variables
# MONITORING_PLUGINS_CONTRIB_CONFIG_DIR="/neteye/shared/monitoring/configs"

# Install configuration files for monitoring plugins
MONITORING_PLUGINS_CONTRIB_CONFIG_DIR="$1"
FILE_VMWARE_API="${MONITORING_PLUGINS_CONTRIB_CONFIG_DIR}/vmware_auth_poc.cfg"
if [ ! -f ${FILE_VMWARE_API} ] > /dev/null 2>1&
then
   echo "[i] 055: Install configuration files for monitoring plugins."
   mkdir -p ${MONITORING_PLUGINS_CONTRIB_CONFIG_DIR}
   cat >>${FILE_VMWARE_API} <<EOM
# Define ESX host credentials
username=<login>
password=<password>
EOM

else
   echo "[ ] 055: configuration files for monitoring plugins already exists."
fi
