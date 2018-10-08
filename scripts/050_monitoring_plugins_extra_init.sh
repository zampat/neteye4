#!/bin/bash

#Define Variables
FILESHARE_MONITORING="/neteye/shared/neteyeshare/monitoring"
FILESHARE_MONIT_PLUGINS="plugins-scripts"

GIT_MONITORING_PLUGINS="https://github.com/zampat/monitoring.git"

# Clone Git Repo
if [ ! -d ${FILESHARE_MONITORING}/${FILESHARE_MONIT_PLUGINS} ]
then
   LOC=`pwd`
   echo "[i] Fetching Monitoring Plugins from git."
   mkdir -p ${FILESHARE_MONITORING}/$FILESHARE_MONIT_PLUGINS

   cd ${FILESHARE_MONITORING}
   /usr/bin/git clone $GIT_MONITORING_PLUGINS $FILESHARE_MONIT_PLUGINS

   echo "[i] Monitoring plugins have been downloaded and are ready for import."
   echo "    For more info see $GIT_MONITORING_PLUGINS"

   cd $LOC
else

   LOC=`pwd`
   echo "[i] Updating Monitoring Plugins from git."
   cd ${FILESHARE_MONITORING}/${FILESHARE_MONIT_PLUGINS}

   /usr/bin/git fetch
   /usr/bin/git pull

   cd $LOC

fi
