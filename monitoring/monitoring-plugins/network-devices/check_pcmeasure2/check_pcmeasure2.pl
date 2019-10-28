#!/usr/bin/perl -w

# -----------------------------------------------

=head1 NAME

check_pcmeasure2.pl - Nagios Plugin for pcmeasure (www.messpc.de)

=head1 SYNOPSIS

check_pcmeasure2.pl -H <host> -S <sensor>[,<sensor] [-p <port>] 
   [-w <threshold>] [-c <threshold>] [-v] [-V]
   [-R <rrd file>] [-T <sensortype>] [-t <timeout>]
   [-F <formatstring>] [-l <label>]

Connects to the program pcmeasure or a ethernet messbox
to ask for values of connected hardware
sensors. pcmeasure is available as Linux or Windows program, the sensors
are connected via serial or parallel port. On the standalone ethernet
messbox the sensors are connected directly. There are different sensors 
available: temperature, humidity, voltage, smoke, motion, water and more. 
Please check www.messpc.de (german) or wwww.pcmeasure.com (english) 
for further informations.

For threshold format and some examples have a look at
http://nagiosplug.sourceforge.net/developer-guidelines.html#THRESHOLDFORMAT

=head1 OPTIONS

=over 4

=item -H|--host=<name-or-ip>

Hostname or ip address of the server running pcmeasure

=item -p|--port=<port>

The port where the program "pcmeasure" is listening

=item -w|--warning=<treshold>

WARNING threshold. Example: -w 18:22 returns OK if result is between 18 and
22, WARNING otherwise.

=item -c|--critical=<threshold>

CRITICAL threshold. See --warning.

=item -S|--sensor=<sensor>[,<sensor>]

Normally one single sensor you want to check. 
In some cases you need to specify two sensors (-T barometer).

Examples: com1.1 (sensor 1 on serial port 1)
lpt1.2 (sensor 2 on parallel port 1).

=item -T|--type=standard|brightness|barometer

Type of sensor. Default: standard. type=barometer needs to sensors

=item -l|--label=<label>

Label for performance data

=item -F|--format-string=<format-string>

Format string for text output, used with sprintf($formatstring, $value).
Default: "$label = %.1f". Example for temperature:

   "current temperature: %.1f �C"

=item -R|--rrd-database=<path-to-db>

You can store the retrieving value in a Round Robin Database RRD.
The database is updated with "N:<value>" (means: current time:given value)
and should be writeable by your nagios user. The rrd database would be
created, if not exist. To change the parameters for database creation,
create rrd database manually or change the values in this plugin
(subroutine create*rrd). 

For infos about Round Robin Databases and the excellent RRDtool please see
www.rrdtool.org. The step parameter of the database should be aligned to
your check interval used with nagios.

=item -t|--timeout=seconds

Timeout for socket operations. Default: 10 seconds

=item -v|--verbose

increases verbosity

=item -V|--version

print version an exit

=item -h|--help

print help message and exit

=cut

# -----------------------------------------------

use strict;
use warnings;

use Getopt::Long qw(:config no_ignore_case bundling);
use Pod::Usage;
use IO::Socket::INET;

# -- searching Nagios::Plugin, may be installed with nagios-plugins
use FindBin;
use lib "$FindBin::Bin/../perl/lib";
use Nagios::Plugin;

use vars qw( $HAVERRD );

# -- check if RRDs is available 
# ...yes, I know, I should not use BEGIN with
# ePN, but do you know a better solution?
BEGIN{
   if ( eval "use RRDs" ) {
      $HAVERRD = 0;
      *rrds_create = sub { };
      *rrds_update = sub { };
      *rrds_error = sub { };
      # print STDERR "have no rrd\n";
   } else {
      $HAVERRD = 1;
      *rrds_create = \&RRDs::create;
      *rrds_update = \&RRDs::update;
      *rrds_error = \&RRDs::error;
      # print STDERR "have rrd\n";
   }
}

# -----------------------------------------------
# global vars
# -----------------------------------------------

my $perfdatastring = '';# for performance data
my $ERR;		# RRD error string
my @values;		# array for sensor results
my $value;		# single sensor result

my $np = Nagios::Plugin->new( shortname => "PCMEASURE" );

my %needed_sensors = (  # how many sensors are needed by type
   standard   => 1,
   brightness => 1,
   barometer  => 2,
);

# -----------------------------------------------
# Command line Parameters
# -----------------------------------------------

# -- Vars

my $remote_host	= '';		# server running pcmeasure
my $remote_port	= 4000;		# default tcp port
my $warn_threshold = '~:';	#
my $crit_threshold = '~:';	#
my $sensor_opt	= '';		# i.e. com1.1, lpt2.4
my $sensor_type	= 'standard';	# standard, brightness, barometer
my @sensors;			# split $sensor_opt
my $label 	= 'value'; 	# label for output and performance data
my $format_string = '';		#  formatting text output
my $TIMEOUT     = 10.0;	 	# TIMEOUT for socket operation, no ALARM function
my $verbose    	= 0;		#
my $help	= 0;		# 
my $rrddb;			# rrd database: store values in an round robin
				# archive, if given
my $printversion = 0;		#

# -- -- -- -- -- -- -- -- 
my $version	= '$Revision: 1.1 $ / $Date: 2008-03-08 16:56:45 $ / wob ';
# -- -- -- -- -- -- -- --

# -- GetOpt

GetOptions(
   "H|host=s"		=> \$remote_host,
   "p|port=s"		=> \$remote_port,
   "w|warning=s"	=> \$warn_threshold,
   "c|critical=s"	=> \$crit_threshold,
   "l|label=s"		=> \$label,
   "F|format-string=s"	=> \$format_string,
   "R|rrd-database=s"	=> \$rrddb,
   "S|sensor=s"		=> \$sensor_opt,
   "T|type=s"		=> \$sensor_type,
   "t|timeout=s"	=> \$TIMEOUT,
   "h|help"		=> \$help,
   "V|version"		=> \$printversion,
   "v|verbose+"		=> \$verbose,

   ) or pod2usage( -exitval => UNKNOWN,
   		   -verbose => 0,
   	           -msg     => "\n *** unknown argument found ***" );

# -- help message
pod2usage(-verbose => 2,
	  -exitval => UNKNOWN ,
          -output  => \*STDOUT,
	 ) if ( $help );

# -- version

pod2usage(-msg     => "\n$0 -- version: $version\n",
          -verbose => 99,
          -sections => "NAME|LICENSE",
	  -exitval => UNKNOWN ,
          -output  => \*STDOUT,
	 ) if ( $printversion );

# -- no host specified
pod2usage(-msg     => "\n*** please specify one host or ip ***\n",
          -verbose => 0,
	  -exitval => UNKNOWN ,
	 ) if ( $remote_host eq '' );

# -- no sensor specified
pod2usage(-msg     => "\n*** please specify one sensor ***\n",
          -verbose => 0,
	  -exitval => UNKNOWN ,
	 ) if ( $sensor_opt eq '' );

# -- may be multiple sensors
@sensors = split(',', $sensor_opt);

# -- check sensor type and numbers
if ( !defined($needed_sensors{$sensor_type}) ) {
   pod2usage(-msg     => "\n*** unknown sensor type ***\n",
             -verbose => 0,
	     -exitval => UNKNOWN ,
            );
}
elsif ( $needed_sensors{$sensor_type} != $#sensors + 1 ) {
   pod2usage(-msg     => "\n*** please specify $needed_sensors{$sensor_type}" 
                         . " sensors for sensor type $sensor_type ***\n",
             -verbose => 0,
	     -exitval => UNKNOWN ,
            );
}

# -- formating text output
if ( "$format_string" eq '' ) {
   $format_string = "$label = %.1f";
}

# -- rrd specified, but module RRDs not available
pod2usage(-msg     => "\n*** perl module RRDs is not available, can't use --rrd-database ***\n",
          -verbose => 0,
	  -exitval => UNKNOWN ,
	 ) if ( defined($rrddb) && ! $HAVERRD );

# -----------------------------------------------
# set thresholds
# -----------------------------------------------

# -- thresholds
$np->set_thresholds( 
   warning  => $warn_threshold,
   critical => $crit_threshold,
);

print "DEBUG: warn= $warn_threshold, crit= $crit_threshold\n" if ($verbose > 1);

# -----------------------------------------------
# create/check rrd database file
# -----------------------------------------------

if ( defined($rrddb) ) {
   # -- create database, if not exist
   if ( ! -e $rrddb ) {
	$ERR = create_myrrd($rrddb);
      if ( $ERR ) {
	 $np->nagios_die("can't create RRD database: $ERR");
      }
   }
   # -- check, if database file is writable
   if ( ! -w $rrddb ) {
      $np->nagios_die("RRD database is not writable");
   }
}

# -----------------------------------------------
# socket operation
# -----------------------------------------------

my $socket = IO::Socket::INET->new(PeerAddr => $remote_host,
				   PeerPort => $remote_port,
				   Proto    => "tcp",
				   Type     => SOCK_STREAM,
				   Timeout  => $TIMEOUT,
				  );

if ($@) {
   $np->nagios_die("Can't open Socket to host $remote_host");
}

foreach my $sensor (@sensors) {

   print $socket "pcmeasure.$sensor\r\n";
   my $answer = <$socket>;

   $answer =~ s/[\r][\n]//;

   if ($verbose) {
      print STDERR "$answer\n";
   }

   if ( $answer =~ m/valid=(\d+)/) {
      my $valid = $1;
      if ($valid != 1 ) {
	 $np->nagios_exit(WARNING, "answer not valid: $answer");
      }
   } else {
      $np->nagios_die("no valid tag found: $answer");
   }
      
   if ( $answer =~ m/value=\s*([+-]{0,1}[.\d]+)/) {
      push @values, $1;
   } 
   else {
       $np->nagios_die("unknown answer: $answer");
   }
}

close($socket);

# -----------------------------------------------
# processing results
# -----------------------------------------------

SENSORTYPE: {
   if ("$sensor_type" eq "standard" ) {
      $value = $values[0];
      last SENSORTYPE;
   }
   if ("$sensor_type" eq "brightness" ) {
      $value = $values[0] * 200;
      last SENSORTYPE;
   }
   if ("$sensor_type" eq "barometer" ) {
      $value = ($values[0] + 5.851 - $values[1]) / 0.0054;
      last SENSORTYPE;
   }
}

# -----------------------------------------------
# update RRD 
# -----------------------------------------------

if ( defined($rrddb) ) {
   # -- update database	
   my $string = "N:$value";
   &rrds_update( $rrddb, $string );
   $ERR = &rrds_error();
   if ( $ERR ) { 
      $np->nagios_die("can't update RRD database: $ERR");
   }
}

# -----------------------------------------------
# performance data
# -----------------------------------------------

$np->add_perfdata( label     => lc($label), 
		   value     => $value,
                   threshold => $np->threshold(),
	         );

# -----------------------------------------------
# finish: return to caller
# -----------------------------------------------

my $result = $np->check_threshold($value);

# -- for future use alarm(0);

my $text_output = sprintf "$format_string", $value;

$np->nagios_exit($result, $text_output);


# ===============================================

=head1 RRD DATABASE CREATION

The step of an automatically created rrd database is 120 seconds, the
heartbeat 600 with xfiles factor 0.5. This means: the time resolution is
120 seconds, undependent of the used period for measurement. There must be
at least one valid value within 300 seconds ( xfiles factor 0.5 x
heartbeat 600).

All values for database creation:

 "--step=120",                   # 120 seconds
 "--start=-1d",                  # start one day back
 "DS:value:GAUGE:600:U:U",       # heartbeat
 "RRA:AVERAGE:0.5:1:3600",       # 3600 x 1    x step (120s) = 120h = 5d
 "RRA:AVERAGE:0.5:30:700",       # 700  x 30   x step        = 700h = 29d
 "RRA:AVERAGE:0.5:120:775",      # 775  x 120  x step        = 3100h = 129d
 "RRA:AVERAGE:0.5:1440:797",     # 797  x 1440 x step        = 1594d
 "RRA:MAX:0.5:1:3600",
 "RRA:MAX:0.5:30:700",
 "RRA:MAX:0.5:120:775",
 "RRA:MAX:0.5:1440:797",
 "RRA:MIN:0.5:1:3600",
 "RRA:MIN:0.5:30:700",
 "RRA:MIN:0.5:120:775",
 "RRA:MIN:0.5:1440:797",

To change this values, you can edit this plugin or create the rrd database
manually.

=cut

sub create_myrrd{
   my $file = shift;
   &rrds_create( $file,
        "--step=120",			# 120 seconds
        "--start=-1d",			# start one day back
        "DS:value:GAUGE:600:U:U",	# heartbeat
        "RRA:AVERAGE:0.5:1:3600",	# 3600 x 1    x step (120s) = 120h = 5d
        "RRA:AVERAGE:0.5:30:700",	# 700  x 30   x step        = 700h = 29d
        "RRA:AVERAGE:0.5:120:775",	# 775  x 120  x step        = 3100h = 129d
        "RRA:AVERAGE:0.5:1440:797",	# 797  x 1440 x step        = 1594d
        "RRA:MAX:0.5:1:3600",
        "RRA:MAX:0.5:30:700",
        "RRA:MAX:0.5:120:775",
        "RRA:MAX:0.5:1440:797",
        "RRA:MIN:0.5:1:3600",
        "RRA:MIN:0.5:30:700",
        "RRA:MIN:0.5:120:775",
        "RRA:MIN:0.5:1440:797",
   );
   my $myERR = &rrds_error();
   return $myERR;
};

# ===============================================

# ===============================================

=head1 AUTHOR

wob (at) swobspace (dot) net

=head1 KNOWN ISSUES

No security checks for --format-strings. Be careful!

Support for sensor type = barometer is experimentel

=head1 BUGS

may be

=head1 LICENSE

This program is free software; you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation; either version 2 of the License (and no
later version).

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program; if not, write to the Free Software
Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307 USA

=head1 HISTORY
 
$Log: check_pcmeasure2.pl,v $

Revision 1.1  2008-03-08 16:56:45  wob
Initial version; uses Nagios::Plugin


=cut
