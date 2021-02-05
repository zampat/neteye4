#!/bin/sh
#
HOST=$1
USER=$2
DOMAIN=$3

if [ -n "$DOMAÏN" ]
then
	RETSTR=$(curl -k -s "https://$HOST/v0/flows/run/?username=$DOMAIN\\$USER")
else
	RETSTR=$(curl -k -s "https://$HOST/v0/flows/run/?username=$USER")
fi

if ! echo $RETST | grep true >/dev/null
then
	if [ -n "$DOMAÏN" ]
	then
		echo "OK - Workflow $DOMAIN\\$USER started"
	else
		echo "OK - Workflow $USER started"
	fi
else
	if [ -n "$DOMAÏN" ]
	then
		echo "CRITICAL - Could not start workflow for user $DOMAIN\\$USER"
	else
		echo "CRITICAL - Could not start workflow for user $USER"
	fi
fi
