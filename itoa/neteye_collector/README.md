
# Installation of Nats straming server and configure it

## Install Nats streaming server

```
yum --enablerepo=neteye install nats-streaming-server
```

## Configuration

Enable Nats input listener on all interfaces

Solution 1: Replace the provided nats configuration file **stan.conf** in:
- NetEye 3: /etc/nats/stan.conf
- NetEye 4: /neteye/shared/nats/conf/stan.conf

Solution 2: Patch the nats configuration file **stan.conf** with provided changes
a) enable listening of nats on *ALL* interfaces on port 4222
```
NetEye 3/4: 
# patch /etc/nats/stan.conf < ./neteye4_monitoring_share/itoa/neteye_collector/stan_enablePublicListener.conf.diff
```

Enable and start nats streaming service
```
# systemctl start nats-streaming-server.service
# systemctl status nats-streaming-server.service
# systemctl enable nats-streaming-server.service
```

# Installation of Telegraf to collect data from nats and write to influx 

## Install Nats streaming server

```
# yum --enablerepo=neteye install telegraf.x86_64
```

# Configuration
Copy sample_telegraf.conf.tpl to telegraf.conf
- NetEye 3 path: /etc/nagios/neteye/telegraf/ 
- NetEye 4 path: /neteye/shared/telegraf/

### Enable Output writer to Influxdb
Apply patch: telegraf_outputsInfluxdb.conf.diff
```
NetEye 3:
# patch /etc/nagios/neteye/telegraf/telegraf.conf < ./neteye4_monitoring_share/itoa/neteye_collector/telegraf_outputsInfluxdb.conf.diff
NetEye 3:
# patch /neteye/shared/telegraf/telegraf.conf < ./neteye4_monitoring_share/itoa/neteye_collector/telegraf_outputsInfluxdb.conf.diff
```

### Enable input reader from Nats-consumer
```
NetEye 3:
patch /etc/nagios/neteye/telegraf/telegraf.conf < ./neteye4_monitoring_share/itoa/neteye_collector/telegraf_inputsNats_consumer.conf.diff
NetEye 4:
patch /neteye/shared/telegraf/telegraf.conf < ./neteye4_monitoring_share/itoa/neteye_collector/telegraf_inputsNats_consumer.conf.diff
```

### Enable input Http-Json reader (i.e. NetEye 3 Monitoring status from Thruk via Json)

Note: We lower the default frequency in order to avoid an overload of the json-source 
```
NetEye 3:
patch /etc/nagios/neteye/telegraf/telegraf.conf < ./neteye4_monitoring_share/itoa/neteye_collector/telegraf_inputsHttpJson.conf.diff
```


Enable and start telegraf collector service
```
# systemctl start telegraf.service
# systemctl status telegraf.service
# systemctl enable telegraf.service
```
