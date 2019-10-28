
# check_pcmeasure2 for NetEye 4

## Importing Service Templates

Execute: service_template-pcmeasure2.sh 


## Setup and configuration 

copy check_pcmeasure2.pl in NetEye 4 plugin directory : /neteye/shared/monitoring/plugins

In Director you need to create 4 Custom Fields:

check_pcmeasure_sensor
check_pcmeasure_label
check_pcmeasure_warning
check_pcmeasure_critical

## Example commandline
[root@neteye4 plugins]# /neteye/shared/monitoring/plugins/check_pcmeasure2.pl -H 10.62.5.35 -S com1.1 -w 45 -c 55 -l 'Celsius'
PCMEASURE OK - Celsius = 20.8 | celsius=20.8;45;55


