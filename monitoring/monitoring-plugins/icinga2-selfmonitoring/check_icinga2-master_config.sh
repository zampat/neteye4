#!/bin/sh
#
#######################################################################
#                                                                     #
#     ICINGA2 Plugin for checking the valid ICINGA2 configuration     #
#                              created by Matthias J. Schmaelzle      #
#                                              Version 1.00 / 2019    #
#######################################################################


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

ICINGA_STATUS=`icinga2-master daemon --validate >/dev/null 2>&1; echo $?`

if [ "$ICINGA_STATUS" = 0 ]; then
	echo "OK: The ICINGA2 Syntax is valid and running"
	exit $STATE_OK
else
	echo "CRITICAL: The ICINGA2 Syntax is invalid and can not run on a productiv environment"
	exit $STATE_CRITICAL
fi

