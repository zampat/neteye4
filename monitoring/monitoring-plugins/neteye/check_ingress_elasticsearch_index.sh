#!/bin/bash

# Original author: Michele Santuari
#
# Extension: Mirko Bez (mirko.bez <at> wuerth-phoenix.com)
# Add command line options to make the tool flexible and usable also in icinga.
#

#
# Make sure that the user (corresponding to the used certificate)
# has access to ${INDEX_STATIC_NAME}-* and field ${INGESTED_TIME_FIELD}.
#
# NetEye > 4.7 defines a user NeteyeElasticCheck, who by default has read access
# to  index "logstash" and only to fields "@timestamp" and "hostname" of this
# index.
# If you want to extend the capabilities of the user, please define a new role
# (e.g., a role that can access other fields on-demand) and assign it to
# the searchguard user.
# It is possible to specify the certificate and private key to use to connect
# to elasticsearch.
#

readonly PROGRAM_NAME=$(basename $0)


function check_threshold() {
  local LOG_TIMESTAMP=$1
  local LOG_TIMESTAMP_SEC=$2
  local SECONDS_AGO=$3
  local SECONDS=$4
  local EXIT_STATUS_ON_MATCH=$5

  if [[ "${LOG_TIMESTAMP_SEC}" -le "${SECONDS_AGO}" ]]; then
    echo "Index ${INDEX_STATIC_NAME} is not collecting logs since ${SECONDS} ${THRESHOLD_STRING} ago"
    echo "Last log is: ${LOG_TIMESTAMP}"
    exit "${EXIT_STATUS_ON_MATCH}"
  fi
}

function build_curl_command() {
  local COMMAND=$1
  local CERT=$2
  local KEY=$3

  COMMAND="${COMMAND} -s"

  if [[ "${CERT}" != "" ]]; then
    COMMAND="${COMMAND} --cert ${CERT}"
  fi

  if [[ "${KEY}" != "" ]]; then
    COMMAND="${COMMAND} --key ${KEY}"
  fi

  echo ${COMMAND}
}


function help() {
  # Print the help message and exit
  echo "$1: check if elasticsearch index is actually receiving data."
  echo -e "\t Usage: $1 [OPTION]..."
  echo ""
  echo -e "\t-c, --critical-threshold (int): the critical threshold (default: "
  echo -e "\t-w, --warning-threshold (int): the warning threshold"
  echo -e "\t--threshold-format (str): the unit of measure for the thresholds \
one of 'days', 'hours', 'minutes','seconds' (default 'hours')"
  echo -e "\t--index-date-format (str): index date format (e.g., 'yyyy-MM-dd') compliant \
to elasticsearch date formats"
  echo -e "\t--index-static-name (str): the base name of the index (e.g., 'logstash', 'winlogbeat')"
  echo -e "\t--ingested-time-field (str): the name of the field to use (e.g., '@timestamp', 'event.created') default: @timestamp"
  echo -e "\t--index-creation-interval (str): it specifies whenever a new index is created (e.g., d = daily, M = monthly)"

  echo -e "\t--es-host (str): the elasticsearch host or ip (default: 'elasticsearch.neteyelocal')"
  echo -e "\t--es-port (int): the elasticsearch port (default: 9200)"
  echo -e "\t--es-protocol (str): the protocol used to connect to elasticsearch (default: 'https')"
  echo -e "\t-u, --searchguard-user (str): searchguard user"
  echo -e "\t--output-date-format (str): the output date format compatible with 'date' command (default: '+%A %Y.%m.%d %H:%M:%S %Z')"
  echo -e "\t--curl-command-path (str): path to a curl executable to use"
  echo -e "\t--curl-cert (str): path to the client's certificate (check: man curl for details)"
  echo -e "\t--curl-key (str): path to the private key of the client (check: man curl for details)"
}


# Default Values that can be overwritten by options
WARNING_THRESHOLD=2
CRITICAL_THRESHOLD=4
INDEX_STATIC_NAME="logstash"
SEARCHGUARD_USER=NeteyeElasticCheck
INGESTED_TIME_FIELD="@timestamp"
OUTPUT_DATE_FORMAT="+%A %Y.%m.%d %H:%M:%S %Z"
ES_HOST="elasticsearch.neteyelocal"
ES_PORT="9200"
ES_PROTOCOL="https"
THRESHOLD_FORMAT="hours"
INDEX_DATE_FORMAT="yyyy.MM.dd"
INDEX_CREATION_INTERVAL="d"
CURL_COMMAND_PATH="/usr/share/neteye/scripts/searchguard/sg_neteye_curl.sh"
CURL_CERT=""
CURL_KEY=""

# Retrieving the command line options. Each shift, discard one argument.
while [[ $# -gt 0 ]]
do
  key="$1"

  case $key in
      "-c"|"--critical-threshold")
      CRITICAL_THRESHOLD="$2"
      shift
      shift
      ;;
      "-w"|"--warning-threshold")
      WARNING_THRESHOLD="$2"
      shift
      shift
      ;;
      "--threshold-format")
      THRESHOLD_FORMAT="$2"
      shift
      shift
      ;;
      "--index-date-format")
      INDEX_DATE_FORMAT="$2"
      shift
      shift
      ;;
      "--index-static-name")
      INDEX_STATIC_NAME="$2"
      shift
      shift
      ;;
      "--ingested-time-field")
      INGESTED_TIME_FIELD="$2"
      shift
      shift
      ;;
      "--index-creation-interval")
      INDEX_CREATION_INTERVAL="$2" # d = daily, m = monthly, y = yearly
      shift
      shift
      ;;
      "--es-host")
      ES_HOST="$2"
      shift
      shift
      ;;
      "--es-port")
      ES_PORT="$2"
      shift
      shift
      ;;
      "--es-protocol")
      ES_PROTOCOL="$2"
      shift
      shift
      ;;
      "-u"|"--searchguard-user")
      SEARCHGUARD_USER="$2"
      shift
      shift
      ;;
      "-h"|"--help")
      help ${PROGRAM_NAME}
      ;;
      "--curl-command-path")
      CURL_COMMAND_PATH="$2"
      shift
      shift
      ;;
      "--curl-cert")
      CURL_CERT="$2"
      shift
      shift
      ;;
      "--curl-key")
      CURL_KEY="$2"
      shift
      shift
      ;;
      *)    # unknown option
        echo "Unknown parameter $key: $2"
        help
        exit 3
      ;;
  esac
done

#
# Translate threshold from ${THRESHOLD_FORMAT} to seconds to allow flexibility
# in the definition
#
THRESHOLD_STRING="seconds"

case ${THRESHOLD_FORMAT} in
  "d"|"days")
    CRITICAL_THRESHOLD=$((${CRITICAL_THRESHOLD}*86400))
    WARNING_THRESHOLD=$((${WARNING_THRESHOLD}*86400))
    ;;
  "h"|"hours")
    CRITICAL_THRESHOLD=$((${CRITICAL_THRESHOLD}*3600))
    WARNING_THRESHOLD=$((${WARNING_THRESHOLD}*3600))
    ;;
  "m"|"minutes")
    CRITICAL_THRESHOLD=$((${CRITICAL_THRESHOLD}*60))
    WARNING_THRESHOLD=$((${WARNING_THRESHOLD}*60))
    ;;
  "s"|"seconds")
    ;;
  *)
    "Unsupported threshold format '${THRESHOLD_FORMAT}': Available options are days, hours, minutes, seconds (or their abbreviations d, h, m, s)"
    exit 3
    ;;
esac

# Building the curl base command
CURL_BASE_COMMAND=$(build_curl_command "${CURL_COMMAND_PATH}" "${CURL_CERT}" "${CURL_KEY}")

# Building index name based on today's date
# ref: https://www.elastic.co/guide/en/elasticsearch/reference/current/date-math-index-names.html
CURRENT_INDEX_NAME="%3C${INDEX_STATIC_NAME}-%7Bnow%2F${INDEX_CREATION_INTERVAL}%7B${INDEX_DATE_FORMAT}%7D%7D%3E"
OLD_INDEX_NAME="%3C${INDEX_STATIC_NAME}-%7Bnow%2F${INDEX_CREATION_INTERVAL}-1${INDEX_CREATION_INTERVAL}%7B${INDEX_DATE_FORMAT}%7D%7D%3E"


# Building the url
URL="${ES_PROTOCOL}://${ES_HOST}:${ES_PORT}/${CURRENT_INDEX_NAME},${OLD_INDEX_NAME}/_search"

# Building the json payload
JSON_PAYLOAD="{
  \"_source\": [\"${INGESTED_TIME_FIELD}\"],
  \"size\": 1,
  \"sort\": [
    {
      \"${INGESTED_TIME_FIELD}\": {
        \"order\": \"desc\"
      }
    }
  ]
}"

JSON=$(${CURL_BASE_COMMAND} -XGET ${URL} -H 'Content-Type: application/json' -d "$JSON_PAYLOAD")

EXIT_CODE="$?"

LOG_TIMESTAMP=$(echo "$JSON" | jq -r ".hits.hits | .[] | .[\"_source\"] | .[\"${INGESTED_TIME_FIELD}\"]")

if [[ "${EXIT_CODE}" -ne 0 ]] || [[ -z "${LOG_TIMESTAMP}" ]]; then
  echo "Not able to collect data for today's '${INDEX_STATIC_NAME}' indices"
  echo "Request to Elastic APIs exits with code ${EXIT_CODE} and timestamp '${INGESTED_TIME_FIELD}' is not extracted"
  echo "JSON_RESPONSE: ${JSON}"
  exit 3
fi

LOG_TIMESTAMP_SEC=$(date -u +%s -d "${LOG_TIMESTAMP}")
WARNING_THRESHOLD_AGO=$(date -u +%s -d "${WARNING_THRESHOLD} ${THRESHOLD_STRING} ago")
CRITICAL_THRESHOLD_AGO=$(date -u +%s -d "${CRITICAL_THRESHOLD} ${THRESHOLD_STRING} ago")

check_threshold "${LOG_TIMESTAMP}" "${LOG_TIMESTAMP_SEC}" "${CRITICAL_THRESHOLD_AGO}" "${CRITICAL_THRESHOLD}" 2
check_threshold "${LOG_TIMESTAMP}" "${LOG_TIMESTAMP_SEC}" "${WARNING_THRESHOLD_AGO}" "${WARNING_THRESHOLD}" 1
TIME_DIFF="$(($(date +%s)-${LOG_TIMESTAMP_SEC}))"

echo "CHECK OK - last log dated \"$(date "${OUTPUT_DATE_FORMAT}" -d ${LOG_TIMESTAMP})\" | elapsed_time_since_last_log=${TIME_DIFF}s;${WARNING_THRESHOLD};${CRITICAL_THRESHOLD};;"
exit 0
