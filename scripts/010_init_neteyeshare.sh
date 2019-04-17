#!/bin/bash

FOLDER_MONITORING=$1
NETEYESHARE_ITOA=$2

#Create folder structure
if [ ! -d $FOLDER_MONITORING ]
then
   echo "[i] Creating neteyeshare folder structure"
   mkdir -p $FOLDER_MONITORING
fi

if [ ! -d ${NETEYESHARE_ITOA} ]
then
   echo "[i] Creating folder itoa"
   mkdir -p ${NETEYESHARE_ITOA}
fi
