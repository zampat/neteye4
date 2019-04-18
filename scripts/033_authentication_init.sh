#!/bin/bash

# Init: Authentication users definition

#Define Variables
# ARG1: ICINGA2_CONF_HOME_DIR="/neteye/shared/icingaweb2/conf"
FILE_AUTHENTICATION="$1/authentication.ini"

# Check if a sample Authentication for LDAP exists
grep "ldap" $FILE_AUTHENTICATION > /dev/null 2>&1
RES=$?
if [ $RES -ne 0 ]
then

   echo "[i] 033: Adding LDAP Authentication sample."

   cat >>$FILE_AUTHENTICATION <<EOM

[ldap_bind.local]
resource = "ldap_bind.local"
user_class = "user"
filter = "!(objectClass=computer)"
user_name_attribute = "sAMAccountName"
backend = "ldap"
base_dn = "DC=mydomain,DC=local"
EOM

   #Adapt permissions for folder and file
   chown apache:icingaweb2 $FILE_AUTHENTICATION
   chown apache:icingaweb2 $FILE_AUTHENTICATION
else
   echo "[ ] 033: LDAP Authentication sample already exists."
fi
