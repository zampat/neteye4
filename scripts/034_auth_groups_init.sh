#!/bin/bash

# Init: Authentication groups definition

#Define Variables
# ARG1: ICINGA2_CONF_HOME_DIR="/neteye/shared/icingaweb2/conf"
FILE_GROUPS="$1/groups.ini"

# Check if a sample groups for LDAP exists
grep "ldap" $FILE_GROUPS > /dev/null 2>&1
RES=$?
if [ $RES -ne 0 ]
then

   echo "[i] 034: Adding LDAP Groups Authentication sample."

   cat >>$FILE_GROUPS <<EOM

[ldap_bind.local]
resource = "ldap_bind.local"
user_backend = "ldap_bind.local"
nested_group_search = "1"
backend = "msldap"
EOM

   #Adapt permissions for folder and file
   chown apache:icingaweb2 $FILE_GROUPS
   chown apache:icingaweb2 $FILE_GROUPS

else
   echo "[ ] 034: LDAP Groups Authentication sample already exists."
fi
