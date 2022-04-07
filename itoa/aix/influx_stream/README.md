
# Introduction

The following collection of projects allows to collect performance data from IBM AIX at a higher frequency, than a polling approach might reach.

__Advice: the following how-to is work in progress and subject to further changes/improvements__

# Setup and software requirements

## Overview of related projects

- [Project site:](http://nmon.sourceforge.net/pmwiki.php?n=Site.Njmon)
- Project site on [`sourceforge`:](https://sourceforge.net/projects/nmon/files/)


## Software from OSS repositories

- AIX Collector binaries: [`njmon_aix_binaries_v21.zip`](https://sourceforge.net/projects/nmon/files/njmon_aix_binaries_v21.zip/download)
- [Sample Grafana dashboard](https://sourceforge.net/projects/nmon/files/Grafana_Template_for_njmon_AIX_v3-1548086037850.json/download)

## Setup AIX data grabber

Compiled binary approach:
- Unzip `njmon_aix_binaries_v21.zip` and place binary for suitable AIX version 6.x or 7.x
- Define Path for Program code: `/usr/local/njmon/`
- Place Njmon binary and executable (755): i.e. `/usr/local/njmon/njmon_aix7_v80`

```
# ls -la /usr/local/njmon/
total 3840
drwxr-xr-x    2 root     system          256 Jun  6 15:59 .
drwxr-xr-x    5 root     system          256 Jun  6 13:51 ..
-rwxr-xr-x    1 root     system       766811 May 20 23:37 njmon_aix7_v80
```


## NetEye performance data handling and influx writer

### Configuration of telegraf influxdb collector

Create new influxdb user and grant permissions:
[Influxdb permissions](https://docs.influxdata.com/influxdb/v1.8/administration/authentication_and_authorization/#user-management-commands)
```
Connect to influxdb via ssl:
influx -ssl -unsafeSsl -username root -password $(cat /root/.pwd_influxdb_root) -host influxdb.neteyelocal

> CREATE USER njmon with password 'password123'
> GRANT ALL ON aix_perfdata to njmon
> show users
```
Create a local telegraf service

```
/neteye/local/telegraf/conf/customer_consumer_aix_perfdata.conf

###############################################################################
#                            OUTPUT PLUGINS                                   #
###############################################################################


# Configuration for sending metrics to InfluxDB
[[outputs.influxdb]]
  ## The full HTTP or UDP URL for your InfluxDB instance.
  urls = ["https://influxdb.neteyelocal:8086"]

  ## The target database for metrics; will be created as needed.
  ## For UDP url endpoint database needs to be configured on server side.
  database = "aix_perfdata"

  ## The value of this tag will be used to determine the database.  If this
  ## tag is not set the 'database' option is used as the default.
  # database_tag = ""

  ## If true, the 'database_tag' will not be included in the written metric.
  # exclude_database_tag = false

  ## If true, no CREATE DATABASE queries will be sent.  Set to true when using
  ## Telegraf with a user without permissions to create databases or when the
  ## database already exists.
  skip_database_creation = false

  ## Name of existing retention policy to write to.  Empty string writes to
  ## the default retention policy.  Only takes effect when using HTTP.
  # retention_policy = ""

  ## The value of this tag will be used to determine the retention policy.  If this
  ## tag is not set the 'retention_policy' option is used as the default.
  # retention_policy_tag = ""

  ## If true, the 'retention_policy_tag' will not be included in the written metric.
  # exclude_retention_policy_tag = false

  ## Write consistency (clusters only), can be: "any", "one", "quorum", "all".
  ## Only takes effect when using HTTP.
  # write_consistency = "any"

  ## Timeout for HTTP messages.
  # timeout = "5s"

  ## HTTP Basic Auth
  username = "username"
  password = "NsmLpq7ql6e77rPU"

  ## HTTP User-Agent
  # user_agent = "telegraf"

  ## UDP payload size is the maximum packet size to send.
  # udp_payload = "512B"

  ## Optional TLS Config for use on HTTP connections.
  # tls_ca = "/etc/telegraf/ca.pem"
  # tls_cert = "/etc/telegraf/cert.pem"
  # tls_key = "/etc/telegraf/key.pem"
  ## Use TLS but skip chain & host verification
  # insecure_skip_verify = false

  ## HTTP Proxy override, if unset values the standard proxy environment
  ## variables are consulted to determine which proxy, if any, should be used.
  # http_proxy = "http://corporate.proxy:3128"

  ## Additional HTTP headers
  # http_headers = {"X-Special-Header" = "Special-Value"}

  ## HTTP Content-Encoding for write request body, can be set to "gzip" to
  ## compress body or "identity" to apply no encoding.
  # content_encoding = "gzip"

  ## When true, Telegraf will output unsigned integers as unsigned values,
  ## i.e.: "42u".  You will need a version of InfluxDB supporting unsigned
  ## integer values.  Enabling this option will result in field type errors if
  ## existing data has been written.
  # influx_uint_support = false

###############################################################################
#                            INPUT PLUGINS                                    #
###############################################################################

[[inputs.influxdb_listener]]
  ## Address and port to host HTTP listener on
  service_address = ":8186"

  ## maximum duration before timing out read of the request
  read_timeout = "10s"
  ## maximum duration before timing out write of the response
  write_timeout = "10s"

  ## Maximum allowed HTTP request body size in bytes.
  ## 0 means to use the default of 32MiB.
  max_body_size = 0

  ## Maximum line size allowed to be sent in bytes.
  ##   deprecated in 1.14; parser now handles lines of unlimited length and option is ignored
  # max_line_size = 0

  ## Set one or more allowed client CA certificate file names to
  ## enable mutually authenticated TLS connections
  #tls_allowed_cacerts = ["/etc/telegraf/clientca.pem"]

  ## Add service certificate and key
  #tls_cert = "/etc/telegraf/cert.pem"
  #tls_key = "/etc/telegraf/key.pem"

  ## Optional tag name used to store the database name.
  ## If the write has a database in the query string then it will be kept in this tag name.
  ## This tag can be used in downstream outputs.
  ## The default value of nothing means it will be off and the database will not be recorded.
  ## If you have a tag that is the same as the one specified below, and supply a database,
  ## the tag will be overwritten with the database supplied.
  # database_tag = ""

  ## If set the retention policy specified in the write query will be added as
  ## the value of this tag name.
  # retention_policy_tag = ""

  ## Optional username and password to accept for HTTP basic authentication.
  ## You probably want to make sure you have TLS configured above for this.
  #basic_username = "foobar"
```

Enable and Start service
```
systemctl start telegraf-local@customer_consumer_aix_perfdata.service
systemctl status telegraf-local@customer_consumer_aix_perfdata.service
systemctl enable telegraf-local@customer_consumer_aix_perfdata.service
```


Run a Test on AIX System:

Define njmon call:
- Frequency and number of cycles. Careful, when running forever handle the stop and start. It is easier to define a interval and define the number of cycles and then restart the process by cronjob. Example:
Cycletime: 1 hour: interval=20 secs X cycles = 180 
- define destination Influxdb host and port

Sample call to send data to neteye:
```
/usr/local/njmon/njmon_aix7_v80 -s 20 -c 180 -I -i 10.1.1.100 -p 8186 -k -K /tmp/neteye_njmon.pid

Info:
-s seconds : seconds between snapshots of data (default 60 seconds)
-c count   : number of snapshots then stop     (default forever)

```

5. Register the cronjob as indicated above

```
# crontab -l
# AIX Performance data injector
*/5 * * * *     /usr/local/njmon/njmon_aix7_v80 -s 20 -c 180 -I -i 10.1.1.100 -p 8186 -k -K /tmp/neteye_njmon.pid
```

