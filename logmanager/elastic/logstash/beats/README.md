# Setup of Filebeat

## Procedure documentation
1.	Get a copy of filebeat
2.	Install and configure filebeat
3.	Configure filebeat

## 1. Get a copy of elastic filebeat

Online resource for downloading latest version:
https://www.elastic.co/de/downloads/beats/filebeat

## 2. Install filebeat
•	Unzip contents into local program files folder i.e. `c:\program files\filebeat\`
•	Register service. (Administrative powershell required)
Execute `.\install-service-filebeat.ps1`

## 3. Configure filebeat

Take filebeat configuration sample from sharepoint folder software and configurations/ (see link above).
Edit sections:
•	Section “filebeat.inputs”: paths of files to include
•	Section “output.logstash”: destination of neteye4 siem server address

Then (re)start service “filebeat”

