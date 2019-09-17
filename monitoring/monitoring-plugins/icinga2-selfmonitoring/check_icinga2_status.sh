#!/bin/sh
#
#######################################################################
#                                                                     #
#  ICINGA2 Plugin for checking the valid status of a running icinga2  #
#                              created by Matthias J. Schmaelzle      #
#     	                                  Version 1.00 / 2019-11-09   #
#######################################################################


# Changelog
# Date          Author      Version     Comment
# 2019-07-20    MJS     (Ver. 1.00)     Initial


# Define global varibales
# ======================================
#
PROGNAME=`basename $0`
VERSION="Version 1.00"
AUTHOR="Matthias Schmaezle (http://www.mjs.de)"

# Define the exit codes
STATE_OK=0
STATE_WARNING=1
STATE_CRITICAL=2
STATE_UNKNOWN=3



# Running the check plugin
# ======================================
#

# Check the icinga deamon and running state
ICINGA_STATUS=`systemctl status icinga2 status >/dev/null 2>&1; echo $?`
ICINGA_STATUS_RUNNING=`systemctl status icinga2 | head -n6 | grep "Active:" | sed 's/^[ \t]*//' | awk -F' since ' '{print $1}'`


# Check if the icinga deamon is NOT running and exit with a CRITICAl state
if [ "$ICINGA_STATUS" != "0" ]; then
        echo "CRITICAL: The ICINGA2 Daemon is NOT running"
        exit $STATE_CRITICAL

# Check if the icinga deamon is running, have an invalid running state and exit with a CRITICAl state
elif [ "$ICINGA_STATUS_RUNNING" != "Active: active (running)" ]; then
        echo "CRITICAL: The ICINGA2 Daemon is running but have an invalid running state of >> $ICINGA_STATUS_RUNNING <<"
        exit $STATE_CRITICAL

# Exit with an OK state if everthing is fine
else
        echo "OK: The ICINGA2 Daemon is running and have a valid running state of >> $ICINGA_STATUS_RUNNING <<"
        exit $STATE_OK
fi


