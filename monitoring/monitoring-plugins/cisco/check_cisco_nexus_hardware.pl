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
use vars qw($opt_h $opt_V $opt_H $opt_C $opt_v $opt_o $opt_c $opt_w $opt_t $opt_p $opt_k $opt_u $opt_l $opt_d $opt_i $opt_a $opt_authproto $opt_priv $opt_privproto);
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
	"a"              => \$opt_a,
	"admin"          => \$opt_a,
	"d=s"            => \$opt_d,
	"debug=s"        => \$opt_d,
	"i"              => \$opt_i,
	"sysdescr"       => \$opt_i,
	"l"              => \$opt_l,
	"list"           => \$opt_l
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

($opt_C) || ($opt_C = shift) || ($opt_C = "public");

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
my $label;
my $oid;
my $unit = "";
my $return_result;
my $output;
my $total_connection = 0;
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

# define some useful constants

# entSensorValues table oids
use constant entSensorType            => ".1.3.6.1.4.1.9.9.91.1.1.1.1.1";
use constant entSensorScale           => ".1.3.6.1.4.1.9.9.91.1.1.1.1.2";
use constant entSensorPrecision       => ".1.3.6.1.4.1.9.9.91.1.1.1.1.3";
use constant entSensorValue           => ".1.3.6.1.4.1.9.9.91.1.1.1.1.4";
use constant entSensorStatus          => ".1.3.6.1.4.1.9.9.91.1.1.1.1.5";
use constant entSensorValueTimeStamp  => ".1.3.6.1.4.1.9.9.91.1.1.1.1.6";
use constant entSensorValueUpdateRate => ".1.3.6.1.4.1.9.9.91.1.1.1.1.7";
use constant entSensorMeasuredEntity  => ".1.3.6.1.4.1.9.9.91.1.1.1.1.8";

# all sensors types
my @nexus_sensors_type = ("undefined", "other", "unknown", "voltsAC", "voltsDC", "amperes", "watts", "hertz", "celsius", "percentRH", "rpm", "cmm", "truthvalue", "special", "dBm");

# sensors scale
my @nexus_sensors_scale = ("unknown", "yocto", "zepto", "atto", "femto", "pico", "nano", "micro", "milli", "units", "kilo", "mega", "giga", "tera", "exa", "peta", "zetta", "yotta");

# all sensors status
my @nexus_sensors_status = ("undefined", "ok", "unavailable", "nonoperational");

# entSensorsThresholds oids
use constant entSensorThresholdIndex              => ".1.3.6.1.4.1.9.9.91.1.2.1.1.1";
use constant entSensorThresholdSeverity           => ".1.3.6.1.4.1.9.9.91.1.2.1.1.2";
use constant entSensorThresholdRelation           => ".1.3.6.1.4.1.9.9.91.1.2.1.1.3";
use constant entSensorThresholdValue              => ".1.3.6.1.4.1.9.9.91.1.2.1.1.4";
use constant entSensorThresholdEvaluation         => ".1.3.6.1.4.1.9.9.91.1.2.1.1.5";    # not used
use constant entSensorThresholdNotificationEnable => ".1.3.6.1.4.1.9.9.91.1.2.1.1.6";    # not used

my @nexus_sensors_threshold_relation = ("unknown", "less than", "less or equal than", "greater than", "greater or equal than", "equal to", "not equal to");

my @nagios_return_code = ("OK", "WARNING", "CRITICAL", "UNKNOWN");

# defines nexus sensor status
use constant NEXUS_OK       => 1;
use constant NEXUS_MINOR    => 10;
use constant NEXUS_MAJOR    => 20;
use constant NEXUS_CRITICAL => 30;
my @nexus_return_code;
$nexus_return_code[&NEXUS_OK]       = "OK";
$nexus_return_code[&NEXUS_MINOR]    = "MINOR";
$nexus_return_code[&NEXUS_MAJOR]    = "MAJOR";
$nexus_return_code[&NEXUS_CRITICAL] = "CRITICAL";

# nexus sensor status to nagios status table
my @nexus_sensor_to_nagios;
$nexus_sensor_to_nagios[&NEXUS_OK]    = $ERRORS{'OK'};
$nexus_sensor_to_nagios[&NEXUS_MINOR] = $ERRORS{'WARNING'};
$nexus_sensor_to_nagios[&NEXUS_MAJOR] = $ERRORS{'CRITICAL'}, $nexus_sensor_to_nagios[&NEXUS_CRITICAL] = $ERRORS{'CRITICAL'};
###############
# entPhysical #
###############
# entPhysical oids
use constant entPhysicalIndex        => ".1.3.6.1.2.1.47.1.1.1.1.1";
use constant entPhysicalDescr        => ".1.3.6.1.2.1.47.1.1.1.1.2";
use constant entPhysicalVendorType   => ".1.3.6.1.2.1.47.1.1.1.1.3";
use constant entPhysicalContainedIn  => ".1.3.6.1.2.1.47.1.1.1.1.4";
use constant entPhysicalClass        => ".1.3.6.1.2.1.47.1.1.1.1.5";
use constant entPhysicalParentRelPos => ".1.3.6.1.2.1.47.1.1.1.1.6";
use constant entPhysicalName         => ".1.3.6.1.2.1.47.1.1.1.1.7";
use constant entPhysicalHardwareRev  => ".1.3.6.1.2.1.47.1.1.1.1.8";
use constant entPhysicalFirmwareRev  => ".1.3.6.1.2.1.47.1.1.1.1.9";
use constant entPhysicalSoftwareRev  => ".1.3.6.1.2.1.47.1.1.1.1.10";
use constant entPhysicalSerialNum    => ".1.3.6.1.2.1.47.1.1.1.1.11";
use constant entPhysicalMfgName      => ".1.3.6.1.2.1.47.1.1.1.1.12";
use constant entPhysicalModelName    => ".1.3.6.1.2.1.47.1.1.1.1.13";
use constant entPhysicalAlias        => ".1.3.6.1.2.1.47.1.1.1.1.14";
use constant entPhysicalAssetID      => ".1.3.6.1.2.1.47.1.1.1.1.15";
use constant entPhysicalIsFRU        => ".1.3.6.1.2.1.47.1.1.1.1.16";
use constant entPhysicalMfgDate      => ".1.3.6.1.2.1.47.1.1.1.1.17";
use constant entPhysicalUris         => ".1.3.6.1.2.1.47.1.1.1.1.18";

my @nexus_entphysical_class = ("undefined", "other", "unknown", "chassis", "backplane", "container", "power supply", "fan", "sensor", "module", "port", "stack", "cpu");

# Base table OIDs
use constant entSensorValueTable     => ".1.3.6.1.4.1.9.9.91.1.1.1";
use constant entPhysicalTable        => ".1.3.6.1.2.1.47.1.1.1";
use constant cefcFanTrayStatusTable  => ".1.3.6.1.4.1.9.9.117.1.4.1";
use constant cefcFanCoolingTable     => ".1.3.6.1.4.1.9.9.117.1.7.2";
use constant entSensorThresholdTable => ".1.3.6.1.4.1.9.9.91.1.2.1";
use constant cefcFRUPowerStatusTable => ".1.3.6.1.4.1.9.9.117.1.1.2";

# mib2 interface status OIDs
use constant ifDescr       => ".1.3.6.1.2.1.2.2.1.2";
use constant ifAdminStatus => ".1.3.6.1.2.1.2.2.1.7";

my @nexus_admin_status = ("undefined", "up", "down", "testing");

# Fan
use constant cefcFanTrayOperStatus => ".1.3.6.1.4.1.9.9.117.1.4.1.1.1";

use constant NEXUS_FANTRAY_UNKNOWN => "1";
use constant NEXUS_FANTRAY_UP      => "2";
use constant NEXUS_FANTRAY_DOWN    => "3";
use constant NEXUS_FANTRAY_WARNING => "4";

my @nexus_fantray_status = ("undefined", "unknown", "up", "down", "warning");

# nexus fantray status to nagios status table
my @nexus_fantray_status_to_nagios;
$nexus_fantray_status_to_nagios[&NEXUS_FANTRAY_UNKNOWN] = $ERRORS{'UNKNOWN'};
$nexus_fantray_status_to_nagios[&NEXUS_FANTRAY_UP]      = $ERRORS{'OK'};
$nexus_fantray_status_to_nagios[&NEXUS_FANTRAY_DOWN]    = $ERRORS{'WARNING'}, $nexus_fantray_status_to_nagios[&NEXUS_FANTRAY_WARNING] = $ERRORS{'CRITICAL'};
my @nexus_fancooling_unit = ("undefined", "cfm", "watts");

# PSU
use constant cefcFRUPowerAdminStatus => ".1.3.6.1.4.1.9.9.117.1.1.2.1.1";
use constant cefcFRUPowerOperStatus  => ".1.3.6.1.4.1.9.9.117.1.1.2.1.2";
use constant cefcFRUCurrent          => ".1.3.6.1.4.1.9.9.117.1.1.2.1.3";
use constant cefcFRUPowerCapability  => ".1.3.6.1.4.1.9.9.117.1.1.2.1.4";
use constant cefcFRURealTimeCurrent  => ".1.3.6.1.4.1.9.9.117.1.1.2.1.5";

use constant NEXUS_PSU_OFFENVOTHER          => "1";
use constant NEXUS_PSU_ON                   => "2";
use constant NEXUS_PSU_OFFADMIN             => "3";
use constant NEXUS_PSU_OFFDENIED            => "4";
use constant NEXUS_PSU_OFFENVPOWER          => "5";
use constant NEXUS_PSU_OFFENVTEMP           => "6";
use constant NEXUS_PSU_OFFENVFAN            => "7";
use constant NEXUS_PSU_FAILED               => "8";
use constant NEXUS_PSU_ONBUTFANFAIL         => "9";
use constant NEXUS_PSU_OFFCOOLING           => "10";
use constant NEXUS_PSU_OFFCONNECTORRATING   => "11";
use constant NEXUS_PSU_ONBUTINLINEPOWERFAIL => "12";

my @nexus_psu_status =
	("undefined", "offEnvOther", "on", "offAdmin", "offDenied", "offEnvPower", "offEnvTemp", "offEnvFan", "failed", "onButFanFail", "offCooling", "offConnectorRating", "onbutInlinePowerFail");

# nexus psu status to nagios status table
my @nexus_psu_status_to_nagios;
$nexus_psu_status_to_nagios[&NEXUS_PSU_OFFENVOTHER]          = $ERRORS{'UNKNOWN'};
$nexus_psu_status_to_nagios[&NEXUS_PSU_ON]                   = $ERRORS{'OK'};
$nexus_psu_status_to_nagios[&NEXUS_PSU_OFFADMIN]             = $ERRORS{'WARNING'};
$nexus_psu_status_to_nagios[&NEXUS_PSU_OFFDENIED]            = $ERRORS{'WARNING'};
$nexus_psu_status_to_nagios[&NEXUS_PSU_OFFENVPOWER]          = $ERRORS{'WARNING'};
$nexus_psu_status_to_nagios[&NEXUS_PSU_OFFENVTEMP]           = $ERRORS{'WARNING'};
$nexus_psu_status_to_nagios[&NEXUS_PSU_OFFENVFAN]            = $ERRORS{'WARNING'};
$nexus_psu_status_to_nagios[&NEXUS_PSU_FAILED]               = $ERRORS{'CRITICAL'};
$nexus_psu_status_to_nagios[&NEXUS_PSU_ONBUTFANFAIL]         = $ERRORS{'CRITICAL'};
$nexus_psu_status_to_nagios[&NEXUS_PSU_OFFCOOLING]           = $ERRORS{'CRITICAL'};
$nexus_psu_status_to_nagios[&NEXUS_PSU_OFFCONNECTORRATING]   = $ERRORS{'CRITICAL'};
$nexus_psu_status_to_nagios[&NEXUS_PSU_ONBUTINLINEPOWERFAIL] = $ERRORS{'CRITICAL'};

##################### RETRIEVE DATA #######################
###### get the sensor table
verbose("get sensor table", "5");
my %nexus_sensors = get_nexus_table(entSensorValueTable, false);

###### get the sensor threshold table
verbose("get sensor threshold table", "5");
my %nexus_sensors_thresholds = get_nexus_table(entSensorThresholdTable, true);

###### get the fru fan table
verbose("get fru fan table", "5");
my %nexus_frufan = get_nexus_table(cefcFanTrayStatusTable, false);

###### get the fru PSU table
verbose("get fru psu table", "5");
my %nexus_frupsu = get_nexus_table(cefcFRUPowerStatusTable, false);

###### get the physical table
verbose("get entity physical table", "5");

# get only selected columns to speed up data retrieving
my %nexus_entphysical = get_nexus_entries([ &entPhysicalDescr, &entPhysicalContainedIn, &entPhysicalClass ]);

###### get the physical table
my %nexus_interface;
if ($opt_a) {
	verbose("get interface table", "5");

	# get only selected columns to speed up data retrieving
	%nexus_interface = get_nexus_interface([ &ifDescr, &ifAdminStatus ]);
}

# When user want to list probes
if ($opt_l) {
	print "List of probes:\n";
}

#################################################################################
# parse the table to get the worst status and append it to the output string.   #
# nexus sensor can have many thresholds, so we test them and keep the worst one #
#################################################################################
my $sensor;
my $sensor_alarm;
my $worse_status             = 0;
my @failed_items_description = ();
my $number_of_sensors        = 0;
my $number_of_failed_sensors = 0;
while ((my $id, $sensor) = each(%nexus_sensors)) {
	my $worse_sensor_status      = NEXUS_OK;
	my $worse_sensor_description = "";
	if (defined($sensor)) {
		$number_of_sensors++;
		my %sensor_data = %{$sensor};

		# get all sensor thresholds data
		next if (!defined($nexus_sensors_thresholds{ $sensor_data{"id"} }{&entSensorThresholdRelation}));
		my %sensor_threshold_data = %{ $nexus_sensors_thresholds{ $sensor_data{"id"} }{&entSensorThresholdRelation} };

		# test each threshold values and keep the worst one
		while ((my $thresh_index, my @thresh_data) = each(%sensor_threshold_data)) {
			my $sensor_value    = $sensor_data{&entSensorValue};
			my $thresh_value    = $nexus_sensors_thresholds{ $sensor_data{"id"} }{&entSensorThresholdValue}{$thresh_index};
			my $thresh_relation = $nexus_sensors_thresholds{ $sensor_data{"id"} }{&entSensorThresholdRelation}{$thresh_index};
			my $thresh_severity = $nexus_sensors_thresholds{ $sensor_data{"id"} }{&entSensorThresholdSeverity}{$thresh_index};

			# proceed with the evaluation (is sensor value {<=|<|=|!=|>|>=} threshold value)
			verbose("threshold data: thresh_value=$thresh_value tresh_relation=$thresh_relation thresh_severity=$thresh_severity sensor_value=$sensor_value", "15");
			$sensor_alarm = evaluate_sensor($sensor_value, $thresh_relation, $thresh_value, $thresh_severity);
			if ($sensor_alarm > $worse_sensor_status) {

				# too bad, sensor has detected something abnormal
				# keep the alarm description for the user
				$worse_sensor_description =
					  "$sensor_value"
					. $nexus_sensors_scale[ $sensor_data{&entSensorScale} ] . " "
					. $nexus_sensors_type[ $sensor_data{&entSensorType} ] . " is "
					. $nexus_sensors_threshold_relation[$thresh_relation]
					. " $thresh_value";
			}

			# if interface is not Admin down, keep only the worst sensor status (critical status not overwritten by minor status) for the current sensor
			if (defined $nexus_entphysical{$id}{&entPhysicalDescr}) {
				unless ($opt_a and $nexus_entphysical{$id}{&entPhysicalDescr} =~ /(\S+) Transceiver/ and defined $nexus_interface{$1} and $nexus_interface{$1} != 1) {
					$worse_sensor_status = max($worse_sensor_status, $sensor_alarm);
				}
			}
		}
		verbose("sensor_alarm = $worse_sensor_status (nagios_rc=" . $nexus_sensor_to_nagios[$worse_sensor_status] . ")", "10");

		# put failed items in a separate table
		if ($worse_sensor_status ne NEXUS_OK) {
			verbose("add new sensor status for sensor_id = "
					. $sensor_data{"id"} . " ("
					. get_nexus_component_location($id) . ") rc="
					. $nexus_return_code[$sensor_alarm]
					. ". type is ="
					. $nexus_sensors_type[ $sensor_data{&entSensorType} ],
				15
			);
			if (defined($nexus_entphysical{$id}{&entPhysicalDescr})) {

				# skip alert if interface is Admin down
				if ($opt_a and $nexus_entphysical{$id}{&entPhysicalDescr} =~ /(\S+) Transceiver/ and defined $nexus_interface{$1} and $nexus_interface{$1} != 1) {
					verbose("not alerting on Transceiver with with interface in state " . $nexus_admin_status[ $nexus_interface{$1} ], 10);
				}
				else {
					$number_of_failed_sensors++;
					push(@failed_items_description,
						          $nexus_return_code[$sensor_alarm] . ": "
							. $nexus_sensors_type[ $sensor_data{&entSensorType} ] . " ("
							. get_nexus_component_location($sensor_data{"id"})
							. ") is failed: $worse_sensor_description");
				}
			}
		}

		# if list option enabled, list sensor data
		if ($opt_l) {

			# this does the job, but undefined values can be thrown
			print "Sensor " . $sensor_data{"id"};
			print " value: " . $sensor_data{&entSensorValue};
			print " " . $nexus_sensors_scale[ $sensor_data{&entSensorScale} ];
			print " " . $nexus_sensors_type[ $sensor_data{&entSensorType} ];
			print " status: " . $nexus_sensors_status[ $sensor_data{&entSensorStatus} ];
			print " type: " . $nexus_entphysical_class[ $nexus_entphysical{ $sensor_data{"id"} }{&entPhysicalClass} ];
			print " located in: " . get_nexus_component_location($sensor_data{"id"});
			print "\n";
		}
		if (defined($nexus_entphysical{$id}{&entPhysicalDescr})) {
			my $ent_description = $nexus_entphysical{$id}{&entPhysicalDescr};
			$ent_description =~ s/\s/_/g;
			$ent_description =~ s/,//g;
			#sometimes the entPhysicalDescr is the same for more than one sensor.
			#let's add "id" to differentiate the variable name in perf data
			$ent_description .= '_' . $sensor_data{"id"};
			push(@perfparse, $ent_description . "=" . $sensor_data{&entSensorValue} . $nexus_sensors_type[ $sensor_data{&entSensorType} ] . ";;;;");
		}

		$worse_status = max($worse_status, $worse_sensor_status);
	}
}

##################################################################################
# parse the fan table to get the worst status and append it to the output string.#
##################################################################################
my $fan;
my $fan_data;
my $worst_fan_status     = NEXUS_FANTRAY_UP;
my $number_of_failed_fan = 0;
my $number_of_fans;
while ((my $id, $fan) = each(%nexus_frufan)) {
	if (defined($fan)) {
		my %fan_data = %{$fan};

		if ($fan_data{&cefcFanTrayOperStatus} != NEXUS_FANTRAY_UP) {
			push(@failed_items_description, get_nexus_component_location($fan_data{"id"}) . " is " . $nexus_fantray_status[ $fan_data{&cefcFanTrayOperStatus} ]);
			$number_of_failed_fan++;
		}
		if ($opt_l) {
			print "Fan " . $fan_data{"id"};
			print " located in: " . get_nexus_component_location($fan_data{"id"});
			print " status is " . $nexus_fantray_status[ $fan_data{&cefcFanTrayOperStatus} ];
			print "\n";
		}
		$worst_fan_status = max($worst_fan_status, $fan_data{&cefcFanTrayOperStatus});
		$number_of_fans++;
	}
}

###########################################################################################
# parse the power supply table to get the worst status and append it to the output string.#
###########################################################################################
my $psu;
my $psu_data;
my $worst_psu_status     = NEXUS_PSU_ON;
my $number_of_failed_psu = 0;
my $number_of_psu;
while ((my $id, $psu) = each(%nexus_frupsu)) {
	if (defined($psu)) {
		my %psu_data = %{$psu};

		if ($psu_data{&cefcFRUPowerOperStatus} != NEXUS_PSU_ON) {
			push(@failed_items_description, get_nexus_component_location($psu_data{"id"}) . " is " . $nexus_psu_status[ $psu_data{&cefcFRUPowerOperStatus} ]);
			$number_of_failed_psu++;
		}
		if ($opt_l) {
			print "PSU " . $psu_data{"id"};
			print " located in: " . get_nexus_component_location($psu_data{"id"});
			print " status is " . $nexus_psu_status[ $psu_data{&cefcFRUPowerOperStatus} ];
			print "\n";
		}
		$worst_psu_status = max($worst_psu_status, $psu_data{&cefcFRUPowerOperStatus});
		$number_of_psu++;
	}
}

# translate the return_code (nexus code)
my $sensor_return_code = $nexus_sensor_to_nagios[$worse_status];
my $fan_return_code    = $nexus_fantray_status_to_nagios[$worst_fan_status];
my $psu_return_code    = $nexus_psu_status_to_nagios[$worst_psu_status];

my $worst_final_return_code = max($sensor_return_code, $fan_return_code, $psu_return_code);

print $outlabel. $nagios_return_code[$worst_final_return_code];
print " (";
print "$number_of_failed_sensors sensor" . ($number_of_failed_sensors <= 1 ? "" : "s") . " failed on $number_of_sensors";
print ", $number_of_failed_fan fan" .      ($number_of_failed_fan <= 1     ? "" : "s") . " failed on $number_of_fans";
print ", $number_of_failed_psu psu failed on $number_of_psu";
print ")\n";
foreach (@failed_items_description) {
	print "$_\n";
}
print "| ";
foreach (@perfparse) {
	print "$_\n";
}
exit($worst_final_return_code);

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
	print "   -l (--list)       list probes\n";
	print "   -a (--admin)      filter Transceiver alerts by adminstatus\n";
	print "   -i (--sysdescr)   use sysdescr instead of sysname for label display\n";
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

sub get_nexus_interface
{
	my %entries = get_nexus_entries(@_);
	my %nexus_return;
	for my $int (values %entries) {
		$nexus_return{ $$int{ $_[0][0] } } = $$int{ $_[0][1] };
	}
	return (%nexus_return);
}

sub evaluate_sensor
{
	my $value     = $_[0];
	my $compare   = $_[1];
	my $threshold = $_[2];
	my $severity  = $_[3];
	my $rc        = NEXUS_OK;
	verbose("compare $value to $threshold and will return $severity if operator $compare is met", "15");
	switch ($compare) {
		case 1 {
			verbose("lessthan compare", "10");
			if ($value < $threshold) {
				$rc = $severity;
			}
		}
		case 2 {
			verbose("lessorequal compare", "10");
			if ($value <= $threshold) {
				$rc = $severity;
			}
		}
		case 3 {
			verbose("greaterthan compare", "10");
			if ($value > $threshold) {
				$rc = $severity;
			}
		}
		case 4 {
			verbose("greaterorequal compare", "10");
			if ($value > $threshold) {
				$rc = $severity;
			}
		}
		case 5 {
			verbose("equalto compare", "10");
			if ($value == $threshold) {
				$rc = $severity;
			}
		}
		case 6 {
			verbose("noequalto compare", "10");
			if ($value != $threshold) {
				$rc = $severity;
			}
		}
	}
	verbose("comparison result: $rc", "15");
	return ($rc);
}

sub get_nexus_component_location
{
	my $sensor_id   = $_[0];
	my $text_output = "";
	$text_output = $nexus_entphysical{$sensor_id}{&entPhysicalDescr} if (defined($nexus_entphysical{$sensor_id}{&entPhysicalDescr}));
	my $parent = $nexus_entphysical{$sensor_id}{&entPhysicalContainedIn};
	while (defined($parent) and $parent ne 0) {
		$text_output .= "->" . $nexus_entphysical{$parent}{&entPhysicalDescr};
		$parent = $nexus_entphysical{$parent}{&entPhysicalContainedIn};
	}
	return ($text_output);
}
