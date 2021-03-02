#! /bin/sh
#
DIR=$(dirname $0)

if [ -e "$DIR/check_alyvix3_testcase.pl" ]
then
	CMD="$DIR/check_alyvix3_testcase.pl"
elif [ -e /neteye/shared/monitorin/plugins/check_alyvix3_testcase.pl ]
then
	CMD=/neteye/shared/monitorin/plugins/check_alyvix3_testcase.pl
else
	echo "check_alyvix3_testcase.pl NOT found, exiting!"
	exit 3
fi

$CMD -v -v $@
exit $?
