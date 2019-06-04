
# Installation of NetEye data streaming architecture for ITOA

Here you find instructions for configuring the streaming server listining for incoming data and the forwarder into the database.


## Install streaming server

The straming server "nats-straming-server" is installed and configured to listen on all interfaces for incoming data.

1. Install the package (valid for NetEye 3 and NetEye 4)
```
yum --enablerepo=neteye install nats-streaming-server
```

2. Configuration of streaming server

Enable Nats input listener on all interfaces

Solution 1: Replace the provided nats configuration file **stan.conf** in:
- NetEye 3: /etc/nats/stan.conf
- NetEye 4: /neteye/shared/nats/conf/stan.conf

Solution 2: Patch the nats configuration file **stan.conf** with provided changes
a) enable listening of nats on *ALL* interfaces on port 4222
```
NetEye 3/4: 
# patch /etc/nats/stan.conf < ./stan_enablePublicListener.conf.diff
```

Enable and start nats streaming service (example valid for NetEye 4)
```
# systemctl start nats-streaming-server.service
# systemctl status nats-streaming-server.service
# systemctl enable nats-streaming-server.service
```

# Installation of forwarder to database

1. Install telegraf package (valid for NetEye 3 and NetEye 4)
```
# yum --enablerepo=neteye install telegraf.x86_64
```

2. Configuration of Telegraf to consume data from nats streaming server

- Copy a new telegraf configuration to run collection as separate instance
- Path on NetEye 3: /etc/nagios/neteye/telegraf/ 
- Path on NetEye 4: /neteye/shared/telegraf/
- Patch new telegraf configuration file to enable:
  - nats input 
  - influx output

```
NetEye 3: 
# export TELEGRAFCONFDIR="/etc/nagios/neteye/telegraf"
NetEye 4: 
# export TELEGRAFCONFDIR="/neteye/shared/telegraf"

# cp $TELEGRAFCONFDIR/sample_telegraf.conf.tpl $TELEGRAFCONFDIR/telegraf.conf
# patch $TELEGRAFCONFDIR/telegraf.conf < ./telegraf_inputsNats_consumer.conf.diff
```

Enable and start telegraf collector service (example valid for NetEye 4)
```
# systemctl start telegraf.service
# systemctl status telegraf.service
# systemctl enable telegraf.service
```

# Advanced topics

[Setup of neteye itos as both local consumer and forwarder of performance data] (neteye_nats_proxy.md)
