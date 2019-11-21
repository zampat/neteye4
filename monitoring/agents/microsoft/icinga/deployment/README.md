# Icinga2 Agents assisted configuration

## Register host in Director and fetch Ticket
[Fetch Host Ticket via Director API]( https://icinga.com/docs/director/latest/doc/70-REST-API/)

```
curl -k -H 'Accept: application/json' -u director:secret 'https://localhost/neteye/director/host/ticket?name=DESKTOP-PCEKP72'
 "e1a598c95114e7dae704efe35a93c83fba9b6c22" 
```

## Install Icinga2 Agent and configure it

- Install the Icinga2 Agent via setup msi
- Place Icinga2 parent certificate in C:\ProgramData\icinga2\var\lib\icinga2/certs/
- Configure Agent via node setup

.\icinga2.exe node setup --endpoint neteye.mydomain.lab --zone DESKTOP-PCEKP72 --parent_zone master --parent_host neteye.mydomain.lab --trustedcert C:\ProgramData\icinga2\var\lib\icinga2\certs\neteye.mydomain.lab.crt --ticket e1a598c95114e7dae704efe35a93c83fba9b6c22 --accept-commands --accept-config
information/cli: Requesting certificate with ticket 'e1a598c95114e7dae704efe35a93c83fba9b6c22'.
information/cli: Verifying parent host connection information: host 'neteye.mydomain.lab', port '5665'.
information/cli: Using the following CN (defaults to FQDN): 'DESKTOP-PCEKP72'.
information/base: Writing private key to 'C:\ProgramData\icinga2\var\lib\icinga2/certs//DESKTOP-PCEKP72.key'.
information/base: Writing X509 certificate to 'C:\ProgramData\icinga2\var\lib\icinga2/certs//DESKTOP-PCEKP72.crt'.
information/cli: Verifying trusted certificate file 'C:\ProgramData\icinga2\var\lib\icinga2\certs\neteye.mydomain.lab.crt'.
information/cli: Requesting a signed certificate from the parent Icinga node.
information/cli: Writing CA certificate to file 'C:\ProgramData\icinga2\var\lib\icinga2/certs//ca.crt'.
information/cli: Writing signed certificate to file 'C:\ProgramData\icinga2\var\lib\icinga2/certs//DESKTOP-PCEKP72.crt'.
information/cli: Disabling the Notification feature.
warning/cli: Feature 'notification' already disabled.
information/cli: Updating the ApiListener feature.
warning/cli: Feature 'api' already enabled.
information/cli: Backup file 'C:\ProgramData\icinga2\etc\icinga2/features-available/api.conf.orig' already exists. Skipping backup.
information/cli: Generating zone and object configuration.
information/cli: Dumping config items to file 'C:\ProgramData\icinga2\etc\icinga2/zones.conf'.
information/cli: Created backup file 'C:\ProgramData\icinga2\etc\icinga2/zones.conf.orig'.
information/cli: Updating 'NodeName' constant in 'C:\ProgramData\icinga2\etc\icinga2/constants.conf'.
information/cli: Created backup file 'C:\ProgramData\icinga2\etc\icinga2/constants.conf.orig'.
information/cli: Updating 'ZoneName' constant in 'C:\ProgramData\icinga2\etc\icinga2/constants.conf'.
information/cli: Backup file 'C:\ProgramData\icinga2\etc\icinga2/constants.conf.orig' already exists. Skipping backup.
information/cli: Make sure to restart Icinga 2.
information/cli: Make sure to restart Icinga 2.
