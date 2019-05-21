# NetEye operating system setup

## Accessing the system
Access the console via monitor and keyboard in case of hardware, via VM console in case of virtual environment.
The default credential must be changed after login (enforced by system policy)
```
user: root
password: admin
```

## Configure OS

NetEye 4 provides a logic to automate many setup tasks. Basic OS configurations are still required:
- System Hostname and DNS registration
- Timezone
- Network configuration
- Mail relay
- Customize credentials

__Important Information on Host Names__
NetEye 4 uses encrypted communications everywhere. One of the parameters for the certificates is the host name. This means that if you have a typo when you enter the host name, or use upper case one time and lower case another, then the certificate will not be accepted and communication with the server will not be possible.

### Configurations to perform on operating system

Define system’s host name
```
[root@neteye ~]# hostnamectl set-hostname <hostname.domain>
[root@neteye ~]# cat /etc/hosts
127.0.0.1   localhost localhost.localdomain localhost4 localhost4.localdomain4
::1         localhost localhost.localdomain localhost6 localhost6.localdomain6
<NetEye IP> <hostname.domain> <hostname>
```

Configure NIC
```
[root@neteye ~]# cat /etc/sysconfig/network-scripts/ifcfg-<interface>
BOOTPROTO=static #To configure according to the client
ONBOOT=yes
IPADDR=<NetEye IP>
NETMASK=<Subnet Masl>
GATEWAY=<Default Gateway IP>
```
Set DNS Resolution
```
[root@neteye ~]# cat /etc/resolv.conf
search <domain>
nameserver <DNS Server 1 IP>
nameserver <DNS Server 2 IP>
```
Update system’s time zone
```
[root@neteye ~]# timedatectl set-timezone Europe/Rome
[root@neteye ~]# cat /etc/opt/rh/rh-php71/php.d/30-timezone.ini
date.timezone="Europe/Rome"
[root@neteye ~]# systemctl restart rh-php71-php-fpm.service
```
Set mail relay for Postfix
```
[root@neteye ~]# cat /etc/postfix/main.cf
relayhost = [<SMTP Relay Server IP or FQDN>]
[root@neteye ~]# systemctl restart postfix.service
```
Ensure your system is up-to-date
```
[root@neteye ~]# yum update
[root@neteye ~]# yum --enablerepo=neteye update
[root@neteye ~]# yum --enablerepo=neteye groupinstall neteye
[root@neteye ~]# yum --enablerepo=neteye groupinstall neteye-logmanagement
```

[<<< Back to documentation overview <<<](./README.md)
