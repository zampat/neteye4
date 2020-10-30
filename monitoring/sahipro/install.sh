#! /bin/sh
#
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

chown -R sahi:sahi $1/userdata
chown -R sahi:sahi $1/tools
cp bin/startsahi.sh $1/userdata/bin
cp config/browser_types.xml $1/userdata/config
cat config/userdata.properties.add >>$1/userdata/config/userdata.properties
cp config/sysconfig.cfg $1/config/
cp etc/sahipro.cron.hourly /etc/cron.hourly/sahipro
cp etc/sahipro*.service /etc/systemd/system/
systemctl daemon-reload
mkdir -p /neteye/shared/httpd/sahipro/tmp
chown -R sahi:icinga /neteye/shared/httpd/sahipro
chmod 0775 /neteye/shared/httpd/sahipro
chmod 0775 /neteye/shared/httpd/sahipro/tmp
cp etc/sahipro.conf /etc/httpd/conf.d/
systemctl restart httpd
mkdir -p /neteye/local/monitoring/data/sahipro/scripts/lib
chown sahi:sahi /neteye/local/monitoring/data/sahipro/scripts
cp lib/neteye.sah /neteye/local/monitoring/data/sahipro/scripts/lib/
ln -s /neteye/local/monitoring/data/sahipro/scripts $1/userdata/scripts/sah
cp phantomjs/* $1/ext/phantomjs/
cp plugin/check_sahipro /neteye/local/monitoring/plugins/
yum install -y rpm/*.rpm
