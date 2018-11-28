#!/bin/bash

FOLDER_MONITORING=$1

#Copy files ./monitoring/analytics_dashboards/
if [ ! -d ${FOLDER_MONITORING}/analytics_dashboards/ ]
then
   echo "[ ] Copy analytics dashboards"
   cp -r ./monitoring/analytics_dashboards $FOLDER_MONITORING
fi
