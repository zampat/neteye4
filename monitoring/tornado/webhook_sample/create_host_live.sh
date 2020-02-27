#!/bin/bash

TEMPLATE="generic-tornado"
HOST="tornado_lab"
IP="127.0.0.1"
TEMPL="generic_passive_service"

SERVICE="$1"
if [[ -z "$1" ]] ; then
    echo "Service Name missing!"
    exit 1
fi
STATUS="$2"
if [[ -z "$2" ]] ; then
    echo "Service Status integer missing!"
    exit 1
fi
OUTPUT="$3"
if [[ -z "$3" ]] ; then
    echo "Plugin output missing!"
    exit 1
fi
PERFDATA="$4"
if [[ -z "$4" ]] ; then
    echo "Optional Plugin perfdata missing"
    PERFDATA="perf=1"
fi


export ICINGAWEB_CONFIGDIR=/neteye/shared/icingaweb2/conf/
RES=`icingacli director host exists "$HOST"`
if [[ $RES =~ "does not exist" ]]
then
   #echo "Host '$HOST' does not exists"
icingacli director host create "$HOST" --imports "$TEMPLATE" --address "$IP" --vars.created_by Tornado --experimental live-creation
fi

RES=`icingacli director service exists "$TEMPL"`
if [[ $RES =~ "exists" ]]
then

  OBJ=$SERVICE
  RES=`icingacli director service exists "$OBJ"`
  if [[ $RES =~ "does not exist" ]]
  then

     echo "Service '$OBJ' does not exists"
     icingacli director service create --json '
{
    "imports": [
        "'${TEMPL}'"
    ],
    "object_name": "'${SERVICE}'",
    "object_type": "object",
    "host": "'${HOST}'"
}'
    RES=$?
    if [ $RES -eq 0 ]
    then
       echo "New service created. Deploy required !!"
       # now deploy configuration
       icingacli director config deploy

       # Waiting for 5 secons after deploy
       echo "Waiting for 5 secons after deploy"
       sleep 5
    fi
  fi
fi



#Define Status for Service
curl -k -s -u root:974a00c8931bbaac -H 'Accept: application/json' -X POST 'https://localhost:5665/v1/actions/process-check-result' -d '{ "type": "Service", "filter": "host.name==\"tornado_lab\" && service.name==\"'${SERVICE}'\"", "exit_status": '${STATUS}', "plugin_output": "'${OUTPUT}'", "performance_data": [ "'${PERFDATA}'", "perf1=1" ], "check_source": "neteye.mydomain.lan", "pretty": true }'
