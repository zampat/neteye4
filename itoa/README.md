
# NetEye ITOA Software and Configurations overview

IT operations analytics (ITOA) provides an infrastructure of:
- collecting agents
- streaming data to a central data collector and
- a forwarder, writing those data into a database

## collecting architecture

We make use of telegraf agents and provide various configuration to collect data of interest from systems.
The agent is compatible with Windows, Linux/Unix.

Configuration and instructions here:
Folder: agents

## streaming data to a central data collector and forwarder to database

The telegraf agents stream their data to a central collector (installed on NetEye).
As collector we use "nats-streaming-server".
Within this folder you find also instructions for configuring the forwarder of data from streaming-server (nats) into the database (influxdb)

Packages are provided by NetEye and instructions for installation and configuration is provided here:
Folder: neteye_nats_collector

## collecting monitoring status infromation

With telegraf we can collect the current status of your monitoring objects and write them into the database influxdb.

Configuration and instructions here:
Folder: neteye_monitoring_status_collector


