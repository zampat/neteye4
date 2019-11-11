# LogManager and SIEM community getting stated

### Searchguard - advanced configuration how-to via command line interface
The searchguard modules handles and protects access via Kibana to your documents stored in elasticsearch database.
The NetEye user guide provides in chapter "Log Manger" an important introduction. 
Advanced configuration scenarios concern:
- Backup and restore of SearchGuard configuration
- LDAP integration and authentication via AD Groups

[This how-to is provided here.](searchguard/README.md)

### Elastic performance tuning hints
Section elastic/elasticsearch_config provides some configuration parameters you should review for performance tuning.
[Related hints and external resources here.](elastic/elasticsearch_config/README.md)

### EventHandler integration of LogManager
By default incoming log messages from LogManager are not forwarded for events processing to EventHandler of NetEye.
To activate the forwarding of all incoming Log-Messages to the Eventhandler you can place the provided rsyslog action to the includes directory of rsyslog server of NetEye.
To do so copy the configuration file into the rsyslog.d folder and restart the rsyslog-logmanager service:
```
cp ./eventhandler/aa_forward_all_to_eventhandler.conf /neteye/shared/rsyslog/conf/rsyslog.d
Standalone: systemctl restart rsyslog-logmanager.service
Cluster: pcs resource restart rsyslog-logmanager
```
