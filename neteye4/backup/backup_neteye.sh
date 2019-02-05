#! /bin/sh
#
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
		mysqldump --skip-lock-tables --create-options --skip-disable-keys --skip-add-drop-table --skip-add-locks --skip-quote-names --skip-extended-insert $i | gzip >$BACKUPDIR/db/$i.sql.gz
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

# Extra Infromation
## Track installed RPMs
/usr/bin/rpm -qa >$BACKUPDIR/rpm-fulllist.txt

## Track running services in case of cluster
if pcs >/dev/null 2>&1
then
   pcs status > $BACKUPDIR/cluster_services_status.txt
else 
   /usr/sbin/neteye status > $BACKUPDIR/standalone_services_status.txt
fi


#Stop now if only DB-backup was required
if [ -n "$DBONLY" ]
then
	exit 0
fi

BKNAME="neteye-backup.tar.gz"

if [ -f $BACKUPDIR/$BKNAME ]
then
	$ECHO mv $BACKUPDIR/$BKNAME $BACKUPDIR/${BKNAME}.old
fi

BKDIRS="$BKDIRS $BACKUPDIR/rpm-fulllist.txt $dirs_to_add"

$ECHO tar ${EXCLOPTS} ${TAROPTS} -czf $BACKUPDIR/$BKNAME $BKDIRS 2>&1 | grep -v "tar: Removing leading" | grep -v "socket ignored" | grep -v "file changed as we read" | grep -v "Cannot stat: No such file or directory" | grep -v "File removed before we read it" | grep -v "Error exit delayed from previous errors" | grep -v "Exiting with failure status due to previous errors"

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
$ECHO umount $NETBACKUPDIR > /dev/null 2>&1
fi
