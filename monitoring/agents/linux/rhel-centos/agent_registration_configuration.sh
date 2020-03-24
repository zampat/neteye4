#!/bin/bash

#install requirements
sudo yum install https://packages.icinga.com/epel/icinga-rpm-release-7-latest.noarch.rpm -y
sudo yum install jq -y
sudo yum install epel-release -y
sudo yum install icinga2 -y
systemctl enable icinga2
systemctl start icinga2
sudo yum install nagios-plugins-all -y
sudo yum install vim-icinga2 -y
sudo yum install nano-icinga2 -y
sudo yum install git -y

#open port firewall
sudo firewall-cmd --permanent --add-port=5665/tcp
sudo firewall-cmd --permanent --add-port=5665/udp
sudo firewall-cmd --reload

#director authentication
user="director" 
password="abcdefghijklmnopqrstvwxyz01234576789"
HOST_DIRECTOR_FQDN="neteye_master.mydomain.lan"

# Token of destination host template
API_KEY="56bf777b67f6da186b609809ce97519d6397bc67"

#variables
PARENTZONE="master"
PARENTNAME="neteye_master.mydomain.lan"

AGENTNAME=$(hostname)
AGENTZONE= $(hostname)


# Start of script
curl -k -s -u $user:$password -H 'Accept: application/json' -X POST 'https://'$HOST_DIRECTOR_FQDN'/neteye/director/self-service/register-host?name='$AGENTNAME'&key='$API_KEY -d '{ "display_name": "'.$AGENTNAME.'", "address": "'.$AGENTNAME.'"  }'

TICKET=$(curl -k -s -u $user:$password -H 'Accept: application/json' -X POST 'https://'$HOST_DIRECTOR_FQDN':5665/v1/actions/generate-ticket' -d '{ "cn":"'.$AGENTNAME.'", "pretty": true }' | jq -r ".results[0].ticket" )

#set certificates

mkdir -p /var/lib/icinga2/certs

chown -R icinga:icinga /var/lib/icinga2/certs



icinga2 pki new-cert --cn $AGENTNAME --key /var/lib/icinga2/certs/$AGENTNAME.key --cert /var/lib/icinga2/certs/$AGENTNAME.crt
icinga2 pki save-cert --key /var/lib/icinga2/certs/$AGENTNAME.key  --cert /var/lib/icinga2/certs/$AGENTNAME.crt  --trustedcert /var/lib/icinga2/certs/trusted-parent.crt  --host $PARENTNAME
icinga2 node setup --ticket $TICKET  --cn $AGENTNAME  --endpoint $PARENTNAME  --zone $AGENTZONE  --parent_zone $PARENTZONE  --parent_host $PARENTNAME --trustedcert /var/lib/icinga2/certs/trusted-parent.crt --accept-commands --accept-config  --disable-confd


systemctl restart icinga2.service

