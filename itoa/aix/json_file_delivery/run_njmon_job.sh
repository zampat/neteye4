#/bin/sh
#
# Perfomance data collection from AIX system via njmon
# Script to organize a local folder structure for collecting performance data as json file
# synchronizing those files to a remote neteye
# and executing the script
#
# Changelog
# 2019.06.14 Patrick Zambelli, Wuerth Phoenix
#
# NetEye Performance monitoring
#0,5,10,15,20,25,30,35,40,45,50,55 * * * * /usr/local/njmon/run_njmon_job.sh -s 10 -c 5 -m /var/log/njmon/ -f > /dev/null 2>&1
#
# prepare the ssh keytrust for user njmon with remote neteye system
#

# Configure destination neteye host
DST_NETEYE_HOST="10.1.1.90"
DST_NETEYE_USER="njmon"

#Configure job frequency
# Start every 5 minutes
# poll every 10 seconds
# repeat for 28 times
# 10 x 28 = 280seconds. 5min = 300seconds
POLL_FREQUENCY="10"
POLL_CYCLES="28"

#Default paths
PERFDATA_PATH="/var/log/njmon/"
NJMON_BIN="/usr/local/njmon/njmon_aix722_v21"
ARCHIVE_PERFDATA_PATH="/tmp/njmon"
# Retention in minutes
ARCHIVE_PERFDATA_RETENTION="60"

#Start of program execution
if [ ! -d ${ARCHIVE_PERFDATA_PATH} ]
then
    mkdir ${ARCHIVE_PERFDATA_PATH}
fi

#Transfer the json and error files to the destination neteye host
/usr/bin/scp ${PERFDATA_PATH}/* ${DST_NETEYE_USER}@${DST_NETEYE_HOST}:
RET=$?
if [ $RET -eq 0 ]
then
   mv ${PERFDATA_PATH}/* ${ARCHIVE_PERFDATA_PATH}/
else
   echo "Error synchronizing perfdata to neteye"
fi

#Cleanup process to remove old files from tmp archive
find ${ARCHIVE_PERFDATA_PATH}/ -mmin +${ARCHIVE_PERFDATA_RETENTION} -type f -name "*.json" -exec rm {} \;
find ${ARCHIVE_PERFDATA_PATH}/ -mmin +${ARCHIVE_PERFDATA_RETENTION} -type f -name "*.err" -exec rm {} \;


# Run job with following frequency
${NJMON_BIN} -s ${POLL_FREQUENCY} -c ${POLL_CYCLES} -m ${PERFDATA_PATH} -f > /dev/null 2>&1
