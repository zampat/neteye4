#!/bin/bash

HTTP_PASSWD_FOLDER="/usr/local/httpd"
HTTP_PASSWD_FILE="${HTTP_PASSWD_FOLDER}/passwd"
HTTP_CONF_FILE="/etc/httpd/conf.d/neteye-share.conf"

HTTP_USERNAME="sharero"
HTTP_PASSWORD="R3ad0nLy_#12"

#Create folder structure
if [ ! -d $HTTP_PASSWD_FOLDER ]
then

   echo "[+] Initializing NetEye-Share: Web Alias"
   echo "    Creating Folder ${HTTP_PASSWD_FOLDER}"
   mkdir ${HTTP_PASSWD_FOLDER}

   echo "[+] Registering new HTTP user: ${HTTP_USERNAME}"
   htpasswd -b  -c ${HTTP_PASSWD_FILE} ${HTTP_USERNAME} ${HTTP_PASSWORD}
fi

if [ ! -f ${HTTP_CONF_FILE} ]
then
   cp neteye4/neteyeshare/neteye-share.conf  ${HTTP_CONF_FILE}

   echo "[!] Now please reload service httpd to activate new neteyeshare weblink"
   echo "    systemctl restart httpd.service"
   echo "  "
   echo "[i] Login on web via: https://neteye_fqdn/neteyeshare"
   echo "    Username: ${HTTP_USERNAME}"
   echo "    Password: ${HTTP_PASSWORD}"
   echo "  "
fi
