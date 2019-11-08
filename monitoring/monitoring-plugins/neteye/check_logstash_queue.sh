#!/bin/bash

# Original author: Mirko Bez (mirko.bez <at> wuerth-phoenix.com)
#
#
#

#
# The aim of this check is to detect the type of queue and launch warning or critical status if the size of the queue
# reaches a certain percentage of the available space
#
# Elasticsearch documentation about logstash queues:
# https://www.elastic.co/guide/en/logstash/7.3/persistent-queues.html
#
# Perhaps, in this case one could choose to use a small percentage value for the warning threshold,
# because it is already a warning that the queue is going to be filled.
#


readonly PROGRAM_NAME=$(basename "$0")
readonly OK=0
readonly WARNING=1
readonly CRITICAL=2
readonly UNKNOWN=3


build_performance_data() {
    local METRIC_NAME=$1
    local VALUE=$2
    local WARNING_THRESHOLD=$3
    local CRITICAL_THRESHOLD=$4
    echo "${METRIC_NAME}=${VALUE};${WARNING_THRESHOLD};${CRITICAL_THRESHOLD};;"
}

check_threshold_existence() {
    local WARNING_THRESHOLD=$1
    local CRITICAL_THRESHOLD=$2
    # Check if warning threshold smaller than critical one
    if [[ "$CRITICAL_THRESHOLD" -lt "${WARNING_THRESHOLD}" ]];
    then
      echo "CHECK UNKNOWN - Critical Threshold '${CRITICAL_THRESHOLD}' should be bigger than or equal to warning threshold '${WARNING_THRESHOLD}'"
      exit "${UNKNOWN}"
    fi
}

from_bytes_to_target() {
    # Convert the bytes number into the corresponding target representation
    local BYTES=$1
    local TARGET=$2
    local DIVISOR=""
    case "${TARGET}" in
      KB)
        # 10^3
        DIVISOR=1000;;
      MB)
        # 10^6
        DIVISOR=1000000;;
      GB)
        # 10^9
        DIVISOR=1000000000;;
      TB)
        # 10^12
        DIVISOR=1000000000000;;
      KiB)
        # 2^10
        DIVISOR=1024;;
      MiB)
        # 2^20
        DIVISOR=1048576;;
      GiB)
        # 2^30
        DIVISOR=1073741824;;
      TiB)
        # 2^40
        DIVISOR=1099511627776;;
      *)
        "Unsupported output target ${TARGET}"
        exit ${UNKNOWN}
        ;;
    esac
    echo "$(bc <<< "scale=4; ${BYTES}/${DIVISOR}")" | awk '{printf "%.3f", $1 }'
}




# Default Values that can be overwritten by options
WARNING_THRESHOLD=70
CRITICAL_THRESHOLD=90
OUTPUT_FORMAT="MiB"
LOGSTASH_HOST="localhost"
LOGSTASH_PORT="9600"
LOGSTASH_PROTOCOL="http"
LOGSTASH_VERSION="auto"
PIPELINE_NAME="main"
THRESHOLD_FORMAT="percentage"
CURL_COMMAND_PATH="/usr/bin/curl"
CURL_CERT=""
CURL_PRIVATE_KEY=""
WARNING_ON_NUMBER=0
CRITICAL_ON_NUMBER=0





function print_help() {
  # Print the help message and exit
  echo "$1: check the status of the logstash queue."
  echo -e "\t Usage: $1 [OPTION]..."
  echo ""
  echo -e "\t-c, --critical-threshold (int): the critical threshold (default: ${CRITICAL_THRESHOLD}, 0 to disable it)"
  echo -e "\t-w, --warning-threshold (int): the warning threshold (default: ${WARNING_THRESHOLD}, 0 to disable it)"
  echo -e "\t--threshold-format (str): the unit of measure for the thresholds \
one of 'percentage, MB, GB' (default ${THRESHOLD_FORMAT})"
  echo -e "\t--logstash-host (str): the elasticsearch host or ip (default: ${LOGSTASH_HOST})"
  echo -e "\t--logstash-port (int): the elasticsearch port (default: ${LOGSTASH_PORT})"
  echo -e "\t--logstash-protocol (str): the protocol used to connect to elasticsearch (default: ${LOGSTASH_PROTOCOL})"
  echo -e "\t--logstash-version (int|str): Major Logstash version (supported options: 6, 7, 'auto'). 'auto' tries to autodetect the version (default: 'autodetect')"
  echo -e "\t--curl-command-path (str): path to a curl executable to use (default: '${CURL_COMMAND_PATH}')"
  echo -e "\t--curl-cert (str): path to the client's certificate (check: man curl for details) (default: '${CURL_CERT}')"
  echo -e "\t--curl-key (str): path to the private key of the client (check: man curl for details) (default: ${CURL_PRIVATE_KEY}')"
  echo -e "\t--output-format (str): choose how to show the output. Currently, KiB, MiB, GiB, TiB, KB, MB, GB and TB are supported (default: ${OUTPUT_FORMAT})"
  echo -e "\t--critical-on-number (int): set the warning on the number of events (default: 0, i.e., no critical for the number of events)"
  echo -e "\t--warning-on-number (int): set the warning on the number of events (default: 0, i.e., no warning for the number of events)"
}


# Retrieving the command line options. Each shift, discard one argument.
while [[ $# -gt 0 ]]
do
  key="$1"

  case ${key} in
      "-c"|"--critical-threshold")
      CRITICAL_THRESHOLD="$2"; shift; shift;;
      "-w"|"--warning-threshold")
      WARNING_THRESHOLD="$2"; shift; shift;;
      "--output-format")
      OUTPUT_FORMAT="$2"; shift; shift;;
      "--threshold-format")
      THRESHOLD_FORMAT="$2"; shift; shift;;
      "--logstash-host")
      LOGSTASH_HOST="$2"; shift; shift;;
      "--logstash-port")
      LOGSTASH_PORT="$2"; shift; shift;;
      "--logstash-protocol")
      LOGSTASH_PROTOCOL="$2"; shift; shift;;
      "-h"|"--help")
      print_help "${PROGRAM_NAME}"
      exit 2
      ;;
      "--curl-command-path")
      CURL_COMMAND_PATH="$2"; shift; shift;;
      "--curl-cert")
      CURL_CERT="$2"; shift; shift;;
      "--curl-key")
      CURL_PRIVATE_KEY="$2"; shift; shift;;
      "--warning-on-number")
      WARNING_ON_NUMBER="$2"; shift; shift;;
      "--critical-on-number")
      CRITICAL_ON_NUMBER="$2"; shift; shift;;
      "--logstash-version")
      LOGSTASH_VERSION="$2"; shift; shift;;
      *)    # unknown option
        echo "Unknown parameter $key: $2"
        help
        exit 3
      ;;
  esac
done

check_threshold_existence "${WARNING_THRESHOLD}" "${CRITICAL_THRESHOLD}"
check_threshold_existence "${WARNING_ON_NUMBER}" "${CRITICAL_ON_NUMBER}"

# Getting LOGSTASH VERSION:
BASE_URL="${LOGSTASH_PROTOCOL}://${LOGSTASH_HOST}:${LOGSTASH_PORT}/"

# Building the url
URL="${BASE_URL}/_node/stats/pipelines"

PIPELINE_OUTPUT=$("${CURL_COMMAND_PATH}" -s -X GET "${URL}")

EXIT_CODE="$?"

QUEUE_OUTPUT=$(echo "${PIPELINE_OUTPUT}" | jq ".pipelines.${PIPELINE_NAME}.queue")

if [[ "${EXIT_CODE}" -ne 0 ]]; then
  echo "CHECK UNKNOWN - Not able to collect queue information for ${PIPELINE_NAME}. ${URL} seems to be not reachable"
  exit ${UNKNOWN}
fi

if [[ -z "${QUEUE_OUTPUT}" ]]; then
    echo "CHECK UNKNOWN - Perhaps ${QUEUE_OUTPUT} does not contain a pipeline named '${PIPELINE_NAME}'?"
    exit ${UNKNOWN}
fi


if [[ "${LOGSTASH_VERSION}" == "auto" ]]; then
    BASIC_INFO=$("${CURL_COMMAND_PATH}" -s -X GET "${BASE_URL}")

    EXIT_CODE="$?"

    if [[ "${EXIT_CODE}" -ne 0 ]]; then
      echo "CHECK UNKNOWN - Not able to collect basic info for. ${URL} seems to be not reachable"
      exit ${UNKNOWN}
    fi

    LOGSTASH_VERSION=$(echo ${BASIC_INFO} | jq -r ".version" | sed  "s/\([0-9]\)\.[0-9]\.[0-9]/\1/")
fi

case "${LOGSTASH_VERSION}" in
  6)
    QUEUE_TYPE=$(echo "${QUEUE_OUTPUT}" | jq -r ".type")
    QUEUE_EVENTS_COUNT=$(echo "${QUEUE_OUTPUT}" | jq -r ".events")
    QUEUE_SIZE=$(echo "${QUEUE_OUTPUT}" | jq -r ".capacity.queue_size_in_bytes")
    QUEUE_MAX_SIZE=$(echo "${QUEUE_OUTPUT}" | jq -e -r ".capacity.max_queue_size_in_bytes")
    LAST_STATUS=$?
    ;;
  7)
    QUEUE_TYPE=$(echo "${QUEUE_OUTPUT}" | jq -r ".type")
    QUEUE_EVENTS_COUNT=$(echo "${QUEUE_OUTPUT}" | jq -r ".events_count")
    QUEUE_SIZE=$(echo "${QUEUE_OUTPUT}" | jq -r ".queue_size_in_bytes")
    QUEUE_MAX_SIZE=$(echo "${QUEUE_OUTPUT}" | jq -r ".max_queue_size_in_bytes")
    LAST_STATUS=$?
    ;;
  *)
    echo "CHECK UNKNOWN - Unsupported logstash version '${LOGSTASH_VERSION}'. Version supported 6.x and 7.x"
    exit ${UNKNOWN}
esac

if [[ "${LAST_STATUS}" -ne 0 ]]; then
    echo "CHECK UNKNOWN - Logstash version ${LOGSTASH_VERSION} was chose/detected but the format do not comply with \
         the expected one."
fi

# Avoid division by 0
if [[ ${QUEUE_MAX_SIZE} -eq 0 ]];
then
    PERCENTAGE=0
else
    # Print also leading 0's
    PERCENTAGE=$(echo $(bc <<< "scale = 3; 100*$QUEUE_SIZE / $QUEUE_MAX_SIZE") | awk '{printf "%.3f", $1 }')
fi

MESSAGE="Queue of type '${QUEUE_TYPE}' in pipeline '${PIPELINE_NAME}' contains ${QUEUE_EVENTS_COUNT} events. \
Totally, ~$(from_bytes_to_target "${QUEUE_SIZE}" "${OUTPUT_FORMAT}") ${OUTPUT_FORMAT} of \
$(from_bytes_to_target "${QUEUE_MAX_SIZE}" "${OUTPUT_FORMAT}") ${OUTPUT_FORMAT} are occupied."


PERFORMANCE_DATA=$(build_performance_data "occupied_size" "${PERCENTAGE}%" "${WARNING_THRESHOLD}" "${CRITICAL_THRESHOLD}")
PERFORMANCE_DATA_EVENT=$(build_performance_data "number_of_events" "${QUEUE_EVENTS_COUNT}" "${WARNING_ON_NUMBER}" "${CRITICAL_ON_NUMBER}")


if [[ $(bc <<< "${PERCENTAGE} > ${CRITICAL_THRESHOLD}") -eq 1 ]] || [[ ${CRITICAL_ON_NUMBER} -ne 0 && "${QUEUE_EVENTS_COUNT}" -gt "${CRITICAL_ON_NUMBER}" ]]; then
    echo "CHECK CRITICAL - ${MESSAGE} | ${PERFORMANCE_DATA} ${PERFORMANCE_DATA_EVENT}"
    exit ${CRITICAL}
elif [[ $(bc <<< "${PERCENTAGE} > ${WARNING_THRESHOLD}") -eq 1 ]] || [[ ${WARNING_ON_NUMBER} -ne 0 && "${QUEUE_EVENTS_COUNT}" -gt "${WARNING_ON_NUMBER}" ]]; then
    echo "CHECK WARNING - ${MESSAGE} | ${PERFORMANCE_DATA} ${PERFORMANCE_DATA_EVENT}"
    exit ${WARNING}
else
    echo "CHECK OK - ${MESSAGE} | ${PERFORMANCE_DATA} ${PERFORMANCE_DATA_EVENT}"
    exit ${OK}
fi