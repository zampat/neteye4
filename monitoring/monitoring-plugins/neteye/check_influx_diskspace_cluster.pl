#!/usr/bin/perl
#
# FILE: check_influx_diskspace_cluster.pl
#
# Copyright 2019 WuerthPhoenix
# (c)2019 Juergen Vigna, Wuerth Phoenix s.r.l.
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty
# of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# you should have received a copy of the GNU General Public License
# along with this program (or with Nagios);  if not, write to the
# Free Software Foundation, Inc., 59 Temple Place - Suite 330,
# Boston, MA 02111-1307, USA
#
# Gets last value for given disk metric for more servers and returns the first found instance
#
# Update 2020-05-05: Allow to pass multiple hosts within parameter -S. The script assembles the regular expression in autonomy
#
my $Version = "1.0.0";

use JSON;
use Data::Dumper;
use Getopt::Long;
use EV;
use AnyEvent;
use AnyEvent::Socket;
use AnyEvent::Handle;
use AnyEvent::InfluxDB;
use Nagios::Plugin;

my $PROGNAME = "check_influx_diskspace_cluster.pl";
my $VERSION  = "1.1.0";

my $influx_host = "influxdb.neteyelocal";
my $influx_port = "8086";
my $influx_user = "admin";
my $influx_pass = "admin";
my $influx_database = "icinga2";
my $measurement = "disk-windows";

my $np = Nagios::Plugin->new(
  usage => "Usage: $PROGNAME [-H <influxdb hostname/IP>] [-p <influxdb port>] -S <hostname1> <hostname2> <hostname3>\n"
    . "\t[-M <measurement-name>] -m <disk-metric-name> [-w <warning>] [-c <critical>]\n"
    . "\t[ -V ] [ -h ]",
  version => $VERSION,
  plugin  => $PROGNAME,
  shortname => ' ',
  blurb => 'Gets last value for given disk metric for more servers and returns the first found instance. All values are retreived from the influxdb, status, max, warning, critical',
  extra   => "\nCopyright 2019 WuerthPhoenix\n"
    . "",
  timeout => 30,
);

$np->add_arg(
  spec => 'host|H=s',
  help => "-H, --host=<hostname>\n"
    . "  influxdb hostname (Default: $host)",
  required => 0,
);

$np->add_arg(
  spec => 'port|p=s',
  help => "-p, --port=<influx-port>\n"
    . "  influxdb tcp port (Default: $port)",
  required => 0,
);

$np->add_arg(
  spec => 'measurement|M=s',
  help => "-M, --measurement=<name>\n"
    . '  influxdb measurements to use (Default: $measurement)\n',
  required => 0,
);

$np->add_arg(
  spec => 'server|S=s',
  help => "-S, --server=<servers>\n"
    . '  Cluster Servers to get the disk-values from. This is a coma separated list of server-names as found in the monitoring.',
  required => 1,
);

$np->add_arg(
  spec => 'metric|m=s',
  help => "-m, --metric=<string>\n"
    . '  disk-metric string to search for\n',
  required => 1,
);

$np->add_arg(
  spec => 'debug|D',
  help => "-D, --debug\n"
    . '  Give DEBUG output',
  required => 0,
);

$np->add_arg(
  spec => 'verbose|v',
  help => "-v, --verbose\n"
    . '  Give verbose output',
  required => 0,
);

$np->add_arg(
  spec => 'warning|w=s',
  help => "-w, --warning\n"
    . '  warning value for % free disk (if not defined get it from DB)',
  required => 0,
);

$np->add_arg(
  spec => 'critical|c=s',
  help => "-c, --critical\n"
    . '  critcal value for % free disk (if not defined get it from DB)',
  required => 0,
);

$np->getopts;

if (defined($np->opts->host)) {
	$influx_host = $np->opts->host;
}

if (defined($np->opts->measurement)) {
	$measurement = $np->opts->measurement;
}

if (defined($np->opts->port)) {
	$influx_port = $np->opts->port;
}

my $server      = $np->opts->server;
my $metric      = $np->opts->metric;
my $verbose     = $np->opts->verbose;
my $debug       = $np->opts->debug;
my $warning     = $np->opts->warning;
my $critical    = $np->opts->critical;
my $exitCode    = 3;
my $output      = "";

#Collect the remaining Arguments from -S ARGS
#This allows to call -S with multiple hosts
foreach $argnum (0 .. $#ARGV) {
    $server = "$server|$ARGV[$argnum]" if $ARGV[$argnum];
    if ($verbose) {
        print "[i] Got another server. This regex: $server\n";
    }
}


my $db = AnyEvent::InfluxDB->new(
        server => "http://$influx_host:$influx_port",
        username => $influx_user,
        password => $influx_pass,
);

my $cv = AE::cv;
my $query = "hostname =~ /$server/ AND metric =~ /$metric/";
if ($verbose) {
        printf "%s\n", $query;
}

$db->select(
        database => $influx_database,
        measurement => "\"$measurement\"",
        fields => 'last(value) as value,max,warn,crit,hostname,service',
        where => $query,
        on_success => $cv,
        on_error => sub {
            $cv->croak("Failed to select data: @_");
        }
);
my @results = @{$cv->recv};

my $value;
my $max;
my $warn;
my $crit;
my $state;
my $host;
my $service;

for my $row ( @results ) {
    foreach my $val (@{$row->{values}}) {
        if ($verbose) {
            print "VAL:".$val->{value}.",".$val->{max}.",".$val->{warn}.",".$val->{crit}."\n";
        }
        $value   = $val->{value};
        $max     = $val->{max};
        $warn = $val->{warn};
        $crit = $val->{crit};
        $host    = $val->{hostname};
        $service = $val->{service};
        if ($debug) {
            printf "%s\n%s\n", $server, Data::Dumper::Dumper($val);
        }
    }
}

$query = "hostname =~ /$host/ AND service =~ /$service/";
if ($verbose) {
        printf "%s\n", $query;
}

$cv = AE::cv;
$db->select(
        database => $influx_database,
        measurement => "\"$measurement\"",
        fields => 'last(state) as state',
        where => $query,
        on_success => $cv,
        on_error => sub {
            $cv->croak("Failed to select data: @_");
        }
);
@results = @{$cv->recv};

for my $row ( @results ) {
    foreach my $val (@{$row->{values}}) {
        if ($verbose) {
            print "STATE:".$val->{state}."\n";
        }
        $state = $val->{state};
        if ($debug) {
            printf "%s:%s\n%s\n", $host, $service, Data::Dumper::Dumper($val);
        }
    }
}

if (!defined($value) || !defined($state)) {
	print "UNKNOWN - Could not get data from Database, wrong parameters?";
	exit 3;
}

if (defined($warning)) {
    $warn = $max / 100 * $warning;
}

if (defined($critical)) {
    $crit = $max / 100 * $critical;
}

$np->set_thresholds(critical => "$crit:", warning => "$warn:");
$state = $np->check_threshold($value);
$np->add_perfdata(label => "$metric", value => $value, critical => $crit, warning => $warn, min => 0,  max => $max);
my $vmb = $value / 1024 / 1024;
my $vp = ($value / $max * 100) + 0.5;
$output = sprintf("DISK free space: $metric($host) %.02f MB (%.0f%)",$vmb,$vp);
$np->nagios_exit($state, $output);
