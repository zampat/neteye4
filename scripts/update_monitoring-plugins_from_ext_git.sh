#!/bin/bash

# Script action:
# Fetch monitoring plugins from external git repos and update files in this git repo
#

#Define Variables
NETEYESHARE_MONITORING="$1"
DATE=`date +%Y%m%d`

 
# Details : Neteye DRBD9 monitoring
NEDRBD_SRC="https://raw.githubusercontent.com/alaskacommunications/nagios_check_drbd9/master/check_drbd9.pl"
NEDRBD_DST_DIR="../monitoring/monitoring-plugins/neteye/"
NEDRBD_FILE="check_drbd9.pl"

# Plugin Details : Generic SAN storage health monitoring
FIBREALL_SRC="https://raw.githubusercontent.com/pld-linux/nagios-plugin-check_fibrealliance/master/check_fibrealliance.sh"
FIBREALL_DST_DIR="../monitoring/monitoring-plugins/storage/"
FIBREALL_FILE="check_fibrealliance.sh"



# Loop trough all Plugins
# Register all prefixes of Plugins to copy here
ELEMENTS=( NEDRBD FIBREALL )

for PLUGIN in ${ELEMENTS[@]}
do

   PLUGIN_DST_DIR=$PLUGIN\_DST_DIR
   PLUGIN_FILE=$PLUGIN\_FILE
   PLUGIN_SRC=$PLUGIN\_SRC

   
   # Valiation: Check existency of folder PluginsContrib
   if [ ! -d "${!PLUGIN_DST_DIR}" ]
   then
      mkdir -p ${!PLUGIN_DST_DIR}
   fi

   # Get file and store to /tmp dir
   /usr/bin/wget ${!PLUGIN_SRC} -O /tmp/${!PLUGIN_FILE}
   
   # Check if Plugin already exists. If yes: backup first
   if [ -f ${!PLUGIN_DST_DIR}/${!PLUGIN_FILE} ]
   then
      # Check if Plugin already exists. If yes: check if new content is available
      diff -ruN ${!PLUGIN_DST_DIR}/${!PLUGIN_FILE} /tmp/${!PLUGIN_FILE} > /tmp/git_fetch_compare.diff
      RES=$?
      # If new contents are found: backup and replace
      if [ "${RES}" -eq "1" ]
      then
	   echo "[+] New version of ${!PLUGIN_FILE} discovered. Creating Backup to ${!PLUGIN_FILE}.${DATE}_bak"
	   cp --force ${!PLUGIN_DST_DIR}/${!PLUGIN_FILE} ${!PLUGIN_DST_DIR}/${!PLUGIN_FILE}.${DATE}_bak

	   mv /tmp/${!PLUGIN_FILE} ${!PLUGIN_DST_DIR}/${!PLUGIN_FILE}
	   echo "[i] Replaced Plugin ${!PLUGIN_FILE} from git to Plugins dir: ${!PLUGIN_DST_DIR}"
      else
	   echo "[ ] Plugin ${!PLUGIN_FILE} is already installed at latest version. Nothing to do."
      fi
   else
      mv /tmp/${!PLUGIN_FILE} ${!PLUGIN_DST_DIR}/${!PLUGIN_FILE}
      echo "[i] Created Plugin ${!PLUGIN_FILE} from git into Plugins dir: ${!PLUGIN_DST_DIR}"
   fi
   chmod 755 ${!PLUGIN_DST_DIR}/${!PLUGIN_FILE}
done


echo "[i] Done: Copied all Non-Product monitoring plugins from GIT Repositories"

