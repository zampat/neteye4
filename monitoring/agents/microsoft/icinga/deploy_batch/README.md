# Icinga2 Agents assisted configuration

This section provides a script for windows to automate the configuration of a Windows Icinga2 Agent. The approach is to contact Icinga2 via API, retrieve the Ticket for a host and configure the Icinga2 agent automatically. Prerequisite is to define the host in Director in advance.

- Have a look at the configurations to change in script
- Run the script in administrative cmd 


```
C:\Users\user\Downloads\icinga2_agent_deploy>01_ConfigureAgent.bat
"Icinga2 Agent msi had already been downloaded. Proceeding with install..."
"Icinga2 Agent already installed"
"Start to register host <hostname> with Ticket: "f3610648cf18978cfc8f93768fbe69c2d2012f2a""
"Icinga2 Agent is installed. Going to configure agent now ...."
[...]
 Subject:     CN = neteye4.mydomain
 Issuer:      CN = Icinga CA
 Valid From:  Sep 17 13:35:49 2019 GMT
 Valid Until: Sep 13 13:35:49 2034 GMT
 Fingerprint: 48 66 AE 7A F6 94 E6 07 4F E8 B3 B4 54 E9 70 8D 35 B2 45 FA
[...]
nformation/cli: Make sure to restart Icinga 2.
information/cli: Updating '"conf.d"' include in 'C:\ProgramData\icinga2\etc\icinga2/icinga2.conf'.
information/cli: Backup file 'C:\ProgramData\icinga2\etc\icinga2/icinga2.conf.orig' already exists. Skipping backup.
information/cli: Make sure to restart Icinga 2.
"End of Icinga2 configuration script."
```


## Technical Backgrounds

### Register host in Director and fetch Ticket
[Fetch Host Ticket via Director API]( https://icinga.com/docs/director/latest/doc/70-REST-API/)

```
curl -k -H 'Accept: application/json' -u director:secret 'https://localhost/neteye/director/host/ticket?name=DESKTOP-PCEKP72'
 "e1a598c95114e7dae704efe35a93c83fba9b6c22" 
```

### Install Icinga2 Agent and configure it

- Install the Icinga2 Agent via setup msi
- Place Icinga2 parent certificate in C:\ProgramData\icinga2\var\lib\icinga2/certs/
- Configure Agent via node setup

```
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
```
