#!/bin/bash

FOLDER_MONITORING=$1

#Copy files ./monitoring/monitoring-plugins
if [ ! -d ${FOLDER_MONITORING}/monitoring-plugins/ ]
then
   echo "[ ] Copy content of configurations"
   cp -r ./monitoring/monitoring-plugins $FOLDER_MONITORING
fi
