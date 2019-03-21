# Master - Satellite setup [WIP]

This how-to describes the setup of a standalone master and standalone satellite setup, structured as 2 distinct endpoints within 2 separated zones, where satellite zone is child of master zone.


## Master setup

constants.conf
```
const NodeName = "neteye4_trainer_master"
const ZoneName = "master

```
zones.conf
```
object Endpoint "neteye4_trainer_master" {
}
object Zone "master" {
   endpoints = [ "neteye4_trainer_master" ]
}
```


## Satellite setup

Add firewall rule: Enable Icinga api protocol on port 5665/tcp  
```
firewall-cmd --zone=public --permanent --add-port=5665/tcp
```


```
zones.conf
```


