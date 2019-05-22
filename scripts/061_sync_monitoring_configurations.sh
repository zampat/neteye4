#!/bin/bash

# Script action:
# Copy NetEye4 / Icinga2 monitoring configuration files to neteyeshare/
#

FOLDER_MONITORING=$1

#Copy files ./monitoring/configurations
if [ ! -d ${FOLDER_MONITORING}/configurations/ ]
then
   echo "[+] 061: Copy monitoring configurations into neteyeshare: $FOLDER_MONITORING"
   cp -r ./monitoring/configurations $FOLDER_MONITORING
fi

