#!/usr/bin/perl


#/******************************************************************************
# *
# * CHECK_F5_POOL_MEMBERS
# *
# * Program: Linux plugin for Nagios
# * License: GPL
# * Copyright (c) 2009- Victor Ruiz (vruiz@adif.es)
# *
# * Description:
# *
# * This software checks some OID's from F5-BIGIP-LOCAL-MIB
# * ltmPools branch with pool members related objects
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
# * $Id: check-f5-poolmbrs.pl,v 0.9 2009/05/07 17:15:40 savirziur Exp $
# *
# *****************************************************************************/


use strict;
use Net::SNMP qw(:snmp);
use Getopt::Long;
use utils qw(%ERRORS $TIMEOUT);

my %nagios_exit_codes = ('UNKNOWN' ,-1,
			 'OK'      , 0,
			 'WARNING' , 1,
			 'CRITICAL', 2,);


my @AvailStateCodes = ('none - error',
			'green - available in some capacity',
			'yellow - not currently available',
			'red - not available',
			'blue - availability is unknown',
			'gray - unlicensed');

my @MonitorStatusCodes = ( 'unchecked  - enabled node that is not monitored',
			'checking   - initial state until monitor reports',
			'up         - enabled node when its monitors succeed',
			'addrdown   - node address monitor fails or forced down',
			'servdown   - node server monitor fails or forced down',
			'down       - enabled node when its monitors fail',
			'forceddown - node forced down manually',
			'maint      - in maintenance mode',
			'disabled   - the monitor instance is disabled');

my %members;

my %ltmPoolMemberTable;
my $ltmPoolMember = '.1.3.6.1.4.1.3375.2.2.5.3';
my $ltmPoolMemberNumber = '.1.3.6.1.4.1.3375.2.2.5.3.1.0';
my $ltmPoolMemberPoolName = '.1.3.6.1.4.1.3375.2.2.5.3.2.1.1';
my $ltmPoolMemberAddr = '.1.3.6.1.4.1.3375.2.2.5.3.2.1.3';
my $ltmPoolMemberPort = '.1.3.6.1.4.1.3375.2.2.5.3.2.1.4';
my $ltmPoolMemberMonitorStatus = '.1.3.6.1.4.1.3375.2.2.5.3.2.1.11';

my %ltmPoolMbrStatusTable;
my $ltmPoolMemberStatus = '.1.3.6.1.4.1.3375.2.2.5.6';
my $ltmPoolMbrStatusAvailState = '.1.3.6.1.4.1.3375.2.2.5.6.2.1.5';
my $ltmPoolMbrStatusEnabledState = '.1.3.6.1.4.1.3375.2.2.5.6.2.1.6';
my $ltmPoolMbrStatusDetailReason = '.1.3.6.1.4.1.3375.2.2.5.6.2.1.8';

# Globals

my $Version='1.0.0';

my $o_host =    undef;          # hostname
my $o_community = undef;        # community
my $o_port =    161;            # port
my $o_help=     undef;          # wan't some help ?
my $o_verb=     undef;          # verbose mode
my $o_version=  undef;          # print version
my $o_warn=     undef;          # warning level
my $o_crit=     undef;          # critical level
my $o_timeout=  undef;          # Timeout (Default 5)
my $o_version2= 1;              # use snmp v2c
# SNMPv3 specific
my $o_login=    undef;          # Login for snmpv3
my $o_passwd=   undef;          # Pass for snmpv3
my $v3protocols=undef;          # V3 protocol list.
my $o_authproto='md5';          # Auth protocol
my $o_privproto='des';          # Priv protocol
my $o_privpass= undef;          # priv password
my $o_filter= undef;            # Pool Filter

# functions

sub p_version { print "check_snmp_load version : $Version\n"; }

sub print_usage {
    print "Usage: $0 [-v] -H <host> -C <snmp_community> [-2] | (-l login -x passwd [-X pass -L <authp>,<privp>])  [-p <port>] -w <warn level> -c <crit level> [-f <filter>] [-t <timeout>] [-V]\n";
}

sub isnnum { # Return true if arg is not a number
  my $num = shift;
  if ( $num =~ /^(\d+\.?\d*)|(^\.\d+)$/ ) { return 0 ;}
  return 1;
}

sub help {
   print "\nSNMP Pool Member check for F5 Loadbalancer ",$Version,"\n";
   print "GPL licence, (c)2018 Juergen Vigna <juergen.vigna\@wuerth-phoneix.com>\n\n";
   print_usage();
   print <<EOT;
-v, --verbose
   print extra debugging information
-h, --help
   print this help message
-H, --hostname=HOST
   name or IP address of host to check
-C, --community=COMMUNITY NAME
   community name for the host's SNMP agent (implies v1 protocol)
-l, --login=LOGIN ; -x, --passwd=PASSWD
   Login and auth password for snmpv3 authentication
   If no priv password exists, implies AuthNoPriv
-X, --privpass=PASSWD
   Priv password for snmpv3 (AuthPriv protocol)
-L, --protocols=<authproto>,<privproto>
   <authproto> : Authentication protocol (md5|sha : default md5)
   <privproto> : Priv protocole (des|aes : default des)
-P, --port=PORT
   SNMP port (Default 161)
-w, --warn=INTEGER : warning level for members in problem status
-c, --crit=INTEGER : critical level for members in problem status
-f, --filter
   Pool Filter if set
-t, --timeout=INTEGER
   timeout for SNMP in seconds (Default: 5)
-V, --version
   prints version number
EOT
}

# For verbose output
sub verb { my $t=shift; print $t,"\n" if defined($o_verb) ; }

Getopt::Long::Configure ("bundling");
GetOptions(
    'v'     => \$o_verb,            'verbose'       => \$o_verb,
    'h'     => \$o_help,            'help'          => \$o_help,
    'H:s'   => \$o_host,            'hostname:s'    => \$o_host,
    'p:i'   => \$o_port,            'port:i'        => \$o_port,
    'C:s'   => \$o_community,       'community:s'   => \$o_community,
    'l:s'   => \$o_login,           'login:s'       => \$o_login,
    'x:s'   => \$o_passwd,          'passwd:s'      => \$o_passwd,
    'X:s'   => \$o_privpass,        'privpass:s'    => \$o_privpass,
    'L:s'   => \$v3protocols,       'protocols:s'   => \$v3protocols,
    't:i'   => \$o_timeout,         'timeout:i'     => \$o_timeout,
    'V'     => \$o_version,         'version'       => \$o_version,
    'c:s'   => \$o_crit,            'critical:s'    => \$o_crit,
    'w:s'   => \$o_warn,            'warn:s'        => \$o_warn,
    'f:s'   => \$o_filter,          'filter:s'      => \$o_filter,
);

# Basic checks
if (defined($o_timeout) && (isnnum($o_timeout) || ($o_timeout < 2) || ($o_timeout > 60)))
    { print "Timeout must be >1 and <60 !\n"; print_usage(); exit $ERRORS{"UNKNOWN"}}
if (!defined($o_timeout)) {$o_timeout=5;}
if (defined ($o_help) ) { help(); exit $ERRORS{"UNKNOWN"}};
if (defined($o_version)) { p_version(); exit $ERRORS{"UNKNOWN"}};
if ( ! defined($o_host) ) # check host and filter
    { print_usage(); exit $ERRORS{"UNKNOWN"}}
# check snmp information
if ( !defined($o_community) && (!defined($o_login) || !defined($o_passwd)) )
     { print "Put snmp login info!\n"; print_usage(); exit $ERRORS{"UNKNOWN"}}
if ((defined($o_login) || defined($o_passwd)) && (defined($o_community) || defined($o_version2)) )
     { print "Can't mix snmp v1,2c,3 protocols!\n"; print_usage(); exit $ERRORS{"UNKNOWN"}}
if (defined ($v3protocols)) {
if (!defined($o_login)) { print "Put snmp V3 login info with protocols!\n"; print_usage(); exit $ERRORS{"UNKNOWN"}}
my @v3proto=split(/,/,$v3protocols);
if ((defined ($v3proto[0])) && ($v3proto[0] ne "")) {$o_authproto=$v3proto[0];        }       # Auth protocol
if (defined ($v3proto[1])) {$o_privproto=$v3proto[1]; }       # Priv  protocol
if ((defined ($v3proto[1])) && (!defined($o_privpass))) {
       print "Put snmp V3 priv login info with priv protocols!\n"; print_usage(); exit $ERRORS{"UNKNOWN"}}
}
# Check warnings and critical
if (!defined($o_warn))
    { $o_warn=1; }
if (!defined($o_crit))
    { $o_crit=0; }

alarm ($o_timeout);

# Connect to host
my ($session,$error);
if ( defined($o_login) && defined($o_passwd)) {
  # SNMPv3 login
  verb("SNMPv3 login");
    if (!defined ($o_privpass)) {
  verb("SNMPv3 AuthNoPriv login : $o_login, $o_authproto");
    ($session, $error) = Net::SNMP->session(
      -nonblocking => 1,
      -maxmsgsize  => 10000,
      -hostname         => $o_host,
      -version          => '3',
      -username         => $o_login,
      -authpassword     => $o_passwd,
      -authprotocol     => $o_authproto,
      -timeout          => $o_timeout
    );
  } else {
    verb("SNMPv3 AuthPriv login : $o_login, $o_authproto, $o_privproto");
    ($session, $error) = Net::SNMP->session(
      -nonblocking => 1,
      -maxmsgsize  => 10000,
      -hostname         => $o_host,
      -version          => '3',
      -username         => $o_login,
      -authpassword     => $o_passwd,
      -authprotocol     => $o_authproto,
      -privpassword     => $o_privpass,
      -privprotocol     => $o_privproto,
      -timeout          => $o_timeout
    );
  }
} else {
        if (defined ($o_version2)) {
                # SNMPv2 Login
                verb("SNMP v2c login");
                  ($session, $error) = Net::SNMP->session(
                 -nonblocking => 1,
                 -maxmsgsize  => 10000,
                 -hostname  => $o_host,
                 -version   => 2,
                 -community => $o_community,
                 -port      => $o_port,
                 -timeout   => $o_timeout
                );
        } else {
          # SNMPV1 login
          verb("SNMP v1 login");
          ($session, $error) = Net::SNMP->session(
                -nonblocking => 1,
                -maxmsgsize  => 10000,
                -hostname  => $o_host,
                -community => $o_community,
                -port      => $o_port,
                -timeout   => $o_timeout
          );
        }
}
if (!defined($session)) {
   printf("ERROR opening session: %s.\n", $error);
   exit $nagios_exit_codes{'UNKNOWN'};
}

my $result = $session->get_bulk_request(
   -callback       => [\&table_cb, \%ltmPoolMemberTable, $ltmPoolMember],
   -maxrepetitions => 10,
   -varbindlist    => [$ltmPoolMember]
);

if (!defined($result)) {
   printf("ERROR: %s.\n", $session->error);
   $session->close;
   exit $nagios_exit_codes{'UNKNOWN'};
}



my $result = $session->get_bulk_request(
   -callback       => [\&table_cb, \%ltmPoolMbrStatusTable, $ltmPoolMemberStatus],
   -maxrepetitions => 10,
   -varbindlist    => [$ltmPoolMemberStatus]
);

if (!defined($result)) {
   printf("ERROR: %s.\n", $session->error);
   $session->close;
   exit $nagios_exit_codes{'UNKNOWN'};
}

snmp_dispatcher();

$session->close;

alarm 0;

my $pool_members_cnt = 0;
my $hiddenString = "";
my $ipAddress = "";

foreach my $oid (oid_lex_sort(keys(%ltmPoolMemberTable))) {
   if ( oid_base_match($ltmPoolMemberPoolName, $oid) ) {
      if (!defined($o_filter) || ($ltmPoolMemberTable{$oid} =~ /$o_filter/)) {
          $pool_members_cnt++;
          $hiddenString= substr($oid, length($ltmPoolMemberPoolName));
          ($ipAddress = $ltmPoolMemberTable{$ltmPoolMemberAddr.$hiddenString}) =~ /(..)(..)(..)(..)(..)/;
          $ipAddress = hex($2).".".hex($3).".".hex($4).".".hex($5);
          $members{$hiddenString} = $ltmPoolMemberTable{$oid}."-".$ipAddress.":".$ltmPoolMemberTable{$ltmPoolMemberPort.$hiddenString};
      }
   } else {
     if ( $pool_members_cnt >= $ltmPoolMemberTable{$ltmPoolMemberNumber} ) { last;}
   }
}

my $enabled_members_cnt = 0;
my $disabled_members_cnt = 0;
my $enabled_members = "";
my $disabled_members = "";

my $available_members_cnt = 0;
my $unavailable_members_cnt = 0;
my $available_members = "";
my $unavailable_members = "";

my $status = "OK";

foreach my $oid (oid_lex_sort(keys(%members))) {
   if ( $ltmPoolMbrStatusTable{$ltmPoolMbrStatusEnabledState . $oid} == 1) {
      $enabled_members_cnt++;
      $enabled_members = $enabled_members . " " . $members{$oid};

      if ( $ltmPoolMbrStatusTable{$ltmPoolMbrStatusAvailState . $oid} == 1 ) {
         $available_members_cnt++;
         $available_members = $available_members . " " . $members{$oid};
      } else {
         $unavailable_members_cnt++;
         $unavailable_members = $unavailable_members . "'" . $members{$oid} . "' (" . substr($ltmPoolMbrStatusTable{$ltmPoolMbrStatusDetailReason . $oid},25) . ") ";
         $status = "CRITICAL";
      }

   } else {
      $disabled_members_cnt++;
      $disabled_members = $disabled_members . " " . $members{$oid};
   }
}

my $perfdata="total_members=$pool_members_cnt;;;0; enabled_members=$enabled_members_cnt;$o_warn;$o_crit;0; disabled_members=$disabled_members_cnt;;;0; available_members=$available_members_cnt;$o_warn;$o_crit;0; unavailable_members=$unavailable_members_cnt;;;0;";

if (defined($o_filter)) {
	if ($unavailable_members_cnt > 0) {
		$status="WARNING";
	} else {
		$status="OK";
	}
	if ($enabled_members_cnt <= $o_warn || $available_members_cnt <= $o_warn) {
		$status="WARNING";
	}
	if ($enabled_members_cnt <= $o_crit || $available_members_cnt <= $o_crit) {
		$status="CRITICAL";
	}
	print "$status - $o_filter ";
	print "ENABLED(" . $enabled_members_cnt . "), ";
	print "DISABLED(" . $disabled_members_cnt . "), ";
	print "AVAILABLE(" . $available_members_cnt . "), ";
	print "UNAVAILABLE(" . $unavailable_members_cnt . ")|$perfdata\n";
	if ($disabled_members_cnt > 0) {
	   print "DISABLED: " . $disabled_members . "\n";
	}
	if ($unavailable_members_cnt > 0) {
	   print "UNAVAILABLE: " . $unavailable_members . "\n";
	}
} else {
	print "MEMBERS[".$ltmPoolMemberTable{$ltmPoolMemberNumber}."] = ";
	print "ENABLED(" . $enabled_members_cnt . ") - ";
	if ($disabled_members_cnt > 0) {
	   print "DISABLED(" . $disabled_members_cnt . "): " . $disabled_members . " - ";
	} else {
	   print "DISABLED(" . $disabled_members_cnt . ") - ";
	}
	print "AVAILABLE(" . $available_members_cnt . ") - ";
	if ($unavailable_members_cnt > 0) {
	   print "UNAVAILABLE(" . $unavailable_members_cnt . "): " . $unavailable_members . "\n";
	} else {
	   print "UNAVAILABLE(" . $unavailable_members_cnt . ")|$perfdata\n";
	}
}
exit $nagios_exit_codes{$status};

sub table_cb
{
   my ($session, $table , $OID_base) = @_;

      if (!defined($session->var_bind_list)) {

      printf("ERROR: %s\n", $session->error);   

   } else {

      # Loop through each of the OIDs in the response and assign
      # the key/value pairs to the anonymous hash that is passed
      # to the callback.  Make sure that we are still in the table
      # before assigning the key/values.

      my $next;

      foreach my $oid (oid_lex_sort(keys(%{$session->var_bind_list}))) {
         if (!oid_base_match($OID_base, $oid)) {
            $next = undef;
            last;
         }
         $next = $oid; 
         $table->{$oid} = $session->var_bind_list->{$oid};   
      }

      # If $next is defined we need to send another request 
      # to get more of the table.

      if (defined($next)) {

         $result = $session->get_bulk_request(
            -callback       => [\&table_cb, $table, $OID_base],
            -maxrepetitions => 10,
            -varbindlist    => [$next]
         ); 

         if (!defined($result)) {
            printf("ERROR: %s\n", $session->error);
         }
      }
   }
}


# Si hay problemas, preparamos una seÃ±al de timeout
$SIG{'ALRM'} = sub {
   print "ERROR: No snmp response from $o_host (TIMEOUT $o_timeout SECONDS)\n";
};
