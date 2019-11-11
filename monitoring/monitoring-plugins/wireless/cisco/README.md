# Wireless controller
## Cisco WLC wireless monitoring
I will provide you the commands to setup the monitoring

First copy all the included MIB files to the NetEye default folder:
```
cp mibs/* /usr/share/snmp/mibs/
```

Create a new influx database
```
influx
CREATE DATABASE telegraf WITH DURATION 90d
quit
```

Install telegraf on NetEye if not already present:
```
yum install telegraf --enablerepo=neteye
```

Copy the telegraf configuration file into the right folder and add its daemon:
```
cp telegraf.conf /neteye/shared/telegraf/
chkconfig --add telegraf
```

Remember to edit the /neteye/shared/telegraf/telegraf.conf file and put the Cisco WLC controller IP address and read SNMP community to access it.
See lines:
```
[[inputs.snmp]]
  agents = [ "PUT Cisco WLC IP address HERE" ]
  version = 2
  community = "public"
```


Start the telegraf service:
```
service telegraf start
```

Now you can import the included sample Dashboards into Grafana to display the collected data
