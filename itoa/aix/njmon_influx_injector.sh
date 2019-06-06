#!/bin/bash

# Script to loop through all collected perfdata files (json) from njmon
# and to write those values into influxdb
# and remove successfully parsed files
#
# Cronjob sample
# # Run system wide raid-check once a week on Sunday at 1am by default
# */5 * * * *     njmon /usr/local/njmon/njmon_influx_injector.sh


# Activate virtualenv, execute command, deactivate virtualenv
NJMON_PERFDATA_PATH="/var/log/njmon/"


source /usr/local/njmon/influxdb/bin/activate

FILES=${NJMON_PERFDATA_PATH}/*.json
for perfdata_file in $FILES
do
  if [ -f ${perfdata_file} ]
  then
	echo "Processing $perfdata_file file..."
	# take action on each file. $f store current file name
	#cat ${perfdata_file} | /usr/bin/python /usr/local/njmon/njmon_to_InfluxDB_injector_15.py > /dev/null 2>&1
	/usr/bin/cat ${perfdata_file} | python /usr/local/njmon/njmon_to_InfluxDB_injector_15.py 
	RET=$?
	   if [ $RET -eq 0 ]
	   then
		/usr/bin/mv ${perfdata_file} /var/log/njmon/done/ > /dev/null 2>&1
	   else
		/usr/bin/mv ${perfdata_file} /var/log/njmon/failed/
	   fi
   fi
done


#Cleanup .err files
/usr/bin/mv ${NJMON_PERFDATA_PATH}/*.err /tmp > /dev/null 2>&1

deactivate

exit $?
