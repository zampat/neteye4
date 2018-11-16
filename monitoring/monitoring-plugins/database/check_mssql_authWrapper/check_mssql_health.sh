#!/bin/sh
#
WAITMAX=/usr/bin/waitmax
TIMEOUT="-s 9 60"
NAGIOS_PATH=`dirname $0`
PWDFILE="/etc/nagios/neteye/plugins/mssql/auth.conf"
PROG=$(basename $0)

if [ -f $PWDFILE ]
then
	ASUSER="--username `cat $PWDFILE |grep -e username | cut -d = -f 2`"
	ASPASS="--password `cat $PWDFILE |grep -e password | cut -d = -f 2`"
else
	echo "WARNING: Password file $PWDFILE not found!"
fi

MSSQL_HEALTH="/usr/lib/nagios/plugins/check_mssql_health $ASUSER $ASPASS"

if [ -x $WAITMAX ]
then
	$WAITMAX $TIMEOUT $MSSQL_HEALTH $* 
else
	$MSSQL_HEALTH $* 
fi

