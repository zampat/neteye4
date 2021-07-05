#!/bin/sh
#
CONFIG=/neteye/shared/nginx/conf/conf.d/elasticsearch-loadbalanced.conf

if [ -z "$1" ]
then
        echo "USAGE: $(basename $0) <servername>"
        exit 3
fi

if [ ! -e $CONFIG ]
then
        exit 0
fi

TMPFILE=$(mktemp nginx_enable.XXXXXXXXXX)
trap 'rm -f $TMPFILE; exit 1' 1 2 15
trap 'rm -f $TMPFILE' 0

HOST=$(echo $1 | cut -d: -f1)
if echo $1 |grep : >/dev/null
then
	PORT=$(echo $1 | cut -d: -f2)
fi
IP=$(getent hosts | grep $HOST | awk '{print $1}')

if [ -n "$IP" ]
then
	if [ -n "$PORT" ]
	then
		HSTR=$IP:$PORT
	else
		HSTR=$IP
	fi
else
	if [ -n "$PORT" ]
	then
		HSTR=$HOST:$PORT
	else
		HSTR=$HOST
	fi
fi
if ! egrep "^#.*$HSTR" $CONFIG >/dev/null
then
        exit 0
fi
cp -a $CONFIG $TMPFILE
sed -i "s/#\(.*$HSTR.*\)/\1/g" $TMPFILE
if ! diff $CONFIG $TMPFILE >/dev/null
then
        cp -a $TMPFILE $CONFIG
        /usr/bin/systemctl reload nginx
fi
