#! /usr/bin/perl -w

#/******************************************************************************
# *
# * CHECK_F5_PLATFORM
# *
# * Program: Linux plugin for Nagios
# * License: GPL
# * Copyright (c) 2009- Victor Ruiz (vruiz@adif.es)
# *
# * Description:
# *
# * This software checks some OID's from F5-BIGIP-SYSTEM-MIB
# * sysPlatform branch with CPU TEMPERATURE, FAN's & VOLTAGE related objects
# *
# * License Information:
# *
# * This program is free software; you can redistribute it and/or modify
# * it under the terms of the GNU General Public License as published by
# * the Free Software Foundation; either version 2 of the License, or
# * (at your option) any later version.
# *
# * This program is distributed in the hope that it will be useful,
# * but WITHOUT ANY WARRANTY; without even the implied warranty of
# * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# * GNU General Public License for more details.
# *
# * You should have received a copy of the GNU General Public License
# * along with this program; if not, write to the Free Software
# * Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
# *
# * $Id: check-f5-platform.pl,v 0.9 2009/05/07 17:15:40 savirziur Exp $
# *
# *****************************************************************************/



   use strict;
   use Getopt::Std;
   use Net::SNMP qw(:snmp);

#  Codigos predefinidos para Nagios
   my %nagios_exit_codes = ('UNKNOWN' ,-1,
                            'OK'      , 0,
                            'WARNING' , 1,
                            'CRITICAL', 2,);

   my $status = "OK";

   our($opt_h, $opt_c, $opt_t, $opt_w, $opt_k);
   my %sysPlatformTable;
   my $output_string = "";

   my $sysPlatform = '.1.3.6.1.4.1.3375.2.1.3';
   my $sysCpuNumber = '.1.3.6.1.4.1.3375.2.1.3.1.1.0';
   my $sysCpuIndex = '.1.3.6.1.4.1.3375.2.1.3.1.2.1.1';
   my $sysCpuTemperature = '.1.3.6.1.4.1.3375.2.1.3.1.2.1.2';

   my $sysChassisFanNumber = '.1.3.6.1.4.1.3375.2.1.3.2.1.1.0';
   my $sysChassisFanIndex = '.1.3.6.1.4.1.3375.2.1.3.2.1.2.1.1';
   my $sysChassisFanStatus = '.1.3.6.1.4.1.3375.2.1.3.2.1.2.1.2';

   my $sysChassisPowerSupplyNumber = '.1.3.6.1.4.1.3375.2.1.3.2.2.1.0';
   my $sysChassisPowerSupplyIndex = '.1.3.6.1.4.1.3375.2.1.3.2.2.2.1.1';
   my $sysChassisPowerSupplyStatus = '.1.3.6.1.4.1.3375.2.1.3.2.2.2.1.2';

   my $sysChassisTempNumber = '.1.3.6.1.4.1.3375.2.1.3.2.3.1.0';
   my $sysChassisTempIndex = '.1.3.6.1.4.1.3375.2.1.3.2.3.2.1.1';
   my $sysChassisTempTemperature = '.1.3.6.1.4.1.3375.2.1.3.2.3.2.1.2';



if ( !getopts('h:c:t:w:k:') ) {

  &usage;
  exit $nagios_exit_codes{'UNKNOWN'};

} else {

   if ($opt_w > $opt_k) {
	print "WARNING threshold must be lower than CRITICAL threshold\n";
	&usage;
	exit $nagios_exit_codes{'UNKNOWN'}; 	
   }

   alarm ($opt_t);

   my ($session, $error) = Net::SNMP->session(
      -version     => 'snmpv2c',
      -nonblocking => 1,
      -hostname    => $opt_h,
      -community   => $opt_c,
      -port        => 161
   );

   if (!defined($session)) {
      printf("ERROR: %s.\n", $error);
      exit $nagios_exit_codes{'UNKNOWN'};
   }

   my $result = $session->get_bulk_request(
      -callback       => [\&table_cb, \%sysPlatformTable, \$status],
      -maxrepetitions => 10,
      -varbindlist    => [$sysPlatform]
   );

   if (!defined($result)) {
      printf("ERROR: %s.\n", $session->error);
      $session->close;
      exit $nagios_exit_codes{'UNKNOWN'};
   }

   snmp_dispatcher();

   $session->close;

   alarm(0);

#   foreach my $oid (oid_lex_sort(keys(%sysPlatformTable))) {
#      printf("%s => %s\n", $oid, $sysPlatformTable{$oid});
#   }
#   print "OK\n";
#   exit $nagios_exit_codes{'OK'};

####   my $cpus = $sysPlatformTable{$sysCpuNumber};   
   my $fans = $sysPlatformTable{$sysChassisFanNumber};
   my $powers = $sysPlatformTable{$sysChassisPowerSupplyNumber};
   my $chassisTemps = $sysPlatformTable{$sysChassisTempNumber};
   my $index = "";
   my $temperature;


####   if ( defined($cpus) and ($cpus > 0) ) {
####	my $i = 0;
####	foreach my $oid (oid_lex_sort(keys(%sysPlatformTable))) {
####	   if ( ! oid_base_match($sysCpuIndex, $oid) ) {
####		( $i < $cpus ) ? next : last;
####	   }
####	   if ( $i eq $cpus ) { last }; 
####	   $index = $sysPlatformTable{$oid};
####	   $temperature = $sysPlatformTable{$sysCpuTemperature . "." . $index};
####	   $i++;
####	   if ( $temperature > $opt_w ) {
####		$status = ( $temperature > $opt_k ) ? "CRITICAL" : ((($status ne "OK")and ($status ne "WARNING")) ? $status : "WARNING");
####		$output_string = $output_string . " CPU-" . $index . " above " . (($temperature > $opt_k) ? "critical" : "warning") . " threshold: " . $temperature . "∫C,";
####	   } else {
####		$status = ( $status ne "OK" ) ? $status : "OK";
####		$output_string = $output_string . " CPU-" . $index . " " . $temperature . "∫C,";
####	   }
####	   
####	}
   ####} else {
####	$status = ($status ne "CRITICAL") ? "UNKNOWN" : "CRITICAL";
####	$output_string = $output_string . "No CPU's reported by snmp";
   ####}

   if ( defined($fans) and ($fans > 0) ) {
	my $i = 0;
	foreach my $oid (oid_lex_sort(keys(%sysPlatformTable))) {
	   if ( ! oid_base_match($sysChassisFanIndex, $oid) ) {
		( $i < $fans ) ? next : last;
	   }
	   if ( $i eq $fans ) { last }; 
	   $index = $sysPlatformTable{$oid};
	   $i++;
	   if ( $sysPlatformTable{$sysChassisFanStatus . "." . $index} eq 0 ) {
		$status = "CRITICAL";
		$output_string = $output_string . " FAN-" . $index . " Bad,";
	   } else {
		$status = ( $status ne "OK" ) ? $status : "OK";
		$output_string = $output_string . " FAN-" . $index . " ok,";
	   }
	}
   } else {
	$status = ($status ne "CRITICAL") ? "UNKNOWN" : "CRITICAL";
	$output_string = $output_string . "No fans reported by snmp.";
   }

   if ( defined($powers) and ($powers > 0) ) {
	my $i = 0;
	foreach my $oid (oid_lex_sort(keys(%sysPlatformTable))) {
	   if ( ! oid_base_match($sysChassisPowerSupplyIndex, $oid) ) {
		( $i < $powers ) ? next : last;
	   }
	   if ( $i eq $powers ) { last }; 
	   $index = $sysPlatformTable{$oid};
	   $i++;
	   if ( $sysPlatformTable{$sysChassisPowerSupplyStatus . "." . $index} eq 0 ) {
		$status = "CRITICAL";
		$output_string = $output_string . " POWER-SUPPLY-" . $index . " Bad,";
	   } else {
		$status = ( $status ne "OK" ) ? $status : "OK";
		$output_string = $output_string . " POWER-SUPPLY-" . $index . " ok,";
	   }
	}
   } else {
	$status = ($status ne "CRITICAL") ? "UNKNOWN" : "CRITICAL";
	$output_string = $output_string . "No chassis power supplies reported by snmp.";
   }

   if ( defined($chassisTemps) and ($chassisTemps > 0) ) {
	my $i = 0;
	foreach my $oid (oid_lex_sort(keys(%sysPlatformTable))) {
	   if ( ! oid_base_match($sysChassisTempIndex, $oid) ) {
		( $i < $chassisTemps ) ? next : last;
	   }
	   if ( $i eq $chassisTemps ) { last }; 
	   $index = $sysPlatformTable{$oid};
	   $temperature = $sysPlatformTable{$sysChassisTempTemperature . "." . $index};
	   $i++;
	   if ( $temperature > $opt_w ) {
		$status = ( $temperature > $opt_k ) ? "CRITICAL" : ((($status ne "OK") and ($status ne "WARNING")) ? $status : "WARNING");
		$output_string = $output_string . " Chassis-Temperature-" . $index . " above " . (($temperature > $opt_k) ? "critical" : "warning") . " threshold: " . $temperature . "∫C,";
	   } else {
		$status = ( $status ne "OK" ) ? $status : "OK";
		$output_string = $output_string . " Chassis-Temperature-" . $index . " " . $temperature . "∫C,";
	   }
	   
	}
   } else {
	$status = ($status ne "CRITICAL") ? "UNKNOWN" : "CRITICAL";
	$output_string = $output_string . "No Chassis temperature reported by snmp.";
   }



   print $output_string, "\n";
   exit $nagios_exit_codes{$status};
}


   sub table_cb
   {
      my ($session, $table, $status) = @_;

      if (!defined($session->var_bind_list)) {
         printf("ERROR: %s.\n", $session->error);
         $session->close;
         exit $nagios_exit_codes{'UNKNOWN'};

      } else {

         # Loop through each of the OIDs in the response and assign
         # the key/value pairs to the anonymous hash that is passed
         # to the callback.  Make sure that we are still in the table
         # before assigning the key/values.

         my $next;

         foreach my $oid (oid_lex_sort(keys(%{$session->var_bind_list}))) {
            if (!oid_base_match($sysPlatform, $oid)) {
               $next = undef;
               last;
            }
            $next = $oid;
            $table->{$oid} = $session->var_bind_list->{$oid};
         }

         # If $next is defined we need to send another request
         # to get more of the table.

         if (defined($next)) {

            my $result = $session->get_bulk_request(
               -callback       => [\&table_cb, $table, \$status],
               -maxrepetitions => 10,
               -varbindlist    => [$next]
            );

            if (!defined($result)) {
               printf("ERROR: %s\n", $session->error);
               $status = "CRITICAL";
            }

         }
      }
   }

# Si hay problemas, para que no se cuelgue Nagios preparamos una se√±al de timeout
   $SIG{'ALRM'} = sub {
      print ("ERROR: No snmp response from $opt_h (alarm timeout)\n");
      exit $nagios_exit_codes{'UNKNOWN'};
   };

sub usage()
{
  print "\nUsage:\n\n $0 -h <F5-hostname or IP address> -c <snmp-community> -t <timeout for snmp-response> -w <warning temperature threshold> -k <critical temperature threshold>\n\n";
}
