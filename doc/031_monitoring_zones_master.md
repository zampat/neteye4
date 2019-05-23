# Monitoring Zones and Endpoints configuration: Master node

NetEye comes with a default Endpoint name, that does not correstpond to your FQDN. This is a problem when deploying Agents not able to resolve that name.
Therefore we need to:
- change the name of the Endpoint
- Generate the certificates
- Validate configuration and align your director configuration

__Remember Master vs. Satellite configuration__
*Service Name:	icinga2-master.service*
*ConfigDir:		/neteye/shared/icinga2/conf/icinga2*


Define Hostname in /etc/hosts
```
192.168.11.72   neteye4_trainer_master.neteye.lab  neteye4_trainer_master
192.168.11.73   neteye4_trainer_satellite.neteye.lab  neteye4_trainer_satellite
```

Define Hostname and Zone in constants.conf
```
const NodeName = "neteye4_trainer_master"
const ZoneName = "master"
```

__Breaking note:__ When removing an Endpoint from zones.conf while still using this endpoint name as Endpoint for Director or other monitoring orjects, you need FIRST to migrate those elements to the new endpoint before removing the old one. Therefore:
1. leave old endpoint in zones.conf and add the new one 
2. add new endpoint to zones.conf and generate certificates
3. validate and reload Icinga2-master service
4. Align Director and monitoring
5. Remove old Endpoint definition

__Define Endpoint and Zone in zones.conf__
```
#This is the new Endpoint
object Endpoint "neteye4_trainer_master" {
}
#This is the Endpoint to remove
object Endpoint "icinga2-master.neteyelocal" {
}
object Zone "master" {
   endpoints = [ "icinga2-master.neteyelocal", "neteye4_trainer_master" ]
}
```

__Generate certificates for each icinga2 satellite__

Note: Generate and sign certificates where icinga2-master service is running!
Certificate creation for new endpoint:
- Create certificate for new hostname and .csr (signing request)
- Sign certificate request with icings2-master service
```
# cd /neteye/shared/icinga2/data/lib/icinga2/certs/
# export icinga_node_name="neteye4vm1.yourdomain.local"
# icinga2 pki new-cert --cn "${icinga_node_name}" --key "${icinga_node_name}.key" --cert "${icinga_node_name}.crt" --csr "${icinga_node_name}.csr"
# icinga2-master pki sign-csr --csr ${icinga_node_name}.csr --cert ${icinga_node_name}.crt
```

Validate Icinga2 configuration:
```
# /usr/sbin/icinga2-master daemon --validate
```

See Problems from icinga2 log
```
# journalctl -u icinga2-master
```

Restart icinga2-master service
```
# systemctl restart icinga2-master.service
```

Synchronize Director to Icinga2 Infrastructure defining now the new Endpoint name
Icinga Director -> Infrastructure -> Kickstart Wizard

[<<< Back to documentation overview <<<](./README.md)
