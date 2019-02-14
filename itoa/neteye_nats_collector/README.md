
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

## Configuration of Telegraf consumer from nats streaming server

- Copy a new telegraf configuration to run collection as separate instance
- Path NetEye 3: /etc/nagios/neteye/telegraf/ 
- Path NetEye 4: /neteye/shared/telegraf/
- Patch new telegraf configuration file to enable:
  - nats input 
  - influx output

```
NetEye 3: 
# export TELEGRAFCONFDIR="/etc/nagios/neteye/telegraf"
NetEye 4: 
# export TELEGRAFCONFDIR="/neteye/shared/telegraf"

# cp $TELEGRAFCONFDIR/sample_telegraf.conf.tpl $TELEGRAFCONFDIR/telegraf.conf
# patch $TELEGRAFCONFDIR/telegraf.conf < ./neteye4_monitoring_share/itoa/neteye_nats_collector/telegraf_inputsNats_consumer.conf.diff
```

Enable and start telegraf collector service
```
# systemctl start telegraf.service
# systemctl status telegraf.service
# systemctl enable telegraf.service
```
