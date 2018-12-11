#!/bin/sh
#
NAGIOS_PATH=`dirname $0`
PWDFILE="/etc/nagios/neteye/plugins/mssql/auth.conf"
PROG=$(basename $0)

SECTION=$1
MSSQL_CMD_ARGS=$*
SECTION_FOUND_LINE="0"

if [ -f $PWDFILE ]
then

   for i in `cat $PWDFILE`
   do
	
	if [[ $i =~ .*$SECTION.* ]]
	then
	   SECTION_FOUND_LINE="1"
	fi

	if [ $SECTION_FOUND_LINE -eq "1" ] && [[ $i =~ .*username* ]]
	then 
	   USER=`echo $i | cut -d = -f 2`
	fi
	if [ $SECTION_FOUND_LINE -eq "1" ] && [[ $i =~ .*password* ]]
	then 
	   PASSWD=`echo $i | cut -d = -f 2`
	   SECTION_FOUND_LINE="0"
	fi
   done

else
	echo "UNKNOWN: Password file $PWDFILE not found!"
	exit 3;
fi

if [ -z $USER ] || [ -z $PASSWD ]
then
   echo "Usage: $PROG 'section_of_password' 'all check_mssql_health parameters'"
   echo " "
   echo "Define Section, username and password within authentication file: "
   echo "   $PWDFILE "
   exit 3
fi

MSSQL_HEALTH="$NAGIOS_PATH/check_mssql_health --username $USER --password $PASSWD"

$MSSQL_HEALTH $MSSQL_CMD_ARGS 
exit $?
