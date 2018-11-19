#!/bin/bash

#Define Variables
FILE_RESSOURCES="$1/resources.ini"

# Check if a demo Ressource for LDAP exists
grep "ldap" $FILE_RESSOURCES > /dev/null 2>&1
RES=$?

if [ $RES -ne 0 ]
then

echo "[i] Adding LDAP configuration sample to Icinga2 Ressources."

cat >>$FILE_RESSOURCES <<EOM

[ldap_bind.local]
type = "ldap"
hostname = "dc.mydomain.local"
port = "389"
encryption = "none"
root_dn = "dc=mydomain,dc=local"
bind_dn = "ldapRO@mydomain.local"
bind_pw = "password"
EOM
else
  echo "[ ] LDAP configuration in Icinga2 Ressources already exists."
fi
