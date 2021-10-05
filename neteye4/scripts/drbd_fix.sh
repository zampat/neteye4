#!/bin/bash

# Helper script to force a re-sync of DRBD devices. This script is great to re-align your drbd ressources in your test envirionment.
# ADVICE: Do never use this script in prodcution ! Think about using parts of the commands to restore your drbd synch-status in production.
#
services=(grafana tornado_webhook_collector tornado_icinga2_collector tornado_email_collector slmd mariadb influxdb tornado snmptrapd nginx nagvis icingaweb2 icinga2-master httpd nats-server)
host_local="neteye4clu01.patrick.lab"

for service in "${services[@]}"
do
   echo "[] Starting for service $s"
   drbdadm primary $service --force
   drbdadm adjust $service

   for i in neteye4clu02.patrick.lab neteye4clu03.patrick.lab
   do
      ssh $i drbdadm disconnect $service
      ssh $i drbdadm -- --discard-my-data connect $service $host_local
      ssh $i drbdadm adjust $service
   done

   sleep 1
   drbdadm adjust $service
   drbdadm secondary $service

   sleep 2

   extra_primry_host="neteye4clu03.patrick.lab"
   extra_secondary_host="neteye4clu02.patrick.lab"
   
   ssh $extra_primry_host drbdadm primary $service --force
   ssh $extra_secondary_host drbdadm disconnect $service
   ssh $extra_secondary_host drbdadm -- --discard-my-data connect $service $extra_primry_host


   ssh $extra_primry_host drbdadm secondary $service

   ssh $extra_primry_host drbdadm adjust $service
   ssh $extra_secondary_host drbdadm adjust $service
   echo "[+] Done"
done
