#!/bin/bash

#Define Variables
FILESHARE_TEMPLATES="$1/monitoring/"
FILESHARE_MONIT_TEMPLATES="monitoring-templates/"

GIT_MONITORING_TEMPLATES="$2"

# Clone Git Repo
if [ ! -d "${FILESHARE_TEMPLATES}${FILESHARE_MONIT_TEMPLATES}" ]
then
   LOC=`pwd`
   echo "[i] 040: Fetching Monitoring Templates for import from git."
   mkdir -p $FILESHARE_TEMPLATES

   cd $FILESHARE_TEMPLATES
   /usr/bin/git clone $GIT_MONITORING_TEMPLATES ${FILESHARE_MONIT_TEMPLATES}
   echo "[i] Monitoring templates have been downloaded and are ready for import."
   echo "    For more info see $GIT_MONITORING_TEMPLATES"

   cd $LOC
else
   echo "[ ] 040: Monitoring Templates already synchronized to neteyeshare."
   echo "    To update got to ${FILESHARE_MONIT_TEMPLATES} and perform 'git fetch && git pull'. Then run ./run_import.sh'"
fi
