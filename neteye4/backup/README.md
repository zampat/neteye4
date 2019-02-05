# Script to backup configuration files and databases of NetEye 

## What is under backup:
- All active Databases
- All configurations, log files and datafiles of standalone neteye services
- All configurations, log files and datafiles of cluster neteye services
- Allow to include/exclue additional paths 

## Install this backup script:
```
backup_neteye.sh:   /usr/local/sbin
neteye-backup.conf: /etc/sysconfig/
```

## Schedule backup:
Define cron job:
```
#crontab -e
#Backup of neteye at 20:00.
0 20 * * * /usr/local/sbin/backup_neteye.sh >/dev/null
```
