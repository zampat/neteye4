# Icinga2 agent setup on RHEL/CENTOS
- Install icinga repo: 
```
wget http://packages.icinga.com/epel/ICINGA-release.repo -O /etc/yum.repos.d/ICINGA-release.repo
```
- Check the repo creation:
```
cat /etc/yum.repos.d/ICINGA-release.repo

[icinga-stable-release]
name=ICINGA (stable release for epel)
baseurl=http://packages.icinga.com/epel/$releasever/release/
enabled=1
gpgcheck=1
gpgkey=http://packages.icinga.com/icinga.key
```
- Install icinga agent:
```
yum --enablerepo=icinga-stable-release install icinga2-2.10.5
```

- Start and enable icinga2 service: 
```
systemctl start icinga2.service
systemctl enable icinga2.service
```
- Open Icinga Director and create manually the host where you install the agent
- From Icinga Director Host's Agent tab downlod Linux commandline script
- Execute the downloaded script
- Install monitoring plugins: 
```
yum install -y https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm
yum install nagios-plugins-users nagios-plugins-load nagios-plugins-disk nagios-plugins-procs nagios-plugins-swap nagios-plugins-ntp nagios-plugins-uptime --enablerepo=epel
```
- Check firewalld rules if needed: 
```
# firewall-cmd --state
running
# firewall-cmd --list-all | grep -i 5665
  ports: 5665/tcp 514/tcp 514/udp 

- If port 5665 is not open, a rule must be created as follows:
```
firewall-cmd --add-port 5665/tcp --permanent 
firewall-cmd --reload
```
