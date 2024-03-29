# Script to backup configuration files and databases of NetEye 

## What is under backup:
- All active Databases
- All configurations, log files and data files of standalone neteye services
- All configurations, log files and data files of cluster neteye services
- Allow to include/exclude additional paths 

## Requirement for backup on remote cifs mount

```
yum install cifs-utils pigz
```

## Register remote mount point
```
vi /etc/fstab
//mydomain.lan/Backups/NetEye4   /cifs/backup     cifs    defaults,auto,username=neteye,password=secret,dom=mydomain.lan,file_mode=0666,dir_mode=0777   0       0
```

## Raise MySQL max connections limit
```
cat >>/neteye/shared/mysql/conf/my.cnf.d/neteye.cnf <<EOM
[mysqld]
max_connections = 250
EOM
```

## Install this backup script:
```
backup_neteye.sh:   /usr/local/sbin
neteye-backup.conf: /etc/sysconfig/
```

## Schedule backup:
Define cron job:
```
#crontab -e

#Backup only DB on active mysql server of neteye at 20:00.
0 20 * * * /usr/bin/df | grep mysql$ > /dev/null 2>&1 && /usr/local/sbin/backup_neteye.sh --dbonly >/dev/null
#Only local backup neteye data at 20:00 (no copy to cifs share).
0 20 * * * /usr/local/sbin/backup_neteye.sh NONE >/dev/null
```
