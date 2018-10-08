#!/bin/bash

FOLDER_MONITORING="/neteye/shared/neteyeshare/monitoring"

#Create folder structure
if [ ! -d $FOLDER_MONITORING ]
then
   echo "[ ] Creating folder structure"
   mkdir -p $FOLDER_MONITORING
fi

#Copy files
if [ ! -d ${FOLDER_MONITORING}/Extra_Icinga2_Configs/ ]
then
   echo "[ ] Copy content of Extra_Icinga2_Configs"
   cp -r Monitoring/Extra_Icinga2_Configs $FOLDER_MONITORING
fi

