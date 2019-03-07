
# NetEye ITOA Software and Configurations overview

IT operations analytics (ITOA) provides a solution to collect and archive performance data from various sources. The frequency of collection can be high and the contents indexed within a timeseries database.

The architecture consits of infrastructure of:
1. collecting agents
2. NetEye: collector for streaming data
3. NetEye: forwarder to database

# Setup and Configuration

## collecting agents

We make use of telegraf agents and provide various configuration to collect data of interest from systems.
The telegraf agents stream their data to a central collector (installed on NetEye).

The agent is compatible with Windows, Linux/Unix.
[Configuration samples and instructions are found here](agents/)


## NetEye: collector of streaming data and forwarder to database

The collector service is provided as package for NetEye3 and NetEye4. You can [install the collector and find the relative how-to in the folder neteye_nats_collector](neteye_nats_collector/)



