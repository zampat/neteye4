#!/bin/bash

WARNING_HOURS=2
CRITIAL_HOURS=4

function check {
if [[ $LOG_TIMESTAMP_SEC -le "$1" ]]; then
	echo "$LOG_TIMESTAMP_SEC" "$1"
        echo "Logstash is not collection logs since $2 hours ago"
        echo "Last log is: $LOG_TIMESTAMP"
        exit "$3"
fi
}

while [[ $# -gt 0 ]]
do
key="$1"

case $key in
    -c)
    CRITIAL_HOURS="$2"
    shift # past argument
    shift # past value
    ;;
    -w)
    WARNING_HOURS="$2"
    shift # past argument
    shift # past value
    ;;
    *)    # unknown option
      echo "Unknown parameter $1 : $2"
      exit 3
    ;;
esac
done

JSON="$(/usr/share/neteye/scripts/searchguard/sg_neteye_curl.sh -XGET "https://elasticsearch.neteyelocal:9200/%3Clogstash-%7Bnow%2Fd%7D%3E/_search" -H 'Content-Type: application/json' -d'
{
  "_source": ["@timestamp"],
  "size": 1,
  "sort": [
    {
      "@timestamp": {
        "order": "desc"
      }
    }
  ]
}')"
EXIT_CODE=$?

LOG_TIMESTAMP=$(echo "$JSON" | jq -r '.hits.hits | .[] | .["_source"] | .["@timestamp"]')

if [ $EXIT_CODE -ne 0 ] || [ -z "$LOG_TIMESTAMP" ]; then
  echo "Not able to collect data for today Logstash indices"
  echo "Request to Elastic APIs exits with code $EXIT_CODE and timestamp is not extracted"
  exit 3
fi

LOG_TIMESTAMP_SEC=$(date -u +%s -d "$LOG_TIMESTAMP")
WARNING_HOURS_AGO=$(date -u +%s -d "$WARNING_HOURS hours ago")
CRITIAL_HOURS_AGO=$(date -u +%s -d "$CRITIAL_HOURS hours ago")

check "$CRITIAL_HOURS_AGO" "$CRITIAL_HOURS" 2
check "$WARNING_HOURS_AGO" "$WARNING_HOURS" 1


exit 0