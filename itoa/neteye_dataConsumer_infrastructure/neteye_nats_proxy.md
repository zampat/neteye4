# Introduction

This configuration allows the setup of a NetEye as both, data consumer and forwarder, acting in this way as proxy 

# Configuration

### 1. Enable local nats server to forward data stream to local telegraf consumer

Edit `stan.conf`:
```
  routes = [
    nats-route://route_user:password!@neteye-remote.mydomain:4244
    # Add this row to write data also locally
    nats-route://route_user:password!@127.0.0.1:4244
```

### 2. Configure telegraf to consume data from nats and forward it into influxdb

```
[[outputs.influxdb]]
  urls = ["http://localhost:8086"] # required
  ## The target database for metrics (telegraf will create it if not exists).
  database = "itoa_metrics" # required

 ## Retention policy to write to. Empty string writes to the default rp.
  retention_policy = "2_weeks"
  ## Write consistency (clusters only), can be: "any", "one", "quorum", "all"
  write_consistency = "any"

  ## Write timeout (for the InfluxDB client), formatted as a string.
  ## If not provided, will default to 5s. 0s means no timeout (not recommended).
  timeout = "5s"
  # username = "telegraf"
  # password = "metricsmetricsmetricsmetrics"
  ## Set the user agent for HTTP POSTs (can be useful for log differentiation)
  user_agent = "neteye01"

[[inputs.nats_consumer]]
  ### urls of NATS servers
  servers = ["nats://localhost:4222"]
  ### Use Transport Layer Security
  secure = false
  ### subject(s) to consume
  subjects = ["my_subject"]
  ### name a queue group
  queue_group = "neteye_local"
  ### Maximum number of metrics to buffer between collection intervals
  metric_buffer = 100000

  ### Data format to consume. This can be "json", "influx" or "graphite"
  ### Each data format has it's own unique set of configuration options, read
  ### more about them here:
  ### https://github.com/influxdata/telegraf/blob/master/DATA_FORMATS_INPUT.md
  data_format = "influx"
```
