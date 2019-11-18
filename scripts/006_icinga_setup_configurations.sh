#!/bin/bash

# Script action:
# Configure / patch NetEye4 / Icinga2 monitoring configuration files
#

# /neteye/shared/icinga2/conf/icinga2/constants.conf
FOLDER_ICINGA2MASTER="/neteye/shared/icinga2/conf/icinga2"
FOLDER_ICINGA2="/neteye/local/icinga2/conf/icinga2"
FOLDER_ICINGA2MASTER_CONST_CONF="${FOLDER_ICINGA2MASTER}/constants.conf"
FOLDER_ICINGA2_CONST_CONF="${FOLDER_ICINGA2}/constants.conf"

# Configure Icinga2-master constants.conf
grep "PluginContribDir = \"\"" ${FOLDER_ICINGA2MASTER_CONST_CONF} > /dev/null 2>&1
RES=$?
if [ $RES -eq 0 ]
then
   echo "[+] 006: Configuring 'PluginContribDir' in ${FOLDER_ICINGA2MASTER_CONST_CONF}."
   echo "         Please restart icinga2-master service"
   sed -i "s/const PluginContribDir = \"\"/const PluginContribDir = \"\/neteye\/shared\/monitoring\/plugins\"/g" ${FOLDER_ICINGA2MASTER_CONST_CONF}
fi

# Configure Icinga2 constants.conf
grep "PluginContribDir = \"\"" ${FOLDER_ICINGA2_CONST_CONF} > /dev/null 2>&1
RES=$?
if [ $RES -eq 0 ]
then
   echo "[+] 006: Configuring 'PluginContribDir' in ${FOLDER_ICINGA2_CONST_CONF}"
   echo "         Please restart icinga2 service"
   sed -i "s/const PluginContribDir = \"\"/const PluginContribDir = \"\/neteye\/shared\/monitoring\/plugins\"/g" ${FOLDER_ICINGA2_CONST_CONF}
fi

echo "[i] 006: To configure the 'PluginContribDir' on a remote neteye satellite run:"
echo "    ssh remote_host_fqdn 'sed -i \"s/const PluginContribDir = \"\"/const PluginContribDir = \"\/neteye\/shared\/monitoring\/plugins\"/g\" /neteye/local/icinga2/conf/icinga2/constants.conf'"
echo "    ssh remote_host_fqdn 'systemctl restart icinga2'"
