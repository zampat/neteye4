
# NetEye ITOA Software and Configurations overview

IT operations analytics (ITOA) provides a solution to collect and archive performance data from various sources. The frequency of collection can be high and the contents indexed within a time series database.

The architecture consists of infrastructure of:
1. Performance data collecting agents
2. Dashboards for Grafana
3. NetEye: collector of streaming data and forwarder to database

## Performance data collecting agents

We make use of telegraf agents to collect performance data at high frequency. Various configuration samples are provided the telegraf agent, to collect performance data from Windows and Linux.
Additional projects with connectors towards nats/influx are available too. Those configurations are under development (check out the various branches)

[Agent setup & configuration](agent_configurations/)

## Dashboards for Grafana
Make use of suitable dashboards importable into Grafana. Great examples are provided by community.
[List of collected Grafana dashboards](dashboards/)

## NetEye: collector of streaming data and forwarder to database

The collector service is provided as package for NetEye3 and NetEye4. You can [install the collector and find the relative how-to in the folder neteye_nats_collector](neteye_dataConsumer_infrastructure/)



