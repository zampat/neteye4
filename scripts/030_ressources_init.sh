#!/bin/bash

# Add default ressources to icingaweb2 config
# file: resources.ini

#Define Variables
# ARG1: ICINGA2_CONF_HOME_DIR="/neteye/shared/icingaweb2/conf"
FILE_RESSOURCES="$1/resources.ini"

# Check if a demo Ressource for LDAP exists
grep "ldap" $FILE_RESSOURCES > /dev/null 2>&1
RES=$?
if [ $RES -ne 0 ]
then
   echo "[i] 030: Adding LDAP configuration sample to Icinga2 Ressources."

   cat >>$FILE_RESSOURCES <<EOM

[ldap_bind.sample (change also auth.>user and auth.>groups)]
type = "ldap"
hostname = "dc.mydomain.local"
port = "389"
encryption = "none"
root_dn = "dc=mydomain,dc=local"
bind_dn = "ldapRO@mydomain.local"
bind_pw = "password"

[Sample remote MYSQL ressource]
type = "db"
db = "mysql"
host = "192.168.200.200"
port = "3306"
dbname = "dbname"
username = "username"
password = "password"
charset = "utf8"
use_ssl = "0"
EOM

else
   echo "[ ] LDAP configuration in Icinga2 Ressources already exists."
fi
