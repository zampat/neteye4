#! /bin/sh
#
SAHIUID=417

if [ -z "$1" ]
then
	echo "USAGE: $(basename $0) <sahi-dir>"
	exit 1
fi
if [ ! -d "$1/userdata" ]
then
	echo "DIR ($1) does not exist or is no sahi-install directory! Did you install sahi-package?!"
	echo "USAGE: $(basename $0) <sahi-dir>"
	exit 1
fi

if grep ^sahi /etc/group >/dev/null
then
	groupadd -g $SAHIUID sahi
fi
if grep ^sahi /etc/passwd >/dev/null
then
	useradd -u $SAHIUID -g sahi sahi
fi

#
# VNC Server Installation
#
yum -y install tigervnc-server metacity xterm tmpwatch rpm/*.rpm
cp etc/vncserver@.service /etc/systemd/system/
systemctl daemon-reload
echo "Starting VNC Daemon insert password if requested"
/usr/sbin/runuser -l sahi -c '/usr/bin/vncserver :99 -localhost'
systemctl enable vncserver@:99.service

chown -R sahi:sahi $1
cp bin/startsahi.sh $1/userdata/bin
cp config/browser_types.xml $1/userdata/config
cat config/userdata.properties.add >>$1/userdata/config/userdata.properties
cp config/sysconfig.cfg $1/config/
cp etc/sahipro.cron.hourly /etc/cron.hourly/sahipro
cp etc/sahipro*.service /etc/systemd/system/
systemctl daemon-reload
mkdir -p /neteye/shared/monitoring/data/sahipro/logs/tmp
chown -R sahi:icinga /neteye/shared/monitoring/data/sahipro/logs
chmod 0775 /neteye/shared/monitoring/data/sahipro/logs
chmod 0775 /neteye/shared/monitoring/data/sahipro/logs/tmp
cp etc/sahipro.conf /etc/httpd/conf.d/
if [ -e /etc/neteye-cluster ]
then
	pcs resource restart httpd
else
	systemctl restart httpd
fi
mkdir -p /neteye/shared/monitoring/data/sahipro/scripts/lib
chown sahi:sahi /neteye/shared/monitoring/data/sahipro/scripts
cp lib/neteye.sah /neteye/shared/monitoring/data/sahipro/scripts/lib/
ln -s /neteye/shared/monitoring/data/sahipro/scripts $1/userdata/scripts/sah
cp phantomjs/* $1/ext/phantomjs/
cp plugin/check_sahipro /neteye/shared/monitoring/plugins/
