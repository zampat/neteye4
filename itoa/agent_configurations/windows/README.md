# Setup Telegraf

Download latest version from [Influx](https://portal.influxdata.com/downloads/)
```
wget https://dl.influxdata.com/telegraf/releases/telegraf-1.10.2_windows_amd64.zip
unzip telegraf-1.10.2_windows_amd64.zip
```
Installation of Telegraf agent on windows:
```
Install Service:

>telegraf.exe -service install --service-name=neteye_telegraf --config "C:\Program Files\Telegraf\telegraf.conf" --config-directory "C:\Program Files\Telegraf\conf.d\"

Uninstall Service:
>telegraf.exe -service uninstall --service-name=neteye_telegraf
```

## Configuration of agent and setup of windows service
[Configure telegraf according the official guide of the agent](https://github.com/influxdata/telegraf/blob/master/docs/WINDOWS_SERVICE.md)

## Grafana dashboard

[Community telegraf dashboard for grafana](../../dashboards/README.md)
