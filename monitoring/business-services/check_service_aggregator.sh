#! /bin/bash
#

# Read the service status of all services given a particular name via livestatus and aggregate results to check if a given number of CRITICAL is exceeded or a given number of OK status is found
#
# This script is published under the GPLv3 license.
# (C) 2018 Patrick Zambelli, Würth-Phoenix GmbH
#
# Changelog: 2018-04-05 Creation of script
# 2018-09-03 Warning/Critical threshold for MAX Incidents and MIN OK values. Rewrite of logic. 
# 2018-11-29 Automate NetEye 3 and 4 compatibility (livestatus selector) 
# 

TMPFILE=/tmp/check_service_aggregator$$.tmp
SERVICE=""
MAX_INCIDENT_WARN="2"
MAX_INCIDENT_CRIT="3"
MIN_OK_WARN="3"
MIN_OK_CRIT="2"

NETEYE_3_LIVESTATUS_DIR="/var/log/nagios/rw"
NETEYE_3_LIVESTATUS="${NETEYE_3_LIVESTATUS_DIR}/live"
NETEYE_4_LIVESTATUS_DIR="/var/run/icinga2-master/icinga2/cmd"
NETEYE_4_LIVESTATUS="${NETEYE_4_LIVESTATUS_DIR}/livestatus"

trap 'rm -f $TMPFILE; exit 1' 1 2 15
trap 'rm -f $TMPFILE' 0

print_usage() {
        echo
        echo "This Plugin aggregates the status of multiple service checks from various host and performs checks: "
        echo "a) not reaching the MAX amount of tollerated crical incidents (HARD) <=  MAX_NUM_OF_CRITICALS. Reaching this threshold, return: CRITICAL for -c and WRNING for -w."
        echo "b) having at least (>=) OK results. Having less than -C will cause CRITICAL, less than -W will cause WARNING."
        echo
        echo "Consider the following states of Service check:"
        echo "INCIDENT: Status = Critical, Statustype = Hard"
        echo ""
        echo "Filter: NOT ACKNOWLEDGED and NOT DURING SCHEDULED DOWNTIME"
        echo
        echo "USAGE: "
        echo "check_service_aggregator.sh -s SERVICE_NAME [-w MAX_NUM_OF_INCIDENTS] [-c MAX_NUM_OF_INCIDENTS] [-W MIN_NUM_OF_OK] [-C MIN_NUM_OF_OK]"
        echo
}



while test -n "$1"; do
    case "$1" in
        --help)
            print_usage
            exit $STATE_OK
            ;;
        -h)
            print_usage
            exit $STATE_OK
            ;;
        -s)
            SERVICE=$2
            shift
            ;;
        -c)
            MAX_INCIDENT_CRIT=$2
            shift
            ;;
        -w)
            MAX_INCIDENT_WARN=$2
            shift
            ;;
        -W)
            MIN_OK_WARN=$2
            shift
            ;;
        -C)
            MIN_OK_CRIT=$2
            shift
            ;;
        -V)
            print_revision $PROGNAME $VERSION
            exit $STATE_OK
            ;;

   esac
   shift
done

if [ -z "$SERVICE" ]
then
   print_usage
   exit $STATE_UNKNOWN
fi

#
# NetEye 3 and 4 compatibility check: Livestatus path changes
#
if [ -d $NETEYE_3_LIVESTATUS_DIR ]
then
   # NetEye 3: /var/log/nagios/rw/live
   echo -e "GET services\nColumns: host_display_name description state state_type acknowledged scheduled_downtime_depth\nFilter: description = $SERVICE" | ncat --unixsock $NETEYE_3_LIVESTATUS >$TMPFILE

elif [ -d $NETEYE_4_LIVESTATUS_DIR ]
then
   # NetEye 4: /var/run/icinga2-master/icinga2/cmd/livestatus
   echo -e "GET services\nColumns: host_display_name description state state_type acknowledged scheduled_downtime_depth\nFilter: description = $SERVICE\n" | ncat --unixsock $NETEYE_4_LIVESTATUS >$TMPFILE

else
   echo "Exception: Monitoring results can not be fetched from livestatus. Make sure livestatus is running"
   exit 3
fi


NUM_OF_SERVICES=0
NUM_OF_OK=0
NUM_OF_CRITICAL_ANY=0
NUM_OF_CRITICAL_INCIDENT=0
NUM_OF_CRITICAL_DOWNTIME=0
NUM_OF_CRITICAL_ACK=0
NUM_OF_CRITICAL_SOFT=0
OUTTXT=""
OUTTXT_DETAIL=""
PERFDATA=""
OUTRET=3

while read ll
do
	#echo "reading line $ll"
        NUM_OF_SERVICES=$(expr $NUM_OF_SERVICES + 1)
        HOSTNAME=$(echo $ll | cut -d\; -f1)
        SERVICENAME=$(echo $ll | cut -d\; -f2)
        STATE=$(echo $ll | cut -d\; -f3)
        STATETYPE=$(echo $ll | cut -d\; -f4)
        IS_ACK=$(echo $ll | cut -d\; -f5)
        IS_DOWNTIME=$(echo $ll | cut -d\; -f6)

        STATE_DESC=""
	if [ $STATE -eq 0 ]; then STATE_DESC="OK"; fi
	if [ $STATE -eq 1 ]; then STATE_DESC="WARNING"; fi
	if [ $STATE -eq 2 ]; then STATE_DESC="CRITICAL"; fi
	if [ $STATE -eq 3 ]; then STATE_DESC="UNKNOWN"; fi

	# Count CRITICAL status
        if [ $STATE -eq 2 ]
        then
           NUM_OF_CRITICAL_ANY=$(expr $NUM_OF_CRITICAL_ANY + 1)

	   # Any critical in soft state (STATETYPE = 0)
           if [ $STATETYPE -eq 0 ]
	   then
		NUM_OF_CRITICAL_SOFT=$(expr $NUM_OF_CRITICAL_SOFT + 1)
	        STATE_DESC="CRITICAL (Soft)"

	   # Any acknowledged critical not soft state
           elif [ $IS_ACK -eq 1 ]
	   then
                NUM_OF_CRITICAL_ACK=$(expr $NUM_OF_CRITICAL_ACK + 1)
	        STATE_DESC="CRITICAL (Acknowledged)"

	   # Any downtime critical not soft state
           elif [ $IS_DOWNTIME -eq 1 ]
           then
                NUM_OF_CRITICAL_DOWNTIME=$(expr $NUM_OF_CRITICAL_DOWNTIME + 1)
	        STATE_DESC="CRITICAL (in Downtime)"

	   # Any critical not soft state = INCIDENT !!
           else
		NUM_OF_CRITICAL_INCIDENT=$(expr $NUM_OF_CRITICAL_INCIDENT + 1)
	        STATE_DESC="CRITICAL (Incident!)"
           fi
        fi

	# Count explicit OK states, HARD status
        if [ $STATE -eq 0 ] && [ $STATETYPE -eq 1 ]
        then
           NUM_OF_OK=$(expr $NUM_OF_OK + 1)
	        STATE_DESC="OK"
	fi

	OUTTXT_DETAIL="$OUTTXT_DETAIL Service $SERVICE on HOST $HOSTNAME has status: $STATE_DESC<br/>"

done <$TMPFILE

#Check of thresholds
# Incidents >= Critical threshold
if [ $NUM_OF_CRITICAL_INCIDENT -ge $MAX_INCIDENT_CRIT ]
then
   OUTTXT="$OUTTXT CRITICAL: Unhandled incidents count $NUM_OF_CRITICAL_INCIDENT reaches/exceeds limit of $MAX_INCIDENT_CRIT "
   OUTRET=2

# OK <= Critical threshold
elif  [ $NUM_OF_OK -le $MIN_OK_CRIT ]
then
   OUTTXT="$OUTTXT CRITICAL: Tracked OK results: $NUM_OF_OK is less/equal critical limit: $MIN_OK_CRIT "
   OUTRET=2

# Incidents >= Warning threshold
elif [ $NUM_OF_CRITICAL_INCIDENT -ge $MAX_INCIDENT_WARN ]
then
   OUTTXT="$OUTTXT WARNING: Unhandled incidents count $NUM_OF_CRITICAL_INCIDENT reaches/exceeds limit of $MAX_INCIDENT_WARN "
   OUTRET=1

# OK <= Warning threshold
elif  [ $NUM_OF_OK -le $MIN_OK_WARN ]
then
   OUTTXT="$OUTTXT WARNING: Tracked OK results: $NUM_OF_OK is less/equal warning limit: $MIN_OK_WARN "
   OUTRET=1

elif [ $NUM_OF_CRITICAL_INCIDENT -lt $MAX_INCIDENT_CRIT ]
then
   OUTTXT="$OUTTXT OK: "
   OUTRET=0
fi


OUTTXT="$OUTTXT for service \"$SERVICE\". Num.of aggregated services: $NUM_OF_SERVICES. OK: $NUM_OF_OK. Criticals: $NUM_OF_CRITICAL_ANY, UNHANDLED: $NUM_OF_CRITICAL_INCIDENT, ACKNOWLEGED: $NUM_OF_CRITICAL_ACK, IN DOWNTIME: $NUM_OF_CRITICAL_DOWNTIME, status SOFT: $NUM_OF_CRITICAL_SOFT"
PERFDATA="ok_services=$NUM_OF_OK;$MIN_OK_WARN;$MIN_OK_CRIT critical_incidents=$NUM_OF_CRITICAL_INCIDENT;$MAX_INCIDENT_WARN;$MAX_INCIDENT_CRIT critical_acknowleged=$NUM_OF_CRITICAL_ACK;; critical_downtime=$NUM_OF_CRITICAL_DOWNTIME;;"

echo "$OUTTXT | $PERFDATA"
echo "$OUTTXT_DETAIL"

exit $OUTRET

