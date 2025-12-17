# Get Ready after setup of Neteye ISO

## NetEye operating system setup

Reference to neteye.guide: [system setup](https://neteye.guide/4.45/getting-started/system-installation/acquire-iso-image.html)

Configure master or [satellite according] (https://neteye.guide/4.45/getting-started/system-installation/single-node-and-satellites.html)

### Define system’s host name

__Important Information on Host Names__
NetEye 4 uses encrypted communications everywhere. One of the parameters for the certificates is the host name. This means that if you have a typo when you enter the host name, or use upper case one time and lower case another, then the certificate will not be accepted and communication with the server will not be possible.
Avoid SPACE _ and special characters in hostname
```
[root@neteye ~]# hostnamectl set-hostname <hostname.domain>
[root@neteye ~]# cat /etc/hosts
127.0.0.1   localhost localhost.localdomain localhost4 localhost4.localdomain4
::1         localhost localhost.localdomain localhost6 localhost6.localdomain6
<NetEye IP> <hostname.domain> <hostname>
```

### Configure NIC via network manager

use nmcli or nmtui

### Timezone config:

```
[root@neteye ~]# timedatectl set-timezone Europe/Rome
[root@neteye ~]# timezone=`timedatectl status | grep "Time zone" | cut -d : -f 2 | tr -d '[:space:]' | cut -d "(" -f 1`; echo "date.timezone=\"$timezone\"" > /neteye/local/php/conf/php.d/30-timezone.ini
Verify timezone:
[root@neteye ~]# cat /neteye/local/php/conf/php.d/30-timezone.ini
date.timezone="Europe/Rome"
[root@neteye ~]# systemctl restart php-fpm.service
```

## Set mail relay for Postfix
```
[root@neteye ~]# cat /etc/postfix/main.cf
relayhost = [<SMTP Relay Server IP or FQDN>]
[root@neteye ~]# systemctl restart postfix.service
```

## Once accomplished you have
- Timezone
- Network and Hostname defined
- generated tags and registered the host in repo
- Mail relay

[<<< Back to documentation overview <<<](./README.md)
