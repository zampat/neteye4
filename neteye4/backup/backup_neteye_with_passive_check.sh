#! /bin/sh
#
# To correctly execute this script you need to create a new service template (look at Director-Basket_PassiveMonitoring.json) and a new API user with this permissions:
#
#[root@neteye4 ~]# cat /neteye/shared/icinga2/conf/icinga2/conf.d/api-users.conf
#/**
# * The ApiUser objects are used for authentication against the API.
# */
#object ApiUser "passivecheck" {
#  password = "MYSERCUREPASSWORD"
#  // client_cn = ""
#
#  permissions = [
#
#    "objects/query/Host",
#    "objects/query/Service",
#    "actions/process-check-result",
#]
#}


scriptname=$(hostname)
HOSTNAME="neteye4.mydomain.tld"
SERVICENAME="NetEye local backup"
API_USER="passivecheck"
API_PWD="MYSERCUREPASSWORD"
NETEYE_API_ACTION="https://neteye4.mydomain.tld:5665/v1/actions/process-check-result"

export PATH=$PATH:/bin:/sbin:/usr/bin:/usr/sbin

if [ -e /etc/sysconfig/neteye-backup.conf ]
then
	source /etc/sysconfig/neteye-backup.conf
fi

if [ -z "$BACKUPDIR" ]
then
	BACKUPDIR=/data/backup
fi
if [ -z "$NETBACKUPDIR" ]
then
	NETBACKUPDIR=/cifs/backup
fi

if [ -z "$BKDIRS" ]
then
	BKDIRS="/etc /neteye/local /neteye/shared /usr/lib64/neteye/monitoring /usr/share/snmp/mibs /var/spool/neteye /var/spool/cron /usr/local /opt /root $BACKUPDIR/db"
fi

if [ -n "$EXCLUDELIST" ]
then
	EXCLOPTS="--wildcards"
	for i in $EXCLUDELIST
	do
		EXCLOPTS="$EXCLOPTS --exclude $i"
	done
fi

if [ "$1" = "--test" ]
then
	shift
	ECHO="echo"
fi

if [ "$1" = "--view" ]
then
	shift
	VIEW=1
fi

if [ "$1" = "--dbonly" ]
then
	shift
	DBONLY=1
fi

if [ "$1" = "-d" ]
then
	shift
	dirs_to_add="$1"
	shift
fi

if [ ! -z "$1" ]
then
	export NETBACKUPDIR=$1
fi

if [ ! -d $BACKUPDIR/db ]
then
	mkdir -p $BACKUPDIR/db
fi

if [ ! -z "$VIEW" ]
then
	echo $BKDIRS
	exit 0
fi

#
# Export the DB's in single file and one x table
#
for i in `mysql -BNe "show databases" 2>/dev/null`
do
	if [ -z "$ECHO" ]
	then
		if [ ! -d $BACKUPDIR/db/$i ]
		then
			mkdir -p $BACKUPDIR/db/$i
		fi
		mysqldump --single-transaction --quick --skip-lock-tables --create-options --skip-disable-keys --skip-add-drop-table --skip-add-locks --skip-quote-names --skip-extended-insert $i | gzip >$BACKUPDIR/db/$i.sql.gz
		for j in $(mysql -BNe "show tables from $i")
		do
		mysqldump  --skip-lock-tables --create-options --skip-disable-keys --skip-add-drop-table --skip-add-locks --skip-quote-names --skip-extended-insert $i $j | gzip >$BACKUPDIR/db/$i/$j.sql.gz
		done
	else
		echo "mysqldump --skip-lock-tables --create-options --skip-disable-keys --skip-add-drop-table --skip-add-locks --skip-quote-names --skip-extended-insert $i | gzip >$BACKUPDIR/db/$i.sql.gz"
		for j in $(mysql -BNe "show tables from $i")
		do
			echo "mysqldump --skip-lock-tables --create-options --skip-disable-keys --skip-add-drop-table --skip-add-locks --skip-quote-names --skip-extended-insert $i $j | gzip >$BACKUPDIR/db/$i/$j.sql.gz"
		done
	fi
done 2>&1 | grep -v "Warning: Skipping the data of table mysql.event"

ret_mysql=$?

# Extra Information
## Track installed RPMs
/usr/bin/rpm -qa >$BACKUPDIR/rpm-fulllist.txt

## Track running services in case of cluster
if [ -f /usr/sbin/pcs ]
then
   	/usr/sbin/pcs status > $BACKUPDIR/cluster_services_status.txt
	BKDIRS="$BKDIRS $BACKUPDIR/rpm-fulllist.txt $BACKUPDIR/cluster_services_status.txt $dirs_to_add"
else 
   	/usr/sbin/neteye status > $BACKUPDIR/standalone_services_status.txt
	BKDIRS="$BKDIRS $BACKUPDIR/rpm-fulllist.txt $BACKUPDIR/standalone_services_status.txt $dirs_to_add"
fi


#Stop now if only DB-backup was required
if [ -n "$DBONLY" ]
then
	exit 0
fi

BKNAME="$scriptname-neteye-backup.tar.gz"

if [ -f $BACKUPDIR/$BKNAME ]
then
	$ECHO mv $BACKUPDIR/$BKNAME $BACKUPDIR/${BKNAME}.old
fi

#$ECHO tar ${EXCLOPTS} ${TAROPTS} -czf $BACKUPDIR/$BKNAME $BKDIRS 2>&1 | grep -v "tar: Removing leading" | grep -v "socket ignored" | grep -v "file changed as we read" | grep -v "Cannot stat: No such file or directory" | grep -v "File removed before we read it" | grep -v "Error exit delayed from previous errors" | grep -v "Exiting with failure status due to previous errors"
$ECHO tar ${EXCLOPTS} ${TAROPTS} -Pczf $BACKUPDIR/$BKNAME $BKDIRS --warning=no-file-changed
ret_tar=$?

if [ "$NETBACKUPDIR" != "NONE" ]
then
	ls $NETBACKUPDIR/ >/dev/null 2>&1
	if [ -L $NETBACKUPDIR ]
	then
		NETBACKUPDIR=$(ls -l $NETBACKUPDIR | awk '{ print $11 }')
	fi
	if ! df | grep $NETBACKUPDIR >/dev/null
	then
		if grep $NETBACKUPDIR /etc/fstab >/dev/null
		then
			mount $NETBACKUPDIR
			didmount=1
		else
			echo "Please specify the $NETBACKUPDIR mount in /etc/fstab, file not copied to netbackup server!"
			exit 10
		fi
	fi

	if ! df | grep $NETBACKUPDIR >/dev/null
	then
		echo "$NETBACKUPDIR *not* mounted, refusing to copy locally!"
		exit 20
	fi

	$ECHO cp $BACKUPDIR/$BKNAME $NETBACKUPDIR
	ret_remote_copy=$?
	$ECHO umount $NETBACKUPDIR > /dev/null 2>&1
fi

if [ $ret_mysql = 0 ] && [ $ret_tar = 0 ] && [ $ret_remote_copy = 0 ]; then
        curl -k -s -u $API_USER:$API_PWD -H "Accept: application/json" \
        -X POST $NETEYE_API_ACTION \
        -d '{ "type": "Service", "filter": "host.name==\"'$HOSTNAME'\" && service.name==\"'"$SERVICENAME"'\"", "exit_status": '0', "plugin_output": "[OK] NetEye Local Backup Done without errors\n"}'
        exit 0
else
        curl -k -s -u $API_USER:$API_PWD -H "Accept: application/json" \
        -X POST $NETEYE_API_ACTION \
        -d '{ "type": "Service", "filter": "host.name==\"'$HOSTNAME'\" && service.name==\"'"$SERVICENAME"'\"", "exit_status": '1', "plugin_output": "[WARNING] NetEye Local Backup Done with possible errors:\nmysqldump exit code:'$ret_mysql'\ntar exit code:'$ret_tar'\nremote copy exit code:'$ret_remote_copy'\n"}'
        exit 1
fi
