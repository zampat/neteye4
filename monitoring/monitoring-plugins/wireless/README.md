# Wireless controller
## Unifi wireless monitoring
As introduced in my Blog Article [Monitoring a Ubiquity Unifi Wireless Controller](https://www.neteye-blog.com/2019/03/monitoring-a-ubiquity-unifi-wireless-controller/), I will provide you the commands to setup the monitoring

First install the go language framework:
```
yum install golang
```

Prepare the default folder structures
```
mkdir /root/go
mkdir /root/go/pkg
mkdir /root/go/pkg/mod
mkdir /root/go/bin
export GOPATH=/root/go
```

Get the go modules
```
go get github.com/golift/unifi
go get github.com/influxdata/influxdb1-client/v2
go get github.com/naoina/toml
go get github.com/ogier/pflag
```

Clone the unifi-poller and compile it
```
git clone https://github.com/davidnewhall/unifi-poller
cd unifi-poller
make
```

Create a new influx database
```
influx
CREATE DATABASE Unifi WITH DURATION 90d
quit
```

Copy the poller files to the destination directories
```
mkdir /usr/local/etc/unifi-poller
cp up.conf.example /usr/local/etc/unifi-poller/up.conf
cp unifi-poller /usr/local/bin/unifi-poller
```

Remember to edit the /usr/local/etc/unifi-poller/up.conf file and put the Unifi controller IP address, user and password to access it.


Copy the systemd service unit file to /etc/systemd/system/unifi-poller.service
```
cp startup/systemd/unifi-poller.service /etc/systemd/system/
sudo systemctl start unifi-poller
```

Thanks to the Author of the Project unifi-poller: [David Newhall II](https://github.com/davidnewhall)
