# Dependeny apply rule samples

## Parent - Child dependency rule

The Dependency Apply rule activates a dependency for all hosts, where (field) host_parent is set.
This rule works for a parent field of type:
- single host (String)
- multiple hosts (Array)
Simply define the type of field according the preference so assign single or multiple hosts.

Instructions:
1) Define a field: "host_parent" of type Director Host
2) Assign field to host template be able to define a "parent" for a host object.
3) place dependency_parentChild.conf in NetEye4 folder: /neteye/shared/icinga2/conf/icinga2/conf.d/
4) Reload icinga2 service

## Icinga Agent dependency rule

This rule defines a service dependency of Services named "*win*" to the service verifying the Icinga Agent availabiliy.
