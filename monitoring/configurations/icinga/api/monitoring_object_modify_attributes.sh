#!/bin/bash

while getopts 'o:n:v:h' OPT; do
  case $OPT in
    o)  object_name=$OPTARG;;
    n)  attr_name=$OPTARG;;
    v)  attr_value=$OPTARG;;
    h)  hlp="yes";;
    *)  unknown="yes";;
  esac
done

# usage
HELP="
    usage: $0 [ -o object_name -v attr_value [ -n attr_name ][-h] ]
    Example: monitoring_object_modify_attributes.sh -o hostname_1 -v true

    syntax:

            -o --> object_name
            -n --> ottr_name
            -v --> ottr_value
            -h --> print this help screen
    exit 3
"

if [ "$hlp" = "yes" -o "$1" = "--help" ]; then
  echo "$HELP"
  exit 0
fi


if [ -n "$object_name" ]; then
   HOSTNAME=$object_name
else
   echo "Pleae define the hostname with parameter -o "
   exit 3
fi

OBJECT_ATTRIBUTE_NAME="enable_active_checks"

if [ -n "$attr_value" ]; then
   OBJECT_ATTRIBUTE_VALUE=$attr_value
else
   echo "Pleae define the attribute value with parameter -v "
   exit 3
fi


# Update host
curl -k -s -u "objectsmodify:123456789" -H "Accept: application/json" -X 'POST' "https://localhost:5665/v1/objects/hosts?host=${HOSTNAME}" -d '{ "attrs": { "'${OBJECT_ATTRIBUTE_NAME}'": '${OBJECT_ATTRIBUTE_VALUE}' }, "pretty": true }'

# Update related services
 curl -k -s -u "objectsmodify:123456789" -H "Accept: application/json" -X 'POST' 'https://localhost:5665/v1/objects/services' \
-d '{ "filter": "regex(pattern, host.name)", "filter_vars": { "pattern": "'${HOSTNAME}'" }, "attrs": { "'${OBJECT_ATTRIBUTE_NAME}'": '${OBJECT_ATTRIBUTE_VALUE}' }, "pretty": true }'
