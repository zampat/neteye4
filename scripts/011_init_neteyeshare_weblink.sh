#!/bin/bash

HTTP_PASSWD_FOLDER="/neteye/shared/httpd"
HTTP_PASSWD_FILE="${HTTP_PASSWD_FOLDER}/.htpasswd"
HTTP_CONF_FILE="/etc/httpd/conf.d/neteye-share.conf"
PWD_SHARE_LOGIN="/root/.pwd_neteye_configro"

HTTP_USERNAME="configro"
#HTTP_PASSWORD="R3ad0nLy_#12"
HTTP_PASSWORD=`head /dev/urandom | tr -dc A-Za-z0-9 | head -c 13 ; echo ''`


#Create folder structure
if [ ! -f ${HTTP_PASSWD_FILE} ]
then

   echo "[+] 011: Setup of neteyeshare/: registragion in httpd and creation of new HTTP user: ${HTTP_USERNAME}."
   echo "    Creating Folder ${HTTP_PASSWD_FOLDER}"
   mkdir -p ${HTTP_PASSWD_FOLDER}

   # Create new httpd user with password to protect some folders
   htpasswd -b  -c ${HTTP_PASSWD_FILE} ${HTTP_USERNAME} ${HTTP_PASSWORD}

   if [ ! -f ${HTTP_CONF_FILE} ]
   then
      cp neteye4/neteyeshare/neteye-share.conf  ${HTTP_CONF_FILE}
   fi

   echo ${HTTP_PASSWORD} >> ${PWD_SHARE_LOGIN} 

   echo "[!] Now please reload service httpd to activate new neteyeshare weblink"
   echo "    systemctl restart httpd.service"
   echo "  "
   echo "[i] The neteyeshare comes with no authentication and can be accessed on web via: https://neteye_fqdn/neteyeshare"
   echo "    Some configuration folders are protected by these credentials: (i.e. ./monitoring/agents/microsoft/icinga/configs/)"
   echo "    Username: ${HTTP_USERNAME}"
   echo "    Password: ${HTTP_PASSWORD}"
   echo "  "
   echo "    The password is stored in: ${PWD_SHARE_LOGIN}"
   echo "  "
fi
