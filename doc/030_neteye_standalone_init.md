# NetEye system setup – Assisted Setup

Ensure MariaDB, InfluxDN and Grafana services are up and running
```
[root@neteye ~]# systemctl start mariadb.service influxdb.service grafana-server.service
```
Run the secure installation script (start not running services i.e. influxdb, grafana):
```
[root@neteye ~]# /usr/sbin/neteye_secure_install
```

Assisted setup cares about:
- Configuration of NetEye as an Icinga master node: 
- Self-signing of Certificate files for Icinga2 SSL-encrypted communication
- Initial load of Icinga2 Commands provided by ITL (more details later)
- Configuration of SELinux and Firewall rules
- Initialization of all Databases
- Configuration of Influxdb and Grafana
- Generate credentials for DB access and API access and register permissions
- Enable all required services
- Setup of EventHandler
- Setup of Maps (NagVis)
- Setup of web server incl. HTTPS (self signed certificate)
- Generates random passwords for default users
- LogManager configuration, PGP key generation, integration of SearchGuard security module

## Access the web interface 

1. Verify neteye services are running
   Hint: Command to start/stop/check NetEye Services status
- Start all NetEye services: neteye start
- Stop all NetEye services: neteye stop
- Get the current status of NetEye services: neteye status

__HINT: You can anways use systemctl to interact with every single NetEye service in a Single Node Setup__

2. Now, login on NetEye web interface

__HINT: Credentials for Web-UI are generated and stored at /root/.pwd_icingaweb2_root__


[<<< Back to documentation overview <<<](./README.md)
