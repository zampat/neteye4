# NetEye Cluster: Icinga2 satellite services configuration

In the cluster, next to the icinga2-master service managed by the cluster software, an additional Icinga2 satellite can be configured as "worker" on the local node.
The configuration of the master zone is therefore extended by another zone, containing the Icinga2 satellites. You can enable one on each cluster node. Services may co-exists with icinga2-master service, using a different port.

Overview:
icinga2-master: managed by cluster service, relocates witin cluster, uses port 5665 for communication
icinga2: managed by local systemctl, provies monitoring on local node, uses port 5664 for communication

## Zoning architecture

zone: master
endpoints: icinga2-master

zone: cluster-satellite
endpoints: neteye4vm1.mydomain.local, neteye4vm2.mydomain.local, ... 
parent zone: master


# Generate certificates for each icinga2 satellite
Note: Generate and sign certificates where icinga2-master service is running!
[Concepts about creating the certificates on the master](https://icinga.com/docs/icinga2/snapshot/doc/06-distributed-monitoring/#create-ca-on-the-master)
Note2: In NetEye the service name for icinga2 master is: "icinga2-master"

## Certificate creation for satellite node

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
const ZoneName = "cluster-satellite"

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
Provide satellite zone configuration in zones.d/ include directory:
Path: /neteye/shared/icinga2/conf/icinga2/zones.d/cluster.conf

```
object Endpoint "neteye4vm1.mydomain.local" {
        host = "neteye4vm1.mydomain.local"
        port = 5664
}

object Endpoint "neteye4vm2.mydomain.local" {
        host = "neteye4vm2.mydomain.local"
        port = 5664
}

object Zone "cluster-satellite" {
        endpoints = [ "neteye4vm1.mydomain.local", "neteye4vm2.mydomain.local" ]
        parent = "master"
    }
```

Now validate configuration and start icinga2 service
Enable service for autostart in systemctl
```
# icinga2 daemon --validate
# systemctl start icinga2.service
# systemctl status icinga2.service
# systemctl enable icinga2.service
```

[<<< Back to documentation overview <<<](./README.md)
