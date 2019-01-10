#!/bin/bash

# Script action:
# Copy NetEye4 / Icinga2 monitoring configuration files to neteyeshare/
#

FOLDER_MONITORING=$1

#Copy files ./monitoring/configurations
if [ ! -d ${FOLDER_MONITORING}/configurations/ ]
then
   echo "[ ] Copy content of configurations"
   cp -r ./monitoring/configurations $FOLDER_MONITORING
fi

