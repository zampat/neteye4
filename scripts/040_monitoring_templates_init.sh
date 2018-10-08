#!/bin/bash

#Define Variables
FILESHARE_TEMPLATES="/neteye/shared/neteyeshare/monitoring"
FILESHARE_MONIT_TEMPLATES="${FILESHARE_TEMPLATES}/icinga2-monitoring-templates/"


GIT_MONITORING_TEMPLATES="https://github.com/zampat/icinga2-monitoring-templates.git"

# Clone Git Repo
if [ ! -d ${FILESHARE_MONIT_TEMPLATES} ]
then
   LOC=`pwd`
   echo "[i] Fetching Monitoring Templates for import from git."
   mkdir -p $FILESHARE_TEMPLATES

   cd $FILESHARE_TEMPLATES
   /usr/bin/git clone $GIT_MONITORING_TEMPLATES
   echo "[i] Monitoring templates have been downloaded and are ready for import."
   echo "    For more info see $GIT_MONITORING_TEMPLATES"

   cd $LOC
else
   echo "[ ] Monitoring Templates already synchronized to neteyeshare."
fi
