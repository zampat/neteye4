Monitoring Cisco Nexus Series

## Cisco Nexus CPU

Manufacturer: Cisco
Branch: Nexus Series
Monitoring: CPU load 
Plugin: check_cisco_nexus_cpu.pl
Requirements: Perl module Switch.pm
How to resolve:
```
yum --enablerepo=neteye install perl-Switch.noarch
```

## Cisco Nexus Memory

Manufacturer: Cisco
Branch: Nexus Series
Monitoring: Memory usage
Plugin: `check_cisco_nexus_mem.pl`

## Cisco Nexus Hardware

Manufacturer: Cisco
Branch: Nexus Series
Monitoring: Hardware health
Plugin: `check_cisco_nexus_hardware.pl`
