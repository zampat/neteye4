#!/bin/bash

#Define Variables
# ARG1: ICINGA2_CONF_HOME_DIR="/neteye/shared/icingaweb2/conf"
DIR_RESSOURCES="$1/preferences/root/"
FILE_RESSOURCES="$1/preferences/root/menu.ini"

# Check if a demo menu entry for fileshare exists
grep "menu-item" $FILE_RESSOURCES > /dev/null 2>&1
RES=$?
if [ $RES -ne 0 ]
then
   echo "[i] Adding Navigation item for user root."
   mkdir -p $DIR_RESSOURCES

   cat >>$FILE_RESSOURCES <<EOM
[FileShare]
type = "menu-item"
target = "_blank"
url = "../neteyeshare/"
EOM

else
   echo "[ ] Navigation item for user root already exists."
fi
