#! /usr/bin/perl -w
###################################################################
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
#    For information : david.barbion@adeoservices.com
####################################################################
#
# Script init
#

use strict;
use Switch;
use List::Util qw[min max];
use Net::SNMP qw(:snmp);
use FindBin;
use lib "$FindBin::Bin";
use lib "/usr/local/nagios/libexec";

#use utils qw($TIMEOUT %ERRORS &print_revision &support);
use Nagios::Plugin qw(%ERRORS);
use Data::Dumper;

use vars qw($PROGNAME);
use Getopt::Long;
use vars qw($opt_h $opt_V $opt_H $opt_C $opt_v $opt_o $opt_c $opt_w $opt_t $opt_p $opt_k $opt_u $opt_d $opt_i $opt_authproto $opt_priv $opt_privproto);
use constant true  => "1";
use constant false => "0";
$PROGNAME = $0;
my $version = 1;
my $release = 0;
sub print_help ();
sub print_usage ();
sub verbose;
sub get_nexus_table;
sub get_nexus_entries;
sub get_nexus_component_location;
sub evaluate_sensor;
my $opt_d = 0;
Getopt::Long::Configure('bundling');
GetOptions(
	"h"              => \$opt_h,
	"help"           => \$opt_h,
	"u=s"            => \$opt_u,
	"username=s"     => \$opt_u,
	"p=s"            => \$opt_p,
	"password=s"     => \$opt_p,
	"authprotocol=s" => \$opt_authproto,
	"k=s"            => \$opt_k,
	"key=s"          => \$opt_k,
	"priv=s"         => \$opt_priv,
	"privprotocol=s" => \$opt_privproto,
	"V"              => \$opt_V,
	"version"        => \$opt_V,
	"v=s"            => \$opt_v,
	"snmp=s"         => \$opt_v,
	"C=s"            => \$opt_C,
	"community=s"    => \$opt_C,
	"w=s"            => \$opt_w,
	"warning=s"      => \$opt_w,
	"c=s"            => \$opt_c,
	"critical=s"     => \$opt_c,
	"H=s"            => \$opt_H,
	"hostname=s"     => \$opt_H,
	"d=s"            => \$opt_d,
	"debug=s"        => \$opt_d,
	"i"              => \$opt_i,
	"sysdescr"       => \$opt_i
);

if ($opt_V) {
	print($PROGNAME. ': $Revision: ' . $version . '.' . $release . "\n");
	exit $ERRORS{'OK'};
}

if ($opt_h) {
	print_help();
	exit $ERRORS{'OK'};
}

$opt_H = shift unless ($opt_H);
(print_usage() && exit $ERRORS{'OK'}) unless ($opt_H);

my $snmp = "1";
if ($opt_v && $opt_v =~ /^[0-9]$/) {
	$snmp = $opt_v;
}

if ($snmp eq "3") {
	if (!$opt_u) {
		print "Option -u (--username) is required for snmpV3\n";
		exit $ERRORS{'OK'};
	}
	if (!$opt_p && !$opt_k) {
		print "Option -k (--key) or -p (--password) is required for snmpV3\n";
		exit $ERRORS{'OK'};
	}
	elsif ($opt_p && $opt_k) {
		print "Only option -k (--key) or -p (--password) is needed for snmpV3\n";
		exit $ERRORS{'OK'};
	}
}

$opt_C ||= 'public';
$opt_w ||= '80,70,60';
$opt_c ||= '90,80,70';

my $name = $0;
$name =~ s/\.pl.*//g;

#===  create a SNMP session ====

my ($session, $error);
if ($snmp eq "1" || $snmp eq "2") {
	($session, $error) = Net::SNMP->session(-hostname => $opt_H, -community => $opt_C, -version => $snmp, -maxmsgsize => "5000");
}
elsif ($opt_p && $opt_priv && $opt_authproto && $opt_privproto) {
	($session, $error) = Net::SNMP->session(
		-hostname     => $opt_H,
		-version      => $snmp,
		-username     => $opt_u,
		-authpassword => $opt_p,
		-authprotocol => $opt_authproto,
		-privpassword => $opt_priv,
		-privprotocol => $opt_privproto,
		-maxmsgsize   => "5000"
	);
}
elsif ($opt_p && $opt_priv) {
	($session, $error) = Net::SNMP->session(-hostname => $opt_H, -version => $snmp, -username => $opt_u, -authpassword => $opt_p, -privpassword => $opt_priv, -maxmsgsize => "5000");
}
elsif ($opt_p && $opt_authproto) {
	($session, $error) = Net::SNMP->session(-hostname => $opt_H, -version => $snmp, -username => $opt_u, -authpassword => $opt_p, -authprotocol => $opt_authproto, -maxmsgsize => "5000");
}
elsif ($opt_p) {
	($session, $error) = Net::SNMP->session(-hostname => $opt_H, -version => $snmp, -username => $opt_u, -authpassword => $opt_p, -maxmsgsize => "5000");
}
elsif ($opt_k) {
	($session, $error) = Net::SNMP->session(-hostname => $opt_H, -version => $snmp, -username => $opt_u, -authkey => $opt_k, -maxmsgsize => "5000");
}

# check that session opened
if (!defined($session)) {
	print("UNKNOWN: SNMP Session : $error\n");
	exit $ERRORS{'UNKNOWN'};
}

# Here we go !
my $loglevel = $opt_d;
my $result;
my $key;
my $value;
my @perfparse;

# parse sysDescr
my $outlabel_oid;
if ($opt_i) {

	# sysdescr
	$outlabel_oid = ".1.3.6.1.2.1.1.1.0";
}
else {
	# sysname
	$outlabel_oid = ".1.3.6.1.2.1.1.5.0";
}
verbose("get sysdescr ($outlabel_oid)", "5");
my $sysdescr = $session->get_request(-varbindlist => [$outlabel_oid]);
if (!defined($sysdescr)) {
	print("UNKNOWN: SNMP get_request : " . $session->error() . "\n");
	exit $ERRORS{'UNKNOWN'};
}
verbose(" sysdescr is " . $sysdescr->{$outlabel_oid}, "5");
my $outlabel = $sysdescr->{$outlabel_oid} . ": ";

my @nagios_return_code = ("OK", "WARNING", "CRITICAL", "UNKNOWN");

# prepare warning and critical thresholds
my @warning_threshold  = split(',', $opt_w) if (defined($opt_w));
my @critical_threshold = split(',', $opt_c) if (defined($opt_c));

use constant THRESHOLD_5_SECONDS => "0";
use constant THRESHOLD_1_MINUTE  => "1";
use constant THRESHOLD_5_MINUTES => "2";

# define some useful constants

####################
# cpmCPUTotalTable #
####################
# base oid
use constant cpmCPUTotalTable => ".1.3.6.1.4.1.9.9.109.1.1.1";

use constant cpmCPUTotalIndex   => ".1.3.6.1.4.1.9.9.109.1.1.1.1.1";
use constant cpmCPUTotal5secRev => ".1.3.6.1.4.1.9.9.109.1.1.1.1.6";
use constant cpmCPUTotal1minRev => ".1.3.6.1.4.1.9.9.109.1.1.1.1.7";
use constant cpmCPUTotal5minRev => ".1.3.6.1.4.1.9.9.109.1.1.1.1.8";

##################### RETRIEVE DATA #######################
###### get the cpmCPU table
verbose("get cpu statistics table", "5");
my %nexus_cpu = get_nexus_table(cpmCPUTotalTable, false);

###########################################################################################
#
###########################################################################################
my $cpu;
my $label;
my $cpu_data;
my $return_code = $ERRORS{'OK'};
while ((my $id, $cpu) = each(%nexus_cpu)) {
	if (defined($cpu)) {
		my %cpu_data = %{$cpu};
		my $five_sec = $cpu_data{&cpmCPUTotal5secRev};
		my $one_min  = $cpu_data{&cpmCPUTotal1minRev};
		my $five_min = $cpu_data{&cpmCPUTotal5minRev};

		if (($five_sec > $warning_threshold[&THRESHOLD_5_SECONDS]) || ($one_min > $warning_threshold[&THRESHOLD_1_MINUTE]) || ($five_min > $warning_threshold[&THRESHOLD_5_MINUTES])) {
			if (($five_sec > $critical_threshold[&THRESHOLD_5_SECONDS]) || ($one_min > $critical_threshold[&THRESHOLD_1_MINUTE]) || ($five_min > $critical_threshold[&THRESHOLD_5_MINUTES]))
			{
				$return_code = $ERRORS{'CRITICAL'};
			}
			else {
				$return_code = $ERRORS{'WARNING'};
			}
		}
		$label .= "cpu${id}-5_seconds=$five_sec%,cpu${id}-1_minute=$one_min%,cpu${id}-5_minutes=$five_min% ";
		push(@perfparse,
			"cpu${id}-5_seconds=$five_sec%;$warning_threshold[&THRESHOLD_5_SECONDS];$critical_threshold[&THRESHOLD_5_SECONDS];0;100 cpu${id}-1_minute=$one_min%;$warning_threshold[&THRESHOLD_1_MINUTE];$critical_threshold[&THRESHOLD_1_MINUTE];0;100 cpu${id}-5_minutes=$five_min%;$warning_threshold[&THRESHOLD_5_MINUTES];$critical_threshold[&THRESHOLD_5_MINUTES];0;100"
		);
	}
}

print $outlabel. $nagios_return_code[$return_code] . " $label\n";
print "| ";
foreach (@perfparse) {
	print "$_\n";
}
exit($return_code);

sub print_usage ()
{
	print "Usage:";
	print "$PROGNAME\n";
	print "   -H (--hostname)   Hostname to query - (required)\n";
	print "   -C (--community)  SNMP read community (defaults to public,\n";
	print "                     used with SNMP v1 and v2c\n";
	print "   -v (--snmp_version)  1 for SNMP v1 (default)\n";
	print "                        2 for SNMP v2c\n";
	print "                        3 for SNMP v3\n";
	print "   -k (--key)        snmp V3 key\n";
	print "   -p (--password)   snmp V3 password\n";
	print "   -u (--username)   snmp v3 username \n";
	print "   --authprotocol    snmp v3 authprotocol md5|sha \n";
	print "   --priv            snmp V3 priv password\n";
	print "   --privprotocol    snmp v3 privprotocol des|aes \n";
	print "   -V (--version)    Plugin version\n";
	print "   -h (--help)       usage help\n\n";
	print "   -i (--sysdescr)   use sysdescr instead of sysname for label display\n";
	print "   -w (--warning)    pass 3 values for warning threshold (5 seconds, 1 minute and 5 minutes cpu average usage in %, default is '80,70,60')\n";
	print "   -c (--critical)   pass 3 values for critical threshold (5 seconds, 1 minute and 5 minutes cpu average usage in %, default is '90,80,70')\n";
	print "\n";
	print "   -d (--debug)      debug level (1 -> 15)";
}

sub print_help ()
{
	print "##############################################\n";
	print "#                ADEO Services               #\n";
	print "##############################################\n";
	print_usage();
	print "\n";
}

sub verbose
{
	my $message      = $_[0];
	my $messagelevel = $_[1];

	if ($messagelevel <= $loglevel) {
		print "$message\n";
	}
}

sub get_nexus_table
{
	my $baseoid    = $_[0];
	my $is_indexed = $_[1];

	verbose("get table for oid $baseoid", "10");
	if ($snmp == 1) {
		$result = $session->get_table(-baseoid => $baseoid);
	}
	else {
		$result = $session->get_table(-baseoid => $baseoid, -maxrepetitions => 20);
	}
	if (!defined($result)) {
		print("UNKNOWN: SNMP get_table : " . $session->error() . "\n");
		exit $ERRORS{'UNKNOWN'};
	}
	my %nexus_values = %{$result};
	my $id;
	my $index;
	my %nexus_return;
	while (($key, $value) = each(%nexus_values)) {
		$index = $id = $key;
		if ($is_indexed) {
			$id =~ s/.*\.([0-9]+)\.[0-9]*$/$1/;
			$key =~ s/(.*)\.[0-9]*\.[0-9]*/$1/;
			$index =~ s/.*\.([0-9]+)$/$1/;
			verbose("key=$key, id=$id, index=$index, value=$value", "15");
			$nexus_return{$id}{$key}{$index} = $value;
			$nexus_return{$id}{"id"}{$index} = $id;
		}
		else {
			$id =~ s/.*\.([0-9]+)$/$1/;
			$key =~ s/(.*)\.[0-9]*/$1/;
			verbose("key=$key, id=$id, value=$value", "15");
			$nexus_return{$id}{$key} = $value;
			$nexus_return{$id}{"id"} = $id;
		}
	}
	return (%nexus_return);
}

sub get_nexus_entries
{
	my (@columns) = @_;

	verbose("get entries", "10");
	if ($snmp == 1) {
		$result = $session->get_entries(-columns => @columns);
	}
	else {
		$result = $session->get_entries(-columns => @columns, -maxrepetitions => 20);
	}
	if (!defined($result)) {
		print("UNKNOWN: SNMP get_entries : " . $session->error() . "\n");
		exit $ERRORS{'UNKNOWN'};
	}
	my %nexus_values = %{$result};
	my $id;
	my %nexus_return;
	while (($key, $value) = each(%nexus_values)) {
		$id = $key;
		$id =~ s/.*\.([0-9]+)$/$1/;
		$key =~ s/(.*)\.[0-9]*/$1/;
		verbose("key=$key, id=$id, value=$value", "15");
		$nexus_return{$id}{$key} = $value;
		$nexus_return{$id}{"id"} = $id;
	}
	return (%nexus_return);
}

