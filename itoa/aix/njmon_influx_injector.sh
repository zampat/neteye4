#!/bin/bash

# Script to loop through all collected perfdata files (json) from njmon
# and to write those values into influxdb
# and remove successfully parsed files
#
# Changelog
# 2019.06.14 Patrick Zambelli, Wuerth Phoenix
#
# Cronjob sample
# # Run system wide raid-check once a week on Sunday at 1am by default
# */5 * * * *     njmon /usr/local/njmon/njmon_influx_injector.sh


#Default paths
NJMON_PERFDATA_PATH="/var/log/njmon"
NJMON_BIN_PATH="/usr/local/njmon"

ARCHIVE_PERFDATA_RETENTION="2"

# Activate virtualenv, execute command, deactivate virtualenv
source ${NJMON_BIN_PATH}/influxdb/bin/activate

FILES=${NJMON_PERFDATA_PATH}/*.json
for perfdata_file in $FILES
do
  if [ -f ${perfdata_file} ]
  then
	echo "Processing: $perfdata_file file." >> ${NJMON_PERFDATA_PATH}/njmon_influx_injector.log 

	# take action on each file. $f store current file name
	/usr/bin/cat ${perfdata_file} | python ${NJMON_BIN_PATH}/njmon_to_InfluxDB_injector_15.py 
	RET=$?
	   if [ $RET -eq 0 ]
	   then
		/usr/bin/mv ${perfdata_file} ${NJMON_PERFDATA_PATH}/done/ > /dev/null 2>&1
	   else
		/usr/bin/mv ${perfdata_file} ${NJMON_PERFDATA_PATH}/failed/
	   fi
   fi
done

#Cleanup process to remove old files from tmp archive
find ${NJMON_PERFDATA_PATH}/ -mtime +${ARCHIVE_PERFDATA_RETENTION} -type f -name "*.json" -exec rm {} \;
find ${ARCHIVE_PERFDATA_PATH}/ -mtime +${ARCHIVE_PERFDATA_RETENTION} -type f -name "*.err" -exec rm {} \;

find ${ARCHIVE_PERFDATA_PATH}/done/ -mtime +${ARCHIVE_PERFDATA_RETENTION} -type f -name "*.json" -exec rm {} \;
find ${ARCHIVE_PERFDATA_PATH}/failed/ -mtime +${ARCHIVE_PERFDATA_RETENTION} -type f -name "*.json" -exec rm {} \;


#Deactivate virtualenv
deactivate

exit $?
