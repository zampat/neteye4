The Dependency Apply rule activates a dependency for all hosts, where (field) host_parent is set.

1) Define a field: "host_parent" of type Director Host
2) Assign field to host template be able to define a "parent" for a host object.
3) place dependencies.conf in NetEye4 folder: /neteye/local/icinga2/conf/icinga2/conf.d/dependencies.conf
4) Reload icinga2 service
