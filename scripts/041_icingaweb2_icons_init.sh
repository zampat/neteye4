#!/bin/bash

# Install additional Host Icons in Icinaweb2 folder

#Define Variables
SRC_GIT_ICONS_FOLDER="./monitoring/configurations/icingaweb2_icons"
# ARG1: ICINGA2_HOME_DIR="/neteye/shared/icingaweb2"
DST_ICINGAWEB2_ICONS_FOLDER="$1/public/img/icons"

# Verify DST Folder exists
if [ -d "${DST_ICINGAWEB2_ICONS_FOLDER}" ]
then
   echo "[i] Installing additional Icingaweb2 Host Icons (to ${DST_ICINGAWEB2_ICONS_FOLDER})"
   /usr/bin/rsync -av ${SRC_GIT_ICONS_FOLDER}/* ${DST_ICINGAWEB2_ICONS_FOLDER}/
   echo "    Done: Host icons have been installed."

else
   echo "[-] Failed to identify Icingaweb2 Icons dir: ${DST_ICINGAWEB2_ICONS_FOLDER}"
fi
