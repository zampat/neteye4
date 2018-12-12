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
   cat >>${HTTP_CONF_FILE} <<EOM
#
# This configuration file allows the neteye client software to be accessed at
# http://localhost/neteye-client-software/
#
Alias /neteyeshare /neteye/shared/neteyeshare

<Directory "/neteye/shared/neteyeshare">
    AuthType Basic
    AuthName "Restricted Files"
    # (Following line optional)
    AuthBasicProvider file
    AuthUserFile "/usr/local/httpd/passwd"
    Require user sharero
    Options Indexes
</Directory>
EOM

   echo "[!] Now please reload service httpd to activate new neteyeshare weblink"
   echo "    systemctl restart httpd.service"
   echo "  "
   echo "[i] Login on web via: https://neteye_fqdn/neteyeshare"
   echo "    Username: ${HTTP_USERNAME}"
   echo "    Password: ${HTTP_PASSWORD}"
   echo "  "
fi
