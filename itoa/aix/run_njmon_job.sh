#/bin/sh
#
##NetEye Performance monitoring
#0,5,10,15,20,25,30,35,40,45,50,55 * * * * njmon /usr/local/njmon/run_njmon_job.sh -s 10 -c 5 -m /var/log/njmon/ -f > /dev/null 2>&1
#
# prepare the ssh keytrust for user njmon with remote neteye system
#

PERFDATA_PATH="/var/log/njmon/"
ARCHIVE_PERFDATA_PATH="/tmp/njmon"
DST_NETEYE_HOST="10.1.1.90"

if [ ! -d ${ARCHIVE_PERFDATA_PATH} ]
then
    mkdir ${ARCHIVE_PERFDATA_PATH}
fi


/usr/bin/scp ${PERFDATA_PATH}/* njmon@${DST_NETEYE_HOST}:
RET=$?
if [ $RET -eq 0 ]
then
   mv ${PERFDATA_PATH}/* /tmp/njmon/
else
   echo "Error synchronizing perfdata to neteye"
fi

echo "start job..."

# Run job with following frequency
# Start every 5 minutes
# poll every 10 seconds
# repeat for 28 times
# 10 x 28 = 280seconds. 5min = 300seconds
/usr/local/njmon/njmon_aix71_v21 -s 10 -c 5 -m ${PERFDATA_PATH} -f > /dev/null 2>&1
