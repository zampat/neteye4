#!/bin/sh

# Version 0.0.3 2010-08-18
# Verify that the sensors check returns data. If not, return unknown to nagios.

# Version 0.0.2 2010-05-11
# Ulric Eriksson <ulric.eriksson@dgc.se>

BASEOID=.1.3.6.1.3.94
SYSTEMOID=$BASEOID.1.6
connUnitStateOID=$SYSTEMOID.1.5
# 1 = unknown, 2 = online, 3 = diag/offline
connUnitStatusOID=$SYSTEMOID.1.6
# 3 = OK, 4 = warning, 5 = failed
connUnitProductOID=$SYSTEMOID.1.7
# e.g. "QLogic SANbox2 FC Switch"
connUnitSnOID=$SYSTEMOID.1.8
# chassis serial number
connUnitNumSensorsOID=$SYSTEMOID.1.14
# number of sensors in connUnitSensorTable
connUnitNameOID=$SYSTEMOID.1.20
# symbolic name
connUnitContactOID=$SYSTEMOID.1.23
connUnitLocationOID=$SYSTEMOID.1.24

SENSOROID=$BASEOID.1.8
connUnitSensorIndexOID=$SENSOROID.1.2
connUnitSensorNameOID=$SENSOROID.1.3
# textual id of sensor
connUnitSensorStatusOID=$SENSOROID.1.4
# 1 = unknown, 2 = other, 3 = ok, 4 = warning, 5 = failed
connUnitSensorMessageOID=$SENSOROID.1.6
# textual status message

PORTOID=$BASEOID.1.10
connUnitPortUnitIdOID=$PORTOID.1.1
connUnitPortIndexOID=$PORTOID.1.2
connUnitPortTypeOID=$PORTOID.1.3
connUnitPortStateOID=$PORTOID.1.6
# user selected state
# 1 = unknown, 2 = online, 3 = offline, 4 = bypassed, 5 = diagnostics
connUnitPortStatusOID=$PORTOID.1.7
# actual status
# 1 = unknown, 2 = unused, 3 = ready, 4 = warning, 5 = failure
# 6 = notparticipating, 7 = initializing, 8 = bypass, 9 = ols, 10 = other
# Always returns 2, so this is utterly useless
connUnitPortSpeedOID=$PORTOID.1.15
# port speed in kilobytes per second

usage()
{
	echo "Usage: $0 -H host -C community -T status|sensors"
	exit 3
}


get_system()
{
        echo "$SYSTEM"|grep "^$1."|head -1|sed -e 's,^.*: ,,'
}

get_sensor()
{
        echo "$SENSOR"|grep "^$2.*$1 = "|head -1|sed -e 's,^.*: ,,'
}

get_port()
{
        echo "$PORT"|grep "^$2.*$1 = "|head -1|sed -e 's,^.*: ,,'
}

if test "$1" = -h; then
	usage
fi

while getopts "H:C:T:" o; do
	case "$o" in
	H )
		HOST="$OPTARG"
		;;
	C )
		COMMUNITY="$OPTARG"
		;;
	T )
		TEST="$OPTARG"
		;;
	* )
		usage
		;;
	esac
done

RESULT=
STATUS=0	# OK

case "$TEST" in
sensors )
	SENSOR=`snmpwalk -v 1 -c $COMMUNITY -On $HOST $SENSOROID`
	# Figure out which sensor indexes we have
	connUnitSensorIndex=`echo "$SENSOR"|
	grep -F "$connUnitSensorIndexOID."|
	sed -e 's,^.*: ,,'`
	for i in $connUnitSensorIndex; do
		connUnitSensorName=`get_sensor $i $connUnitSensorNameOID`
		connUnitSensorStatus=`get_sensor $i $connUnitSensorStatusOID`
		connUnitSensorMessage=`get_sensor $i $connUnitSensorMessageOID`
		RESULT="$RESULT$connUnitSensorName = $connUnitSensorMessage
"
		if test "$connUnitSensorStatus" != 3; then
			STATUS=2	# Critical
		fi
	done
	if test -z "$SENSOR"; then
		STATUS=3	# Unknown
	fi
	;;
status )
	SYSTEM=`snmpwalk -v 1 -c $COMMUNITY -On $HOST $SYSTEMOID`
	connUnitStatus=`get_system $connUnitStatusOID`
	connUnitProduct=`get_system $connUnitProductOID`
	connUnitSn=`get_system $connUnitSnOID`
	case "$connUnitStatus" in
	3 )
		RESULT="Overall unit status: OK"
		;;
	4 )
		RESULT="Overall unit status: Warning"
		STATUS=1
		;;
	5 )
		RESULT="Overall unit status: Failed"
		STATUS=2
		;;
	* )
		RESULT="Overall unit status: Unknown"
		STATUS=3
		;;
	esac
	if test ! -z "$connUnitProduct"; then
		RESULT="$RESULT
Product: $connUnitProduct"
	fi
	if test ! -z "$connUnitSn"; then
		RESULT="$RESULT
Serial number: $connUnitSn"
	fi
	;;
* )
	usage
	;;
esac

echo "$RESULT"
exit $STATUS
