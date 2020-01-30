#!/bin/bash

# Original author: Michele Santuari
#
# Extension: Mirko Bez (mirko.bez <at> wuerth-phoenix.com)
# Add command line options to make the tool flexible and usable also in a pure icinga/elasticsearch environment.
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
# the selected user.
# It is possible to specify the certificate and private key to use to connect
# to elasticsearch.
#

readonly PROGRAM_NAME=$(basename "$0")


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

  echo "${COMMAND}"
}

function build_performance_data() {
    TIME_DIFF=$1
    WARNING_THRESHOLD_SEC=$2
    CRITICAL_THRESHOLD_SEC=$3
    echo "elapsed_time_since_last_log=${TIME_DIFF}s;${WARNING_THRESHOLD_SEC};${CRITICAL_THRESHOLD_SEC};;"
}

# Credit https://stackoverflow.com/questions/6250698/how-to-decode-url-encoded-string-in-shell
function urldecode() { : "${*//+/ }"; echo -e "${_//%/\\x}"; }


# Default Values that can be overwritten by options
WARNING_THRESHOLD=2
CRITICAL_THRESHOLD=4
INDEX_STATIC_NAME="logstash"
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
CURL_PRIVATE_KEY=""
CURL_TIMEOUT="0"



function help() {
  # Print the help message and exit
  echo "$1: check if elasticsearch index is actually receiving data."
  echo -e "\t Usage: $1 [OPTION]..."
  echo ""
  echo -e "\t-c, --critical-threshold (int): the critical threshold (default: ${CRITICAL_THRESHOLD})"
  echo -e "\t-w, --warning-threshold (int): the warning threshold (default: ${WARNING_THRESHOLD})"
  echo -e "\t--threshold-format (str): the unit of measure for the thresholds \
one of 'days', 'hours', 'minutes','seconds' (default ${THRESHOLD_FORMAT})"
  echo -e "\t--index-date-format (str): index date format (e.g., ${INDEX_DATE_FORMAT}) compliant \
to elasticsearch date formats"
  echo -e "\t--index-static-name (str): the static name of the index (default: ${INDEX_STATIC_NAME})"
  echo -e "\t--ingested-time-field (str): the name of the field to use (default: ${INGESTED_TIME_FIELD})"
  echo -e "\t--index-creation-interval (str): it specifies whenever a new index is created (e.g., d = daily, M = monthly) (default ${INDEX_CREATION_INTERVAL})"
  echo -e "\t--es-host (str): the elasticsearch host or ip (default: ${ES_HOST})"
  echo -e "\t--es-port (int): the elasticsearch port (default: ${ES_PORT})"
  echo -e "\t--es-protocol (str): the protocol used to connect to elasticsearch (default: ${ES_PROTOCOL})"
  echo -e "\t--output-date-format (str): the output date format compatible with 'date' command (default: '${OUTPUT_DATE_FORMAT}')"
  echo -e "\t--curl-command-path (str): path to a curl executable to use (default: ${CURL_COMMAND_PATH})"
  echo -e "\t--curl-cert (str): path to the client's certificate (check: man curl for details) (default: ${CURL_CERT})"
  echo -e "\t--curl-key (str): path to the private key of the client (check: man curl for details) (default: ${CURL_PRIVATE_KEY})"
  echo -e "\t--timeout (int): maximum timeout for the connection to elasticsearch expressed in seconds. Exceeding this timeout will result in an unknown state."
}


# Retrieving the command line options. Each shift, discard one argument.
while [[ $# -gt 0 ]]
do
  key="$1"

  case ${key} in
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
      "-h"|"--help")
      help "${PROGRAM_NAME}"
      exit 2
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
      CURL_PRIVATE_KEY="$2"
      shift
      shift
      ;;
      "--timeout")
      CURL_TIMEOUT="$2"
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

case ${THRESHOLD_FORMAT} in
  "d"|"days")
    CRITICAL_THRESHOLD_SEC=$((CRITICAL_THRESHOLD*86400))
    WARNING_THRESHOLD_SEC=$((WARNING_THRESHOLD*86400))
    THRESHOLD_FORMAT="days"
    ;;
  "h"|"hours")
    CRITICAL_THRESHOLD_SEC=$((CRITICAL_THRESHOLD*3600))
    WARNING_THRESHOLD_SEC=$((WARNING_THRESHOLD*3600))
    THRESHOLD_FORMAT="hours"
    ;;
  "m"|"minutes")
    CRITICAL_THRESHOLD_SEC=$((CRITICAL_THRESHOLD*60))
    WARNING_THRESHOLD_SEC=$((WARNING_THRESHOLD*60))
    THRESHOLD_FORMAT="minutes"
    ;;
  "s"|"seconds")
    CRITICAL_THRESHOLD_SEC=$((CRITICAL_THRESHOLD))
    WARNING_THRESHOLD_SEC=$((WARNING_THRESHOLD))
    THRESHOLD_FORMAT="seconds"
    ;;
  *)
    "Unsupported threshold format '${THRESHOLD_FORMAT}': Available options are days, hours, minutes, seconds (or their abbreviations d, h, m, s)"
    exit 3
    ;;
esac



# Building the curl base command
CURL_BASE_COMMAND=$(build_curl_command "${CURL_COMMAND_PATH}" "${CURL_CERT}" "${CURL_PRIVATE_KEY}")

if [[ "${CURL_TIMEOUT}" -gt "0" ]]; then
  CURL_BASE_COMMAND="${CURL_BASE_COMMAND} --max-time ${CURL_TIMEOUT}"
fi

# Building index name based on today's date
# ref: https://www.elastic.co/guide/en/elasticsearch/reference/current/date-math-index-names.html
CURRENT_INDEX_NAME="%3C${INDEX_STATIC_NAME}-%7Bnow%2F${INDEX_CREATION_INTERVAL}%7B${INDEX_DATE_FORMAT}%7D%7D%3E"
OLD_INDEX_NAME="%3C${INDEX_STATIC_NAME}-%7Bnow%2F${INDEX_CREATION_INTERVAL}-1${INDEX_CREATION_INTERVAL}%7B${INDEX_DATE_FORMAT}%7D%7D%3E"


# Building the url
URL="${ES_PROTOCOL}://${ES_HOST}:${ES_PORT}/${CURRENT_INDEX_NAME},${OLD_INDEX_NAME}/_search?ignore_unavailable=true"

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


JSON=$(${CURL_BASE_COMMAND} --show-error -XGET "${URL}" -H 'Content-Type: application/json' -d "$JSON_PAYLOAD")

EXIT_CODE="$?"

if [[ "${EXIT_CODE}" -ne 0 ]]; then
  echo "CHECK UNKNOWN - curl failed with error code ${EXIT_CODE}"
  echo "${JSON}"
  exit 3
fi

echo "${JSON}" | jq "." > /dev/null

IS_JSON="$?"

if [[ "${IS_JSON}" -ne "0" ]]; then
  echo "CHECK UNKNOWN - Unexpected return message '${JSON}'"
  echo "Expected a JSON Response"
  exit 3
fi

SHARDS=$(echo "${JSON}" | jq "._shards.total")

if [[ "${EXIT_CODE}" -eq 0 ]] && [[ "${SHARDS}" -eq 0 ]]; then
  DECODED_CURRENT_INDEX_NAME=$(urldecode "${CURRENT_INDEX_NAME}")
  DECODED_OLD_INDEX_NAME=$(urldecode "${OLD_INDEX_NAME}")
  echo "CHECK UNKNOWN - There are no shards associated to the indices"
  echo "'${DECODED_CURRENT_INDEX_NAME}' nor for '${DECODED_OLD_INDEX_NAME}'"
  exit 3
fi

LOG_TIMESTAMP=$(echo "$JSON" | jq -r ".hits.hits | .[] | ._source.${INGESTED_TIME_FIELD}")


if [[ "${EXIT_CODE}" -ne 0 ]] || [[ -z "${LOG_TIMESTAMP}" ]]; then
  echo "CHECK UNKNOWN - Not able to collect data neither for '${CURRENT_INDEX_NAME}' nor for '${OLD_INDEX_NAME}' indices"
  echo "Request to Elastic APIs exits with code ${EXIT_CODE} and timestamp '${INGESTED_TIME_FIELD}' is not extracted"
  echo "JSON_RESPONSE: ${JSON}"
  exit 3
fi

LOG_TIMESTAMP_SEC=$(date -u +%s -d "${LOG_TIMESTAMP}")

TIME_DIFF="$(($(date +%s)-LOG_TIMESTAMP_SEC))"


PERFORMANCE_DATA=$(build_performance_data ${TIME_DIFF} ${WARNING_THRESHOLD_SEC} ${CRITICAL_THRESHOLD_SEC})
DATE_OUTPUT=$(date "${OUTPUT_DATE_FORMAT}" -d "${LOG_TIMESTAMP}")

if [[ ${TIME_DIFF} -gt ${CRITICAL_THRESHOLD_SEC} ]]; then
    echo "CHECK CRITICAL - last log dated \"${DATE_OUTPUT}\". Index '${INDEX_STATIC_NAME}' is not collecting log since more than ${CRITICAL_THRESHOLD} ${THRESHOLD_FORMAT} | ${PERFORMANCE_DATA}"
    exit 2
elif [[ ${TIME_DIFF} -gt ${WARNING_THRESHOLD_SEC} ]]; then
    echo "CHECK WARNING - last log dated \"${DATE_OUTPUT}\". Index '${INDEX_STATIC_NAME}' is not collecting log since more than ${WARNING_THRESHOLD} ${THRESHOLD_FORMAT} | ${PERFORMANCE_DATA}"
    exit 1
else
    echo "CHECK OK - last log dated \"${DATE_OUTPUT}\" | ${PERFORMANCE_DATA}"
    exit 0
fi

