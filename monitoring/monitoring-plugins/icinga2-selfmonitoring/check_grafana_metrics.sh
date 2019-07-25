#!/bin/bash
#
################################################################################
#                                                                              #
#      Nagios/Icinga check plugin for checking metrics via Grafana API         #
#                      created by Matthias J. Schmaelzle <http://www.mjs.de>   #
#                                                        Version 1.00 / 2019   #
################################################################################

# Changelog
# Date          Author      Version     Comment
# 2019-07-12    MJS     (Ver. 1.00)     Initial
# 2019-07-20    MJS     (Ver. 1.01)     Add more checks options



# Define global varibales
# ======================================
#

# Programm, version and author information
PROGNAME=`basename $0`
VERSION="Version 1.01"
AUTHOR="Matthias Schmaezle (http://www.mjs.de)"

# Date Format
HUMAN_DATE=`date +%Y-%m-%d`
COMPLETE_DATE=`date "+%d.%m.%Y %H:%M"`
UNIX_DATE=`date +%s`
UNIX_DATE_TEMP_FILE=`date +%s%N`
UNIX_DATE_15=`date "+%s" -d "15 min ago"`
UNIX_TEMP_RANDOM=`hexdump -n 16 -v -e '/1 "%02X"' /dev/urandom`

# Define the exit codes
STATE_OK=0
STATE_WARNING=1
STATE_CRITICAL=2
STATE_UNKNOWN=3

# Default WARNING and CRITICAL thresholds
WARNING=5
CRITICAL=3

# Default check modes
CHECK_MODE=influxdb




# Gernerate menue
# ======================================
#

print_version() {
    echo "$PROGNAME $VERSION $AUTHOR"
}


print_help() {
    print_version $PROGNAME $VERSION
    echo ""
    echo "$PROGNAME - Checks the count of metrics by using the Grafana API"
    echo ""
    echo "$PROGNAME is a Nagios/Icinga plugin for checking the count of metrics by using the Grafana API"
    echo ""
    echo "Usage: $PROGNAME -H <HOSTNAME OR URL> -m <CHECKMODE> -datasource <GRAFANA DATASOURCE> -mdb <INFLUX DB> -mhost <QUERY HOST OBJECT> -mservice <QUERY SERVICE OBJECT> -mmetric <METRIC OBJECT> -mtime <TIME GO BACK> -w <WARNING TRHESHOLD -c <CRITICAL THRESHOLD>"
    echo ""
    echo "Parameter:"
    echo "  -H"
    echo "     Define the Sophos Host or URL, e.g. -H https://127.0.0.1/grafana";
    echo "  -m"
    echo "     Define the check mode <influxdb> default, e.g. -m influxdb"
    echo "  -u"
    echo "     Define a a API Key User, e.g. -u eyJrIjoibTkzMXVjeHpUVUMXXXXXXXXXXXXXXXXXXXXX"
    echo "  -datasource"
    echo "     Define a valid Grafana Datasource (case sensitive), e.g. -datasource InfluxDB"
    echo "  -mdb"
    echo "     Define the InfluxDB database (case sensitive) to get values from, e.g. -mdb icinga2"
    echo "  -mhost"
    echo "     Define a host object to do a query of valid metrics, e.g. -mhost livedemo-icinga2-stretch.hetzner.mjs.local"
    echo "  -mservice"
    echo "     Define a service for a host object to do a query of valid metrics, e.g. -mservice load"
    echo "  -mmetric"
    echo "     Define a special metric of a service for a host object to do a query of valid metrics, e.g. -mmetric load1"
    echo "  -mtime"
    echo "     Define the time range to go back from now time to check metrics, e.g. -mtime 10m"
    echo "  -w"
    echo "     Define the WARNING threshold, e.g. -w 5"
    echo "  -c"
    echo "     Define the CRITICAL threshold, e.g. -c 3"
    echo "  -h"
    echo "     This help"
    echo "  -v"
    echo "     Version"
    echo ""
    echo ""
    echo "Examples:"
    echo "Check the metrics for a host/service object"
    echo "   e.g. ./$PROGNAME -H http://127.0.0.1/grafana -m influxdb -u "eyJrIjoibTkzMXVjeHpUVUMXXXXXXXXXXXXXXXXXXXXX" -datasource InfluxDB -mdb icinga2 -mhost icinga2.mjs.local -mservice load -mmetric load1 -mtime 10m -w 5 -c 3"
    echo ""
    echo ""
    echo ""
    exit $STATE_UNKNOWN
}



# Check if an paramater is given
if [ -z $1 ]; then
    echo $usage
    print_help
    exit $e_unknown
fi



# Check for parameters
while test -n "$1"; do
    case "$1" in
                -h)
                        print_help
                        exit $STATE_UNKNOWN
                        ;;
                -v)
                        print_version
                        exit $STATE_OK
                        ;;
                -H)
                        hostname=$2
                        shift
                        ;;
		-u)
                        API_USER=$2
                        shift
                        ;;
                -m)
                        CHECK_MODE=$2
                        shift
                        ;;
		-datasource)
			GRAFANA_DATASOURCE=$2
			shift
                        ;;
                -mdb)
                        METRIC_DB=$2
                        shift
                        ;;

		-mhost)
			METRIC_HOST=$2
                        shift
                        ;;
                -mservice)
                        METRIC_SERVICE=$2
                        shift
                        ;;
                -mmetric)
                        METRIC_METRIC=$2
                        shift
                        ;;
                -mtime)
                        METRIC_TIME=$2
                        shift
                        ;;
                -w)
                        WARNING=$2
                        shift
                        ;;
                -c)
                        CRITICAL=$2
                        shift
                        ;;
                *)
                        print_help
                        ;;

        esac
        shift
done





# Cleanup old temp files
# ======================================

find /tmp/Check_Grafana_*.tmp -mmin +360 -exec rm {} \; > /dev/null 2>&1


# Check for given parameters
# ======================================

if [ "$hostname" = "" ]; then
        echo "Error: >> Hostname and URL not given <<"
        echo "Please specify a hostname with url, e.g. -H http://127.0.0.1/grafana";
        exit $STATE_UNKNOWN
fi


if [ "$METRIC_HOST" = "" ]; then
        echo "Error: >> Host object to do a query not given <<"
        echo "Please specify a host object to do a query of valid metrics, e.g. -mhost icinga2.hetzner.mjs.local";
        exit $STATE_UNKNOWN
fi


if [ "$METRIC_SERVICE" = "" ]; then
        echo "Error: >> Service for a host object to do a query not given <<"
        echo "Please specify a service for a host object to do a query of valid metrics, e.g. -mservice load";
        exit $STATE_UNKNOWN
fi


if [ "$METRIC_METRIC" = "" ]; then
        echo "Error: >> Special metric of a service for a host object to do a query not given <<"
        echo "Please specify a special metric of a service for a host object to do a query of valid metrics, e.g. -mmetric load1";
        exit $STATE_UNKNOWN
fi


if [ "$METRIC_TIME" = "" ]; then
        echo "Error: >> A time range to go back from now time not given <<"
        echo "Please specify a time range to go back from now time to check metrics, e.g. -mtime 10m";
        exit $STATE_UNKNOWN
fi


if [ "$GRAFANA_DATASOURCE" = "" ]; then
	echo "Error: >> Grafana Datasource not given <<"
        echo "Please specify a valid Grafana Datasource (case sensitive), e.g. -datasource InfluxDB";
        exit $STATE_UNKNOWN
fi




# Running script an generate result
# ======================================
#


# Create a Temp File and run the Request
# ---------------------------------------

# Define a Temp Result file
TMP_RESULT_FILE="/tmp/Check_grafana_$UNIX_DATE_TEMP_FILE-$UNIX_TEMP_RANDOM.tmp"


# Get the ID of the Grafana Datasource
GET_GRAFANA_DATASOURCE=`curl -k -s -H "Authorization: Bearer $API_USER" "$hostname/api/datasources/id/$GRAFANA_DATASOURCE" | awk -F'{"id":' '{print $2}' | sed 's/}//g'`

# Check if a result of a Grafana DataSource ist given
if [ "$GET_GRAFANA_DATASOURCE" = "" ]; then
 	echo "Error: >> No valid Grafana Datasource given, no result for \"$GRAFANA_DATASOURCE\" <<"
        echo "Please specify a valid Grafana Datasource (case sensitive), e.g. -datasource InfluxDB";

        # Last Cleanup
        if [ -f $TMP_RESULT_FILE ]; then
          rm $TMP_RESULT_FILE > /dev/null 2>&1
        fi

        exit $STATE_UNKNOWN
fi


# Check the grafana metrics via influxdb
# ---------------------------------------
if [ "$CHECK_MODE" = "influxdb" ]; then


  # Check for given parameters needed by the InfluxDB
  # --------------------------------------

  if [ "$METRIC_DB" = "" ]; then
        echo "Error: >> Grafana Backend not given <<"
        echo "Please specify the Grafana Backend to get values from, e.g. -mdb icinga2";

	# Last Cleanup
	if [ -f $TMP_RESULT_FILE ]; then
          rm $TMP_RESULT_FILE > /dev/null 2>&1
	fi

        exit $STATE_UNKNOWN
  fi



# ---------------------------------------------------------------
# Do a curl query and Generate a Result file
# ---------------------------------------------------------------

  curl -k -D $TMP_RESULT_FILE -v -s -H "Authorization: Bearer $API_USER" -H "Content-Type: application/json" "$hostname/api/datasources/proxy/$GET_GRAFANA_DATASOURCE/query?db=$METRIC_DB&q=SELECT%20mean(%22value%22)%20FROM%20%22$METRIC_SERVICE%22%20WHERE%20(%22hostname%22%20%3D%20%27$METRIC_HOST%27%20AND%20%22metric%22%20%3D%20%27$METRIC_METRIC%27)%20AND%20time%20%3E%3D%20now()%20-%20$METRIC_TIME%20GROUP%20BY%20time(1m)%20fill(null)" >> $TMP_RESULT_FILE 2>&1

  # Modify the respones
  cat $TMP_RESULT_FILE | awk -F'"values":' '{print $2}' | sed '/^$/d' | sed 's/\],\[/\n/g' | sed 's/\(\[\|\]\|\}\|\"\)//g' | awk -F':' '{print "Time=" $0}' | awk -F',' '{print $1 ",Metric-Value=" $2}' >> $TMP_RESULT_FILE




# ---------------------------------------------------------------
# Exit if no valid check mode ist given
# ---------------------------------------------------------------

else

# Last Cleanup
if [ -f $TMP_RESULT_FILE ]; then
        rm $TMP_RESULT_FILE > /dev/null 2>&1
fi

  echo "UNKOWN: No vaild Check Mode given"
  exit $STATE_UNKNOWN

fi



# Check for the HTTP Exit Code
# ---------------------------------------
ERROR_CODE=`head -n 7 $TMP_RESULT_FILE | grep "HTTP/1.1" | awk '{print $2}'`

if [ "$ERROR_CODE" = "" ]; then
        echo "UNKOWN: No valid information or a HTTP ERROR could be received from Host $hostname"

        # Cleanup temp file
        rm $TMP_RESULT_FILE > /dev/null 2>&1

        exit $STATE_UNKNOWN

elif [ "$ERROR_CODE" != "200" ]; then
        echo "CRITICAL: HTTP ERROR code for Host $hostname with HTTP ERROR CODE >> $ERROR_CODE <<"

        # Cleanup temp file
        rm $TMP_RESULT_FILE > /dev/null 2>&1

        exit $STATE_CRITICAL
fi


# Check the count of received vlues
# ---------------------------------------

# Extract the date from the temp file
RESULT_VALUE=`cat $TMP_RESULT_FILE | grep -v "Metric-Value=null" | grep -c "Metric-Value="`

# Check if the Result count is higher than the critical threshold
if [ "$RESULT_VALUE" -lt "$CRITICAL" ]; then

        echo "CRITICAL: $RESULT_VALUE metrics for Hosts: \"$METRIC_HOST\" and service \"$METRIC_SERVICE\" where found in the last $METRIC_TIME (Thresholds Current: $RESULT_VALUE / WARNING: $WARNING / CRITICAL: $CRITICAL) | metrics_found=$RESULT_VALUE;$WARNING;$CRITICAL;0;0"

        # Cleanup temp file
        rm $TMP_RESULT_FILE > /dev/null 2>&1

        exit $STATE_CRITICAL


# Check if the Result count is higher than the warning threshold
elif [ "$RESULT_VALUE" -lt "$WARNING" ]; then

        echo "WARNING: $RESULT_VALUE metrics for Hosts: \"$METRIC_HOST\" and service \"$METRIC_SERVICE\" where found in the last $METRIC_TIME (Thresholds Current: $RESULT_VALUE WARNING: $WARNING / CRITICAL: $CRITICAL) | metrics_found=$RESULT_VALUE;$WARNING;$CRITICAL;0;0"

        # Cleanup temp file
        rm $TMP_RESULT_FILE > /dev/null 2>&1

        exit $STATE_WARNING

# Exit with an ok state, if the result of metrics ist greater than the warning/critical threshold
else
	echo "OK: $RESULT_VALUE metrics for Hosts: \"$METRIC_HOST\" and service \"$METRIC_SERVICE\" where found in the last $METRIC_TIME (Thresholds Current: $RESULT_VALUE WARNING: $WARNING / CRITICAL: $CRITICAL) | metrics_found=$RESULT_VALUE;$WARNING;$CRITICAL;0;0"

        # Cleanup temp file
        rm $TMP_RESULT_FILE > /dev/null 2>&1

        exit $STATE_OK

fi


