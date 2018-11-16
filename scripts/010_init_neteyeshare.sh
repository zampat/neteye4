#!/bin/bash

FOLDER_MONITORING=$1

#Create folder structure
if [ ! -d $FOLDER_MONITORING ]
then
   echo "[ ] Creating folder structure"
   mkdir -p $FOLDER_MONITORING
fi
