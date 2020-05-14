# Icinga2 satellite services configuration

Overview:
icinga2-master: managed by cluster service, relocates within cluster, uses port 5665 for communication
icinga2: managed by local systemctl, provides monitoring on local node, uses port 5664 for communication

## Zoning architecture

```
zone: master
endpoints: icinga2-master

zone: satellite
endpoints: neteye4vm1.mydomain.local
parent zone: master
```

# Operations On Satellite (s) #
## Generate certificates for each icinga2 satellite
Note: Generate and sign certificates where icinga2-master service is running!
[Concepts about creating the certificates on the master](https://icinga.com/docs/icinga2/snapshot/doc/06-distributed-monitoring/#create-ca-on-the-master)
Note 2: In NetEye the service name for icinga2 master is: "icinga2-master"

## Certificate creation for satellite node (s)

- Connect to Host where icinga2 master service is running:
- Generate the certificates:
```
# cd /neteye/shared/icinga2/data/lib/icinga2/certs/
# export icinga_node_name="neteye4vm1.mydomain.local"
# icinga2 pki new-cert --cn "${icinga_node_name}" --key "${icinga_node_name}.key" --cert "${icinga_node_name}.crt" --csr "${icinga_node_name}.csr"
# icinga2-master pki sign-csr --csr ${icinga_node_name}.csr --cert ${icinga_node_name}.crt
```
- Copy or SCP the generated certificates and the CA certificate to the Icinga2 satellite
```
# scp -r ca.crt ${icinga_node_name}.{crt,key} root@${icinga_node_name}:/neteye/local/icinga2/data/lib/icinga2/certs/
```
- On satellite set permissions
```
# cd /neteye/local/icinga2/data/lib/icinga2/certs
# chown icinga:icinga *
# chmod 600 *.key
# chmod 644 *.crt
```

## On Satellite ##
### Configuration of icinga2: constants.conf

**Constants.conf for icinga2**
Path: /neteye/local/icinga2/conf/icinga2/constants.conf
```
/**
 * This file defines global constants which can be used in
 * the other configuration files.
 */

/* The directory which contains the plugins from the Monitoring Plugins project. */
const PluginDir = "/usr/lib64/neteye/monitoring/plugins"

/* The directory which contains the Manubulon plugins.
 * Check the documentation, chapter "SNMP Manubulon Plugin Check Commands", for details.
 */
const ManubulonPluginDir = "/usr/lib64/neteye/monitoring/plugins"

/* The directory which you use to store additional plugins which ITL provides user contributed command definitions for.
 * Check the documentation, chapter "Plugins Contribution", for details.
 */
const PluginContribDir = "/neteye/shared/monitoring/plugins/"

/* Our local instance name. By default this is the server's hostname as returned by `hostname --fqdn`.
 * This should be the common name from the API certificate.
 */
const NodeName = "neteye4vm1.mydomain.local"

/* Our local zone name. */
const ZoneName = "satellite"

/* Secret key for remote node tickets */
const TicketSalt = ""
```


**Configuration of icinga2: Zones.conf**
Path: /neteye/local/icinga2/conf/icinga2/zones.conf
```
object Endpoint "neteye4.mydomain.local" {
}

object Zone "master" {
        endpoints = [ "neteye4.mydomain.local" ]
}

# Other global zones not shown here ...

# Recursive include of folder zones.d/
include_recursive "zones.d"
```
## On Master ##
Provide satellite zone configuration in zones.d/ include directory:
Path: /neteye/shared/icinga2/conf/icinga2/zones.d/satellite.conf

```
object Endpoint "neteye4vm1.mydomain.local" {
        host = "neteye4vm1.mydomain.local"
        port = 5665
}
object Zone "satellite" {
        endpoints = [ "neteye4vm1.mydomain.local" ]
        parent = "master"
    }
```

__Verify Firewall and Features__
- Apply firewall rules to enable incoming connection on API port
```
# firewall-cmd --list-all
# firewall-cmd --permanent --zone=public --add-port=5665/tcp
# firewall-cmd --reload
```
- Enable features: `api checker mainlog`
```
icinga2 feature enable api
icinga2 feature disable notification
```
- Verify API configuration, especially enable to accept configuration.
  Path: `/neteye/local/icinga2/conf/icinga2/features-enabled/api.conf`
```
object ApiListener "api" {
  bind_host = "0.0.0.0"
  bind_port = 5665

  accept_config = true
  accept_commands = true
  
  ticket_salt = TicketSalt
}
```
- Test telnet on api port


__Now validate configuration and start icinga2 service__

Enable service for automatic start in systemctl
```
# icinga2 daemon --validate //on satellite
# icinga2-master daemon --validate //on master
# systemctl start icinga2.service
# systemctl status icinga2.service
# systemctl enable icinga2.service
```

[<<< Back to documentation overview <<<](./README.md)
