#!/usr/bin/perl -w
# Created by Patrick Webster
# 20070109 Check BigIP F5 Load Balancer CPU Idle % for Nagios
# Version 0.1 patrick@aushack.com
#
# Install:  1) # mv check_bigIP_snmp.pl /usr/lib/nagios/plugins
#           2) # chmod 755 /usr/lib/nagios/plugins/check_bigIP_snmp.pl
#           3) # chown root.root /usr/lib/nagios/plugins/check_bigIP_snmp.pl
#           4) Update snmp.cfg, host.cfg, services.cfg, resources.cfg etc.
#
# Notes: Configured for SNMP v2c, which is 'CLEAR TEXT' - ensure you use source IP ACLs on the SNMP server,
#        and restrict to read-only. Or better, use SNMP v3 3DES SHA1 instead for encryption and authentication.
#
# To do: Check snmpwalk is present or die. Probably a lot of bugs, too!
#
# You may need to change the following lines to suit your installation:

$snmp='/usr/bin/snmpwalk'; # You need snmpwalk installed - try 'which snmpwalk' on the shell ;-) Absolute paths are better.
$numChecks=5;              # How many SNMP queries do we want to compile? The higher the more accurate, but more processing.
$wait=2;                   # How long to wait before attemping another check? Value in seconds.

# Probably won't need to do anything beyond here.

$pass=$ARGV[1];
$host=$ARGV[0];

if (!$ARGV[2]) { $warn="80";} else {$warn=$ARGV[2];}
if (!$ARGV[3]) { $crit="90";} else {$crit=$ARGV[3];}

$STATE_OK=0;
$STATE_WARNING=1;
$STATE_CRITICAL=2;
$STATE_UNKNOWN=3;

sub usage {
        print "\nUsage: " . $0 . " <host> <community string> [ <warning> <critical> ]\n";
        print "e.g.   " . $0 . " 127.0.0.1 public\n";
        print "or.    " . $0 . " 127.0.0.1 public 20 10\n";
        print "Created by Patrick Webster, patrick\@aushack.com\n";
        print "Gets the CPU idle average of the BigIP F5 Load Balancer and returns a Nagios state.\n\n";
        exit $STATE_UNKNOWN;
}

if (!$pass) { usage(); }

# If you want to change to SNMP v3, modify below.

for($i=0;$i<$numChecks;$i++) {
        $array[$i] =`$snmp -v 2c -c $pass $host ssCpuIdle.0`;
                if ($array[$i] =~ m/(\d+$)/) {
                #print $i . " : " . $1 . "\n";
                $average += $1;
                }
        sleep $wait;
        }
$count = @array;
$retval = (100-($average/$count));

#print "\nThe average CPU idle is: " . $retval . "\n\n";

if (!$average) {
        print "UNKNOWN - Unable to connect\n";
        exit $STATE_UNKNOWN;
}
if ($retval > $warn) {
        if ($retval > $crit) {
                print "CRITICAL - CPU Used = " . $retval . "|cpu_used=$retval;$warn;$crit;0;100\n";
                exit $STATE_CRITICAL;
                }
        print "WARNING - CPU Used = " . $retval . "|cpu_used=$retval;$warn;$crit;0;100\n";
        exit $STATE_WARNING;
}

print "OK - CPU Used = " . $retval . "|cpu_used=$retval;$warn;$crit;0;100\n";
exit $STATE_OK;

# EOF


