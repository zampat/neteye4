#!/bin/sh
#
# Wait a moment so cronjob check does not fail
#
SAHI_HOME=/neteye/local/sahipro
if [ -e /etc/sysconfig/sahipro ]
then
        . /etc/sysconfig/sahipro
fi
PROG=$(basename $SAHI_HOME)
#
# If no enabled for runlevel on this host ignore command
#
if ! systemctl status $PROG |grep Loaded|grep enabled >/dev/null
then
        exit 0
fi

if [ "$1" = "-f" ]
then
        shift
        WAIT=0
else
        sleep $[ ( $RANDOM % 20 )  + 2 ]s
        WAIT=60
fi

#/usr/bin/ssh nginx.neteyelocal /neteye/shared/monitoring/bin/nginx_disable_server.sh $(hostname -s).neteyelocal:9999
while [ $WAIT -gt 0 ]
do
        if ! ps -ef | grep -v grep | egrep 'phantomjs|firefox|chrome' >/dev/null
        then
                WAIT=0
        fi
        WAIT=$(expr $WAIT - 1)
        sleep 1
done
/usr/bin/systemctl stop $PROG
pkill -9 phantomjs
pkill -9 firefox
pkill -9 chrome
rm -f $SAHI_HOME/userdata/database/*
/usr/bin/systemctl start $PROG
#/usr/bin/ssh nginx.neteyelocal /neteye/shared/monitoring/bin/nginx_enable_server.sh $(hostname -s).neteyelocal:9999
