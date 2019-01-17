#!/usr/bin/perl -w
#
# check_wmi_plus.pl - nagios plugin for agentless checking of Windows
#
# Copyright (C) 2011 Matthew Jurgens
# You can email me using: mjurgens (the at goes here) edcint.co.nz
# Download link can be found at http://www.edcint.co.nz
#
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
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.
#

# ----------------------------------------------------------
# ---------------- CHANGE THESE SETTINGS -------------------
# Location of the conf file for the remainder of the settings
# the full path is required since when Nagios runs this whole plugin becomes a subroutine of /usr/sbin/p1.pl
# and when it becomes a subroutine there is no such thing as the current directory or the same directory as this script
# eg $0 becomes /usr/sbin/p1.pl no matter where you install this script
my $conf_file='/etc/check_wmi_plus/check_wmi_plus.conf';

# we are looking for the dir where utils.pm is located. This is normally installed as part of Nagios
use lib "/usr/lib/nagios/plugins";
use lib "/usr/lib64/nagios/plugins"; 

# you shouldn't need to change anything else below this line
# change the settings in the $conf_file itself
# ---------------- END CHANGE THESE SETTINGS ---------------
# ----------------------------------------------------------


#==============================================================================
#================================= DECLARATIONS ===============================
#==============================================================================

our $VERSION=1.64;

# which version of PRO (if used does this require)
our $requires_PRO_VERSION=1.28;

use strict;
use Getopt::Long;
use Scalar::Util qw(looks_like_number reftype);
use Number::Format qw(:subs);
use Data::Dumper;
use Storable;
use Config::IniFiles;
use DateTime;

# command line option declarations
our $opt_auth_file='';
our $opt_Version='';
our $opt_help='';
our $opt_mode='';
our $opt_submode='';
our $opt_username='';
our $opt_password='';
our $opt_show_fields='';
our $opt_wminamespace='root/cimv2'; # this is the default namespace
our $opt_warn=(); # this becomes an array reference
our $opt_critical=(); # this becomes an array reference
our @opt_include_data=(); # this becomes an array reference
our @opt_exclude_data=(); # this becomes an array reference
our @opt_map_exit_status=();
our $debug=0; # default value
our $opt_value='';
our $opt_z='';
our $opt_inihelp='';
our $opt_package='';
our $opt_keep_state=1;
our $opt_keep_state_id='';
our $opt_helper_state_expiry='3600'; # default number of seconds after which helper state results are considered expired
our $opt_keep_state_expiry='3600'; # default number of seconds after which keep state results are considered expired
our $opt_join_state_expiry='3600'; # default number of seconds after which join state results are considered expired
our $opt_texthelp=0;
our $opt_command_examples='';
our $opt_ignore_versions='';
our $opt_ignore_auth_file_warnings='';
our $opt_installmodule_dir='';
our $opt_collect_usage='';
our $opt_show_usage='';
our $opt_use_cached_wmic_response='';
our $opt_log_usage_show='';
our $opt_log_usage_switch='';
our $opt_log_usage_suffix='';
our $opt_log_usage_keep='';
our $test_wmic_file_base='';
our $test_number=1;
our $test_generate='';
our $test_run='';
our $test_ignorejoinstatefiles='';
our $test_ignorehelperstatefiles='';
our $test_ignorekeepstatefiles='';
our $opt_filter_ini_rows_by_status='';
our $opt_disable_pro='';


# they all start with _ since later they are copied into the data array/hash and this reduces the chance they clash
# then we have consistent usage throughout
my %the_original_arguments=(); # used to store the original user specified command line arguments  - sometimes we change the arguments
our %the_arguments = (
   _mode  => '',     # just for duplicate storage of the mode (Since we actually modify the actual mode variable for ini files)
   _submode => '',   # just for duplicate storage of the submode
   _arg1  => '',
   _arg2  => '',
   _arg3  => '',
   _arg4  => undef, # we need this undef for checkeventlog so we know if something was specified or not - take care with other checks that use this
   _arg5  => undef,
   _bytefactor  => '',
   _delay       => '',
   _host        => '',
   _nodatamode  => '',
   _nodataexit  => '',
   _nodatastring=> "WMI Query returned no data. The item you were looking for may NOT exist or the software that creates the WMI Class may not be running, or all data has been excluded.\n",
   _timeout     => '',
   _truncate_output  => 8192,
);

# arrays/hashes where we will store information about warn/critical specs/checks
my %warn_perf_specs_parsed;      # list of parsed warn specs - a hash
my %critical_perf_specs_parsed;  # list of parsed critical specs - a hash
my @warn_spec_result_list;        # list of warn spec results
my @critical_spec_result_list;    # list of critical spec results

our $wmic_delimiter='|';
our $wmic_split_delimiter='\|';

# key is the full name of the Module Version variable
# value is the minimum module version we'd like to use
my %good_module_versions=(
   ']',5.01,
   'DateTime::VERSION',0.66,
   'Getopt::Long::VERSION',2.38,
   'Scalar::Util::VERSION',1.22,
   'Number::Format::VERSION',1.73,
   'Data::Dumper::VERSION',2.125,
   'Config::IniFiles::VERSION',2.58,
   'Storable::VERSION',2.22
   );

my %displaywhatwhen_mode_list=();

# define some "string" constants
our %string_constant=(
   ok       => 0,
   warning  => 1,
   critical => 2,
   unknown  => 3,

   CRITERIA => 1,
   EVENT    => 2,

);

# for mode=checkeventlog
our %event_modes=(
   ANY         => 1,
   INCLUDEALL  => 2,
);

our %event_counts=(
   CRITERIA => 1,
   EVENT    => 2,
);
  


#==============================================================================
#=================================== CONFIG ===================================
#==============================================================================

my $PROGNAME="check_wmi_plus";

my $default_bytefactor=1024;

# work out the conf file dir
our $conf_file_dir=$conf_file;
# remove the filename from the end of the conf_file to get the dir
$conf_file_dir=~s/^(.*)\/(.*?)$/$1/; 

# ================================== DEFAULT CONFIGURATION ================================
# override these settings using the $conf_file (which is defined right near the top of this script)

# ---------------------- DEFAULT FILE LOCATIONS -------------------------
# Developed and tested with everything installed in /opt/nagios/bin/plugins

# You might not even use this variable if you have different locations for everything
our $base_dir='/opt/nagios/bin/plugins';

# This is the full path location of the wmic command
# - standard value "/usr/bin/wmic" since this is where it goes when it is compiled
our $wmic_command="/usr/bin/wmic"; # CHANGE THIS IF NEEDED

# set the location of the ini file. Set to '' if not using it or specify using the --inifile parameter
# set this to something else if you want
# - standard value "$conf_file_dir/check_wmi_plus.ini"
our $wmi_ini_file='';

# set the location of the ini dir. Set to '' if not using it or specify using the --inidir parameter
# set this to something else if you want
# - standard value "$conf_file_dir/check_wmi_plus.d"
our $wmi_ini_dir="$conf_file_dir/check_wmi_plus.d";

# set the location of temporary directory - used for keep state option
# if running on Windows then $ENV{'TMP'} will be set and hence used
our $tmp_dir=$ENV{"TMP"} || '/tmp';

# this script helps with making the manpage help. By default it is in the same directory as the plugin itself
our $make_manpage_script="$base_dir/check_wmi_plus.makeman.sh";

# this is the directory where the manpage is stored when created, defaults to the same directory as the ini files
our $manpage_dir="$wmi_ini_dir";

# PRO only: set the location of where the check_wmi_plus will store some persistent data
# - standard value "$conf_file_dir/check_wmi_plus.data"
our $wmi_data_dir="$conf_file_dir/check_wmi_plus.data";

# PRO only: this is the file where the usage stats are stored (if using it via $collect_usage_info or --icollectusage)
our $usage_db_file="$wmi_data_dir/check_wmi_plus.usagedb";

# PRO only: this is the file where the compiled ini files are stored
our $compiled_ini_file="$wmi_data_dir/check_wmi_plus.compiledini";


# ---------------------- OTHER CONFIGURATION -------------------------

# Disable the check of Perl Module versions
# The module versions are checked because the are often the cause of the plugin not working correctly
# If you want support you will need to reproduce the fault with the supported versions of the modules ie enable this check
# Set to 1 to ignore the version check, Set to 0 to perform the check
# Setting this to 1 has the same effect as the command line option  --IgnoreMyOutDatedPerlModuleVersions
# Setting either this to 1 or the command line option will disable the check
our $ignore_my_outdated_perl_module_versions=0;

# force the use of the wmic command line binary. Set to 1 to force
# this is used if you have the wmiclient library installed but want to use the command line version
our $force_wmic_command=0;

# used cached wmic responses
# you don't really want this on unless you want to totally bypass wmic
# some checks will totally fail with this set
# all your check response will be inaccurate
our $use_cached_wmic_responses=0;

# extra wmic args
# specify standard additional arguments to pass directly to the wmic command line for ALL invocations of wmic
# Note that the command line parameter --extrawmicarg is also available if you need this on a case by case basis
# This is an array so you need to put each argument into a separate array index
# eg @opt_extra_wmic_args=( "argument1=value1", "argument2=value2" );
# should be set to @opt_extra_wmic_args=() if not used
# extra wmic arguments specified on the command line are added to the ones specified here
our @opt_extra_wmic_args=( ); # extra arguments to pass to wmic

# force reading of the ini files - you may want to do this if you are doing a non-ini file check and you are using variables defined in an ini file
# only use this if you really needed it since it makes each invocation of the plugin a lot slower
our $force_ini_open=0;

# PRO Only:
# collect various usage info and store it in $usage_db_file for later analysis
# also available by using the --icollectusage command line parameter
# requires additional perl modules if invoked
our $collect_usage_info=1;

# PRO Only:
# show various usage info at end of plugin output (more info than is collected)
# also available by using the --ishowusage command line parameter
# requires additional perl modules if invoked
our $show_usage_info=1;

# Pro Only:
# Generate a Nagios error if there is a problem updating the usage stats
# If set to 0, errors updating usage stats will be shown in the plugin output but will not impact the Nagios alert type
our $generate_nagios_error_for_usage_stats_problem=1;

# Pro Only:
# use compiled ini files for additional speed
our $use_compiled_ini_files=1;

# ============================= END OF DEFAULT CONFIGURATION ================================

our $host_os='';
eval {
   # get the Config module if it is available (so we can get the ostype)
   require Config;
   $host_os = $Config::Config{'osname'};
};

# try and open the conf file to get any user set variables
# if it does not work, just ignore and carry on
if (-f "$conf_file") {
   if (!defined(do "$conf_file")) {
      die "Configuration File Error with $conf_file (mostly likely a syntax error)";
   }
}

# check the base_dir
# if it does not work die
if (! -d "$base_dir") {
      die "The variable '\$base_dir' in $conf_file is not set to a valid directory";
}

# do this use here since the user might have changed the directory we in the conf file
use utils qw ($TIMEOUT %ERRORS &print_revision &support);

# list all valid modes with dedicated subroutines here
# all the modes that can take a critical/warning specification set to value of 1
my %mode_list = ( 
   checkcpu             => 1,
   checkcpuq            => 1,
   checkdnsrecords      => 1,
   checkdrivesize       => 1,
   checkeventlog        => 1,
   checkfileage         => 1,
   checkfilesize        => 1,
   checkfoldersize      => 1,
   checkgeneric         => 1,
   checkgroup           => 1,
   checkgroupuser       => 1,
   checklogon           => 1,
   checkmem             => 1,
   checknetwork         => 1,
   checkpage            => 1,
   checkprintjob        => 1,
   checkprocess         => 1,
   checkquota           => 1,
   checkservice         => 1,
   checkshare           => 1,
   checksmart           => 1,
   checkstartupcommand  => 1,
   checktime            => 1,
   checkuptime          => 1,
   checkuseraccount     => 1,
   checkvolsize         => 1,
   checkwsusserver      => 0,
);

# multipliers are calculated as BYTEFACTOR^mulitpler eg m = x * 1000^2 or x * 1024^2
my %multipliers=(
   k  => 1,
   m  => 2,
   g  => 3,
   t  => 4,
   p  => 5,
   e  => 6,
);

my %time_multipliers=(
   sec   => 1,
   min   => 60,
   hr    => 3600,
   day   => 86400,
   wk    => 604800,
   mth   => 2629800,  # this one is not exact. We assume that there are 365.25/12=30.4375 days in a month on average
   yr    => 31557600, # this one is also approximate. We assume that there are 365.25 days per year
);

my %include_mode_text = (
   0  => 'Exclude',
   1  => 'Include',
);
# this regex finds if a multiplier is valid - just list all multiplier options in here
my $multiplier_regex="[KMGTPE|min|hr|day|wk|mth|yr]";

# defined smart attribute code to names mappings - these are the SMART attributes we extract in checksmart
my %smartattributes=(
   5  => 'Reallocated_Sector_Count',
   9  => 'Power_On_Hours',
   12 => 'Power_Cycle_Count',
   194=> 'Temperature',
   197=> 'Current_Pending_Sector',
   198=> 'Offline_Uncorrectable',
);

# this hash contains lists of the fields that can be used in the warning/critical specs for specific modes
our %valid_test_fields = (
   # key name is the name of the mode
   # value is an array of fields names to check against
   # the first one in the list is the default if none is specified in a warn/crit specification
   # you should always specify at least one per mode that uses warning/critical checking so that it knows what to check against
   checkcpu          => [ qw(_AvgCPU) ],
   checkcpuq         => [ qw(_AvgCPUQLen) ],
   checkdrivesize    => [ qw(_Used% _UsedSpace _UsedGB _Free% FreeSpace_FreeGB) ],
   checkeventlog     => [ qw(_ItemCount) ],
   checkfileage      => [ qw(_FileAge) ],
   checkfilesize     => [ qw(FileSize _ItemCount) ],
   checkfoldersize   => [ qw(_FolderSize _ItemCount) ],
   checkgeneric      => [ qw(FileControlBytesPersec FileControlOperationsPersec FileDataOperationsPersec FileReadBytesPersec FileReadOperationsPersec FileWriteBytesPersec FileWriteOperationsPersec) ],
   checkgroup        => [ qw(_ItemCount _ItemChange LocalAccount Status) ],
   checkgroupuser    => [ qw(_ItemCount _ItemChange) ],
   checklogon        => [ qw(_ItemCount _ItemChange) ],
   checkmem          => [ qw(_MemUsed% _MemFree% _MemUsed _MemFree _MemTotal) ],
   checknetwork      => [ qw(CurrentBandwidth _PacketsSentPersec _PacketsReceivedPersec OutputQueueLength PacketsReceivedErrors _BytesSentPersec _BytesReceivedPersec _SendBytesUtilisation _ReceiveBytesUtilisation) ],
   checkpage         => [ qw(_Used% _Used _Free _Free% _PeakUsed% _PeakUsed _PeakFree _PeakFree% _Total) ], 
   checkprintjob     => [ qw(_ItemCount _ItemChange Color Status TotalPages Owner Document DataType) ],
   checkprocess      => [ qw(_ItemCount _NumExcluded) ],
   checkquota        => [ qw(_ItemCount _ItemChange DiskSpaceUsed Limit Status WarningLimit) ],
   checkservice      => [ qw(_NumBad _NumGood _NumExcluded _Total) ],
   checkshare        => [ qw(_ItemCount _ItemChange) ],
   checksmart        => [ qw(_DiskFailing _ItemCount Temperature) ],
   checkstartupcommand=>[ qw(_ItemCount _ItemChange Command Description Name User) ],
   checktime         => [ qw(_DiffSec _CWPSec _WindowsSec) ],
   checkuptime       => [ qw(_UptimeSec) ],
   checkuseraccount  => [ qw(_ItemCount _ItemChange Disabled LocalAccount Lockout PasswordChangeable PasswordExpires PasswordRequired SIDType Status) ],
   checkvolsize      => [ qw(_Used% _UsedSpace _UsedGB _Free% FreeSpace_FreeGB) ],

);

# this hash contains lists of the fields that are displayed for specific modes before any per row display starts
# documentation on format for this is the same as for %display_fields
our %pre_display_fields = (
   checknetwork      => [ '_DisplayMsg||~|~| - ||', '_NumInterfaces||Number of Interfaces||~||. Interface Details - ' ],
   checkpage         => [ '_OverallResult||Overall Status - |~|: ||. Individual Page Files Detail' ],
   checksmart        => [ '_DisplayMsg||Overall Status - |~| - ||', '_Total| Disks(s)| Found |~|||', '_NumGood| OK|~|~| and ||', '_NumBad| failing |~|~|~||' ],
   );

# this hash contains lists of the fields that are displayed for specific modes
our %display_fields = (
   # key name is the name of the mode
   # value is an array of fields names to display
   # the value can be in 2 formats - 
   # 1) FIELD (where we just display this field like FIELD=xx,
   # 2) FIELD|UNITS (where we just display this field like FIELD=xxUNITS,
   # 3) FIELD|UNITS|DISPLAY|SEP|DELIM|START|END
   # where we display this FIELD like STARTDISPLAYSEPxxUNITSENDDELIM
   # the default DELIM is comma space, if DELIM is set to ~ then none will be used
   # the default SEP is =, if SEP is set to ~ then none will be used
   # DISPLAY normally shows FIELD or whatever you specify as DISPLAY. Set DISPLAY to ~ to show nothing.
   # if units is prefixed with # then we use a function to convert it to a scaled based figure using prefixes like K, M, G etc - the calculation is influenced by the BYTEFACTOR setting
   # In DISPLAY/START/END anything enclosed in {} will be substituted by the value of that item of that name eg {DeviceID} will replace by the value contained in DeviceID eg C:
   # eg BytesSentPersec will be shown as BytesSentPersec=XX, 
   # eg BytesSentPersec|BYTES will be shown as BytesSentPersec=XXBytes, 
   # eg _Used%|%|.|.||(|) will be shown as (45.2%)
   # I was going to use qw() but it makes it way harder to read. You could still use it for the most basic format
   checkcpu          => [ '_DisplayMsg||~|~| - ||', '_AvgCPU|%|Average CPU Utilisation| |~||' ],
   checkcpuq         => [ '_DisplayMsg||~|~| - ||', '_AvgCPUQLen||Average CPU Queue Length| | ||', '_arg1| points|~|~|~|(| with', '_delay| sec delay|~| | ||', '_CPUQPoints||~|~|~|gives values: |)' ],
   checkdnsrecords   => [ '_DisplayMsg||~|~| - ||', '_DNSDetails||~|~|~||. ', '_WMIDetails||~|~|~||. ' ],
   checkdrivesize    => [ '_DisplayMsg||~|~| - ||', 'DiskDisplayName||~|~| ||', 'Size|#B|Total||||', '_UsedSpace|#B|Used|| ||', '_Used%|%|~|~||(|)', 'FreeSpace|#B|Free|| ||', '_Free%|%|~|~||(|)' ],
   checkeventlog     => [ '_DisplayMsg||~|~| - ||', '_ItemCount| event(s)|~|~| ||', '_SeverityType||~|~||of Severity Level: "|"', '_arg3| hours|~|~|~|were recorded in the last |', '_arg1||~|~|~| from the | Event Log.', "_EventList||~|~|~||" ],
   checkfileage      => [ '_DisplayMsg||~|~| - ||', '_arg1||Age of File| |~|| is ', '_NicelyFormattedFileAge||~|~|~|| or ', '_DisplayFileAge||~|~|~||', '_PerfDataUnit||~|~|||(s).' ], 
   checkfilesize     => [ '_DisplayMsg||~|~| - ||', '_arg1||File| |~|| is ', 'FileSize|#B|~|~|. ||', '_ItemCount| instance(s)|Found| |.||' ], 
   checkfoldersize   => [ '_DisplayMsg||~|~| - ||', '_arg1||Folder| |~|| is ', '_FolderSize|#B|~|~|. ||', '_ItemCount| files(s)|Found| |.||', '_FileList||~|~|~||' ], 
   checkgeneric      => [ '_DisplayMsg||~|~| - ||', 'FileControlBytesPersec', 'FileControlOperationsPersec', 'FileDataOperationsPersec', 'FileReadBytesPersec', 'FileReadOperationsPersec', 'FileWriteBytesPersec', 'FileWriteOperationsPersec' ], 
   checkgroup        => [ '_DisplayMsg||~|~| - ||', '_ItemCount| group(s). |Found |~|~||', '_ItemChange||Groups changed since last check=|~|~||', '_ItemList||~|~|~||' ],
   checkgroupuser    => [ '_DisplayMsg||~|~| - ||', '_ItemCount| group user(s). |Found |~|~||', '_ItemChange||Group users changed since last check=|~|~||', '_ItemList||~|~|~||' ],
   checklogon        => [ '_DisplayMsg||~|~| - ||', '_ItemCount| logon(s). |Found |~|~||', '_ItemChange||Logons changed since last check=|~|~||', '_ItemList||~|~|~||' ],
   checkmem          => [ '_DisplayMsg||~|~| - ||', 'MemType||~|~|~||: ', '_MemTotal|#B|Total|: | - ||', '_MemUsed|#B|Used|: | ||', '_MemUsed%|%|~|~| - |(|)', '_MemFree|#B|Free|: | ||', '_MemFree%|%|~|~||(|)' ], 
   checknetwork      => [ '_DisplayMsg||~|~| - ||', '_DisplayName||Interface:|~|||', 'IPAddress||IP Address:|~|||', 'MACAddress||MAC Address |~|||', 'CurrentBandwidth|#bit/s|Speed:|~|||', 'DHCPEnabled', '_BytesSentPersec|#B/sec|Byte Send Rate|| (||', '_SendBytesUtilisation|%|Utilisation||), ||', '_BytesReceivedPersec|#B/sec|Byte Receive Rate||(||', '_ReceiveBytesUtilisation|%|Utilisation||) ||', '_PacketsSentPersec|#packet/sec|Packet Send Rate||||', '_PacketsReceivedPersec|#packet/sec|Packet Receive Rate||||', 'OutputQueueLength||Output Queue Length||||', 'PacketsReceivedErrors||Packets Received Errors||||' ],
   checkquota        => [ '_DisplayMsg||~|~| - ||', '_ItemCount| quota(s). |Found |~|~||', '_ItemChange||Quotas changed since last check=|~|~||', '_ItemList||~|~|~||' ],
   checkpage         => [ '_DisplayMsg||~|~| - ||', 'Name||~|~| ||', '_Total|#B|Total|: | - ||', '_Used|#B|Used|: | ||', '_Used%|%|~|~| - |(|)', '_Free|#B|Free|: | ||', '_Free%|%|~|~||(|)', '_PeakUsed|#B|Peak Used|: | ||', '_PeakUsed%|%|~|~| - |(|)', '_PeakFree|#B|Peak Free|: | ||', '_PeakFree%|%|~|~||(|)' ], 
   checkprintjob     => [ '_DisplayMsg||~|~| - ||', '_ItemCount| print jobs(s). |Found |~|~||', '_ItemChange||Print Job Queue changed since last check=|~|~||', '_ItemList||~|~|~||' ],
   checkprocess      => [ '_DisplayMsg||~|~| - ||', '_ItemCount| Instance(s)|Found |~|~|| of "{_arg1}" running ', '_NumExcluded| excluded|~|~|~|(|). ', 'ProcessList||~|~|~||' ],
   checkservice      => [ '_DisplayMsg||~|~| - ||', '_Total| Services(s)|Found |~|||', '_NumGood| OK|~|~| and ||', '_NumBad| with problems |~|~|~||', '_NumExcluded| excluded|~|~|~|(|). ', '_ServiceList||~|~|~||' ],
   checkshare        => [ '_DisplayMsg||~|~| - ||', '_ItemCount| shares(s). |Found |~|~||', '_ItemChange||Shares changed since last check=|~|~||', '_ItemList||~|~|~||' ],
   checksmart        => [ '_DisplayMsg||~|~| - ||', '_PhysicalDeviceID||Dev#|~|||', 'Model||~|~|||', 'SerialNumber||Serial#|~|||', 'PredictFailure', 'Temperature' ],
   checkstartupcommand=>[ '_DisplayMsg||~|~| - ||', '_ItemCount| startup command(s). |Found |~|~||', '_ItemChange||Startup Commands changed since last check=|~|~||', '_ItemList||~|~|~||' ],
   checktime         => [ '_DisplayMsg||~|~| - ||', '_DiffSec| seconds|Time Difference is |~|||', '_WindowsTime||Time from Windows is |~|||(UTC)', '_CWPTime||Check WMI Plus time is |~|||(UTC)' ],
   checkuptime       => [ '_DisplayMsg||~|~| - ||', '_DisplayTime||System Uptime is |~|.||' ],
   checkuseraccount  => [ '_DisplayMsg||~|~| - ||', '_ItemCount| user account(s). |Found |~|~||', '_ItemChange||User Accounts changed since last check=|~|~||', '_ItemList||~|~|~||' ],
   checkvolsize      => [ '_DisplayMsg||~|~| - ||', 'VolumeDisplayName||~|~| ||', 'Capacity|#B|Total||||', '_UsedSpace|#B|Used|| ||', '_Used%|%|~|~||(|)', 'FreeSpace|#B|Free|| ||', '_Free%|%|~|~||(|)' ],

);

# this hash contains lists of the fields that are used as performance data for specific modes
our %performance_data_fields = (
   # key name is the name of the mode
   # value is an array of fields names to display
   # the value can be in 2 formats - 
   # 1) FIELD
   # 2) FIELD|UNITS
   # 3) FIELD|UNITS|DISPLAY
   # In DISPLAY/UNITS anything enclosed in {} will be substituted by the value of that item of that name eg {DeviceID} will replace by the value contained in DeviceID eg C:
   checkcpu          => [ '_AvgCPU|%|Avg CPU Utilisation' ],
   checkcpuq         => [ '_AvgCPUQLen||Avg CPU Queue Length' ],
   checkdrivesize    => [ '_UsedSpace|B|{DiskDisplayName} Space', '_Used%|%|{DiskDisplayName} Utilisation', 'Size|B|{DiskDisplayName} Size' ],
   checkeventlog     => [ '_ItemCount||Event Count' ],
   checkfileage      => [ '_DisplayFileAge|{_PerfDataUnit}|{_arg1} Age' ],
   checkfilesize     => [ 'FileSize|B|{_arg1} Size', '_ItemCount||File Count' ],
   checkfoldersize   => [ '_FolderSize|B|{_arg1} Size', '_ItemCount||File Count' ],
   checkgeneric      => [ 'FileControlBytesPersec', 'FileControlOperationsPersec', 'FileDataOperationsPersec', 'FileReadBytesPersec', 'FileReadOperationsPersec', 'FileWriteBytesPersec', 'FileWriteOperationsPersec' ],
   checkgroup        => [ '_ItemCount||Group Count' ],
   checkgroupuser    => [ '_ItemCount||Group User Count' ],
   checklogon        => [ '_ItemCount||Logon Count' ],
   checkmem          => [ '_MemUsed|B|{MemType} Used', '_MemUsed%|%|{MemType} Utilisation' ], 
   checknetwork      => [ '_BytesSentPersec||{_DisplayName} BytesSentPersec', '_SendBytesUtilisation|%|{_DisplayName} Send Utilisation', '_BytesReceivedPersec||{_DisplayName} BytesReceivedPersec', '_ReceiveBytesUtilisation|%|{_DisplayName} Receive Utilisation', '_PacketsSentPersec||{_DisplayName} PacketsSentPersec', '_PacketsReceivedPersec||{_DisplayName} PacketsReceivedPersec', 'OutputQueueLength||{_DisplayName} OutputQueueLength', 'PacketsReceivedErrors||{_DisplayName} PacketsReceivedErrors' ],
   checkpage         => [ '_Total|B|{Name} Page File Size', '_Used|B|{Name} Used', '_Used%|%|{Name} Utilisation', '_PeakUsed|B|{Name} Peak Used', '_PeakUsed%|%|{Name} Peak Utilisation' ], 
   checkprintjob     => [ '_ItemCount||Print Job Count' ],
   checkprocess      => [ '_ItemCount||Process Count', '_NumExcluded||Excluded Process Count' ],
   checkquota        => [ '_ItemCount||Share Count',  ],
   checkservice      => [ '_Total||Total Service Count', '_NumGood||Service Count OK State', '_NumBad||Service Count Problem State', '_NumExcluded||Excluded Service Count' ],
   checkshare        => [ '_ItemCount||Share Count' ],
   checksmart        => [ 'Reallocated_Sector_Count||{_DiskDisplayName}_Reallocated_Sector_Count','Power_On_Hours||{_DiskDisplayName}_Power_On_Hours','Power_Cycle_Count||{_DiskDisplayName}_Power_Cycle_Count','Temperature||{_DiskDisplayName}_Temperature','Current_Pending_Sector||{_DiskDisplayName}_Current_Pending_Sector','Offline_Uncorrectable||{_DiskDisplayName}_Offline_Uncorrectable' ],
   checkstartupcommand=>[ '_ItemCount||Startup Command Count' ],
   checktime         => [ '_DiffSec' ],
   checkuptime       => [ '_UptimeSec|s|Uptime Seconds', '_UptimeMin|min|Uptime Minutes', '_UptimeHours|hours|Uptime Hours', '_UptimeDays|days|Uptime Days' ],
   checkuseraccount  => [ '_ItemCount||User Account Count' ],
   checkvolsize      => [ '_UsedSpace|B|{VolumeDisplayName} Space', '_Used%|%|{VolumeDisplayName} Utilisation' ],

);

# a couple of defaults we use for ini files
my $default_inifile_number_wmi_samples=1;
my $default_inifile_delay=5;

# some default help text
our $default_help_text_delay="DELAY  (optional) specifies the number of seconds over which the utilisation is calculated. The longer you can make this without timing out, the more accurate it will be. If specifying longer values. You may also need to use the -t parameter to set a longer script timeout. Only valid if also specifying --nokeepstate ie you are not using the state keeping feature. We recommend that you do keep state and hence do not use --nokeepstate.";

# name of command example ini file - not named as .ini so that it does not get read as part of reading other ini files
# assumed to be in the same dir as the other ini files
my %command_examples_ini_file=(
   1  => 'CommandExamples.chtml',
   2  => 'WarnCritExamples.chtml',
   );

# counters for the number of wmic calls via specific methods
our $wmic_calls=0;
our $wmic_library_calls=0;

# and for the testing modes we also need a counter to just count the number of calls we make to get wmi data
our $global_wmic_call_counter=0;

our $ini_based_check=0;

our $final_exit_code='';

our $plugin_output='';

# PRO only: this is the file where we control the usage file currently written to 
our $current_usage_db_suffix_file="$wmi_data_dir/check_wmi_plus.usagedb.suffix";

# Pro flags for final decisions on usage stats
our $i_will_show_usage_stats=0;
our $i_will_collect_usage_info=0;

# list of static ini variables
our %ini_static_variables=();

# disable the use of static variables
my $opt_disable_static_variables=0;

# flag to tell us if we have opened the ini files already
my $ini_files_already_opened=0;

# name of the keep state file
our $keep_state_file='';

#==============================================================================
#================================== PARAMETERS ================================
#==============================================================================

my @saved_ARGV=@ARGV;

# if the user is using a DOS type file for their nagios command/service definitions then we may see a CR character at the end of the command line
# remove it by doing a regex on the last character of the last parameter (if it is set)
if ($ARGV[$#ARGV]) {
   $ARGV[$#ARGV]=~s/\r$//;
}

if ($host_os =~ m/win32$/i) {
   # if running on Windows we have to remove any ' from the start and end of all command line arguments
   # For windows, the ' is not used to delimit a string, the " is used instead.
   for (my $i=0;$i<=$#ARGV;$i++) {
      $ARGV[$i] =~s/^\'(.*)\'$/$1/;
   }
}

Getopt::Long::Configure('no_ignore_case');
GetOptions(
   "Authenticationfile=s"           => \$opt_auth_file,
   "arguments=s"                    => \$the_arguments{'_arg1'},
   "bytefactor=s"                   => \$the_arguments{'_bytefactor'},
   "Convertslash"                   => \$the_arguments{'_convertslash'},
   "critical=s@"                    => \$opt_critical,
   "debug+"                         => \$debug,
   "excludedata=s@"                 => \@opt_exclude_data,
   "extrawmicargs=s@"               => \@opt_extra_wmic_args,
   "fieldshow"                      => \$opt_show_fields,
   "filterinirowsbystatus=s"        => \$opt_filter_ini_rows_by_status,
   "forceiniopen"                   => \$force_ini_open,
   "forcewmiccommand"               => \$force_wmic_command,
   "forcetruncateoutput=s"          => \$the_arguments{'_truncate_output'},
   "help"                           => \$opt_help,
   "helperexpiry=s"                 => \$opt_helper_state_expiry,
   "Hostname=s"                     => \$the_arguments{'_host'},
   "icollectusage!"                 => \$opt_collect_usage,
   "iexamples=s"                    => \$opt_command_examples,
   "IgnoreMyOutDatedPerlModuleVersions"
                                    => \$opt_ignore_versions,
   "IgnoreAuthFileWarnings"         => \$opt_ignore_auth_file_warnings,
   "includedata=s@"                 => \@opt_include_data,
   "idisablepro"                    => \$opt_disable_pro,
   "inidir=s"                       => \$wmi_ini_dir,
   "inifile=s"                      => \$wmi_ini_file,
   "inihelp"                        => \$opt_inihelp,
   "installmoduledir"               => \$opt_installmodule_dir,
   "ipackage"                       => \$opt_package,
   "itexthelp"                      => \$opt_texthelp,
   "ishowusage!"                    => \$opt_show_usage,
   "iusecachewmicresponse"          => \$opt_use_cached_wmic_response,
   "itestwmicfilebase=s"            => \$test_wmic_file_base,
   "itestnumber=s"                  => \$test_number,
   "itestgenerate"                  => \$test_generate,
   "itestrun"                       => \$test_run,
   "itestignorehelperstatefiles"    => \$test_ignorehelperstatefiles,
   "itestignorejoinstatefiles"      => \$test_ignorejoinstatefiles,
   "itestignorekeepstatefiles"      => \$test_ignorekeepstatefiles,
   "joinexpiry=s"                   => \$opt_join_state_expiry,
   "keepexpiry=s"                   => \$opt_keep_state_expiry,
   "keepid=s"                       => \$opt_keep_state_id,
   "keepstate!"                     => \$opt_keep_state,
   "logkeep"                        => \$opt_log_usage_keep,
   "logshow"                        => \$opt_log_usage_show,
   "logsuffix=s"                    => \$opt_log_usage_suffix,
   "logswitch"                      => \$opt_log_usage_switch,
   "Mapexitstatus=s@"               => \@opt_map_exit_status,
   "mode=s"                         => \$opt_mode,
   "namespace=s"                    => \$opt_wminamespace,
   "nodataexit=s"                   => \$the_arguments{'_nodataexit'},
   "nodatamode"                     => \$the_arguments{'_nodatamode'},
   "nodatastring=s"                 => \$the_arguments{'_nodatastring'},
   "otheraguments=s"                => \$the_arguments{'_arg2'},
   "password=s"                     => \$opt_password,
   "submode=s"                      => \$opt_submode,
   "timeout=i"                      => \$the_arguments{'_timeout'},
   "username=s"                     => \$opt_username,
   "value=s"                        => \$opt_value,
   "variablesdisabled"              => \$opt_disable_static_variables,
   "version"                        => \$opt_Version,
   "warning=s@"                     => \$opt_warn,
   "ydelay=s"                       => \$the_arguments{'_delay'},
   "z"                              => \$opt_z,
   "3arg=s"                         => \$the_arguments{'_arg3'},
   "4arg=s"                         => \$the_arguments{'_arg4'},
   "5arg=s"                         => \$the_arguments{'_arg5'},
   );                               

if ($test_run) {
   # if both options supplied, ignore generate
   $test_generate=0;
}

# see if the check_wmi_plus_lib module is available
our $use_wmilib=0;

# to see if the pro library is being used
our $use_pro_library=0;

if (-f "$base_dir/check_wmi_plus_pro.pl") {
   if (do "$base_dir/check_wmi_plus_pro.pl") {
      if ($opt_disable_pro) {
         $debug && print "Pro Library is present - but disabled by command line option\n";
      } else {
         $debug && print "Pro Library is present\n";
         init_pro_module();
      }
   } else {
      print "Pro Library exists but does not compile: $@\n";
      exit 1;
   }
}

if ($opt_installmodule_dir) {
   # look for a nagios looking path in the @INC
   # if there is one, link the perl module to that dir
   # if not tell the user to pick another one themselves
   my $install_dir='';
   foreach my $inc_path (@INC) {
      if ($inc_path=~/nagios|icinga/i) {
         $install_dir=$inc_path;
         last;
      }
   }
   if ($install_dir) {
      print "Linking the Pro Library to $install_dir\n";
      `ln -s "$wmi_ini_dir/check_wmi_plus_pro.pl" "$install_dir"`;
      # check its ok
      if ( ! -l "$install_dir/check_wmi_plus_pro.pl") {
         print "Could not successfully link the Pro Library!\n";
         $install_dir='';
      }
   }
   if (! $install_dir) {
      print "Could not automatically find a suitable directory to install the module to.\nCopy or link the Pro Library to one of the following directories:\n" . join(", ",@INC);
   }
   exit 1;
}

if ($opt_log_usage_switch && $use_pro_library) {
   switch_current_usage_db();
   exit;
}
if ($opt_log_usage_show && $use_pro_library) {
   if ($i_will_collect_usage_info) {
      my ($current_usage_db_file,$suffix)=get_current_usage_db_file();
      print "Current Usage DB File:$current_usage_db_file\n";
   } else {
      print "Collection of Usage Stats is not currently enabled.\n";
   }
   exit;
}

# check module versions as they very often cause problems if older than developed with
# unless ignored by command line option
if ($opt_ignore_versions || $ignore_my_outdated_perl_module_versions) {
   # the user has to configure this so they get warned at least once if it is a problem
   # ignore perl module version checks
} else {
   # check the versions
   my $versions_ok=check_module_versions(0);
   if (!$versions_ok) {
      finish_program($ERRORS{'UNKNOWN'});
   }
}

if ($debug || $test_generate) {
   my $command_line=join(' ',@saved_ARGV);

   if ($test_generate) {
      my $test_commandline=$command_line;
      # remove some specific --itest parameters
      $test_commandline=~s/--itestg\w*//g;
      $test_commandline=~s/--itestn\w*[= ]*\d+//g;
      print "\n# ---------------------------------------------------------------------------------------------\n[" . int(rand()*10000000) . "]\ndescription=\ncmd=$0 $test_commandline\n";
   } else {

      if (! $opt_z) {
         # try and mask any user/password
         $command_line=~s/-u\s*(\S*?)\s/-u USER /;
         $command_line=~s/-p\s*(\S*?)\s/-p PASS /;
      }
      print "Command Line (v$VERSION): $0 $command_line\n";
      print "Base Dir: $base_dir\n";
      print "Conf File Dir: $conf_file_dir\n";
      print "Loaded Conf File $conf_file\n";
      print "WMI Ini Dir: $wmi_ini_dir\n";
         
      if ($debug>=2) {
         no warnings;
         # get some info about the system
         $wmic_delimiter='!';
         $wmic_split_delimiter='!';
         print "======================================== SYSTEM INFO =====================================================\n";
         print "--------------------- Module Versions ---------------------\n";
         check_module_versions(1);
         print "Net::DNS - $Net::DNS::VERSION\n";
         print "--------------------- Environment ---------------------\n";
         print "ENV=" . Dumper(\%ENV);
         print "--------------------- Computer System ---------------------\n";
         get_wmi_data(1,'',"SELECT * FROM Win32_ComputerSystem",
         '','',my $dummy1,\$the_arguments{'_delay'},undef,0);
         print "--------------------- Operating System ---------------------\n";
         get_wmi_data(1,'',"SELECT * FROM Win32_OperatingSystem",
         '','',my $dummy2,\$the_arguments{'_delay'},undef,0);
         $wmic_delimiter='|';
         $wmic_split_delimiter='\|';
         print "-------------------------- Time ---------------------\n";
         my $gmt = DateTime->now(time_zone => 'gmt');
         my $local = DateTime->now(time_zone=>'local');
         print `date`;
         print "GMT=$gmt, LOCAL=$local\n";
         print "======================================= END SYSTEM INFO ===================================================\n";
      }
   }
}

if ($opt_package) {
   print "Creating Check WMI Plus Bundle\n";
   my $tarfile="check_wmi_plus.v$VERSION.tar.gz";
   # tar up the files and dir, exclude subversion directory
   # run the plugin and put its help screen in a readme
   my $output=`$0 --itexthelp --noishowusage --noicollectusage`;
   open(README,">$base_dir/check_wmi_plus.README.txt");
   print README "check_wmi_plus v$VERSION\nFor installation details and more downloads see http://www.edcint.co.nz/checkwmiplus\nThe --help output follows - \n\n";
   print README $output;
   close(README);

   # a bit of hard coding here .....
   my $cmd="
      cd $base_dir;
      cp $conf_file_dir/check_wmi_plus.conf $conf_file_dir/check_wmi_plus.conf.sample;
      sed -i 's#/opt/nagios/bin/plugins#CHANGE ME TO THE DIRECTORY WHERE THE PLUGIN IS INSTALLED#' $conf_file_dir/check_wmi_plus.conf.sample;
      # make the compiled ini file zero so that it forces a recompile
      rm $wmi_data_dir/check_wmi_plus.compiledini;
      touch $wmi_data_dir/check_wmi_plus.compiledini;
      chown -R nagios:nagios $conf_file_dir $base_dir;
      tar czvf $tarfile --no-recursion --exclude=.svn --exclude=man1 check_wmi_plus.pl check_wmi_plus_help.pl check_wmi_plus.README.txt $conf_file_dir/check_wmi_plus.conf.sample $wmi_ini_dir/* $wmi_data_dir $wmi_data_dir/check_wmi_plus.compiledini event_generic.pl check_wmi_plus.makeman.sh
      ";
   $output=`$cmd 2>&1`;
   print "CMD:$cmd\n\nOUTPUT:$output\n\n";
   print "Created $base_dir/$tarfile\n";
   $output=`rm $conf_file_dir/check_wmi_plus.conf.sample`;
   exit 0;
}

if ($opt_command_examples) {
   show_command_examples("$wmi_ini_dir/$command_examples_ini_file{$opt_command_examples}");
   exit 0;
}

# check up on the ini file
if ($wmi_ini_file && ! -f $wmi_ini_file) {
   print "This plugin requires an INI file. Configure its location by setting the \$wmi_ini_file variable in '$conf_file' or by using the --inifile parameter to override the default setting. Ini File currently set to '$wmi_ini_file'";
   finish_program($ERRORS{'UNKNOWN'});
} elsif ($wmi_ini_dir && ! -d $wmi_ini_dir) {
   print "This plugin requires an INI directory. Configure its location by setting the \$wmi_ini_dir variable in '$conf_file' or by using the --inidir parameter to override the default setting. Ini Directory currently set to '$wmi_ini_dir'. ";
   finish_program($ERRORS{'UNKNOWN'});
}

if ($the_arguments{'_timeout'}) {
   $TIMEOUT=$the_arguments{'_timeout'};
}

if (!$opt_help && !$opt_texthelp && !$opt_inihelp) {
   # Setup the trap for a timeout only if not showing the help info
   $SIG{'ALRM'} = sub {
      $plugin_output.="UNKNOWN - Plugin Timed out ($TIMEOUT sec). There are multiple possible reasons for this, some of them include - The host $the_arguments{_host} might just be really busy, it might not even be running Windows.\n";
      finish_program($ERRORS{'UNKNOWN'});
   };
   alarm($TIMEOUT);
}
 
if ($the_arguments{'_bytefactor'}) {
   if ($the_arguments{'_bytefactor'} ne '1024' && $the_arguments{'_bytefactor'} ne '1000') {
      print "The BYTEFACTOR option must be 1024 or 1000. '$the_arguments{'_bytefactor'}' is not valid.\n";
      include_help();
      short_usage();
   }
}
my $actual_bytefactor=$the_arguments{'_bytefactor'} || $default_bytefactor;
# store the original specified command line bytefactor for later use (we need it for checknetwork)
$the_arguments{'_savedbytefactor'}=$the_arguments{'_bytefactor'} || '';
# reload the arguments hash bytefactor setting with the actual value used
# this allows use to substitute it into custom calculation fields
$the_arguments{'_bytefactor'}=$actual_bytefactor;

if ($opt_help || $opt_texthelp) {
   include_help();
   usage();
}

if ($opt_inihelp && !$opt_mode) {
   # only show the overview of inihelp if no mode is specified
   show_ini_help_overview();
}

if ($opt_Version) {
   print "Version: $VERSION\n";
   finish_program($ERRORS{'OK'});
}

if ($opt_warn && $opt_critical && $opt_value) {
   # making it easier to test warning/critical values
   # pass in -w SPEC -c SPEC and -v VALUE
   my ($test_result,$neww,$newc)=test_limits($opt_warn,$opt_critical,$opt_value);
   print "Overall Status Generated = $test_result ($neww,$newc)\n";
   finish_program($test_result);
}

if (! $the_arguments{'_host'} && !$opt_inihelp) {
   # they did not specify a hostname and they are not trying to get inihelp either
   # we need the inihelp bit here so that we drop through to load the inifile and read the inihelp
   print "No Hostname specified\n\n";
   include_help();
   short_usage();
}

# take a look at the username and if it is in the format USER@DOMAIN, change it to DOMAIN/USER
if ($opt_username=~/^(.*?)\@(.*?)$/) {
   $opt_username="$2/$1";
   $debug && print "Username specified as USER\@DOMAIN, altering to DOMAIN/USER\n";
}

# take a copy of the original arguments
%the_original_arguments=%the_arguments; # not really used at the moment

# object for holding the ini file content
my $wmi_ini=();

#==============================================================================
#===================================== MAIN ===================================
#==============================================================================

# most of the time if we are running within NAGIOS then this env variable gets set
# if it is not there we are probably running from the command line
my $running_within_nagios=$ENV{'NAGIOS_PLUGIN'} || '';

if (! -x $wmic_command) {
   print "This plugin requires the linux implementation of wmic eg from zenoss.\nOnce wmic is installed, configure its location by setting the \$wmic_command variable in '$conf_file'.";
   finish_program($ERRORS{'UNKNOWN'});
}

$use_pro_library && endtimer('Preparation');

# save the mode and submode
$the_arguments{'_mode'}=$opt_mode;
$the_arguments{'_submode'}=$opt_submode;

if ($force_ini_open) {
   $wmi_ini=open_ini_file($wmi_ini);
}

# now run the appropriate sub for the check
if (defined($mode_list{$opt_mode})) {
   # have to set a reference to the subroutine since strict ref is set
   my $subref=\&$opt_mode;
   &$subref('');
} else {
   if ($wmi_ini_file || $wmi_ini_dir || $force_ini_open) {
      # maybe the mode is defined in the ini file
      # read the ini file and check
      $use_pro_library && starttimer('Read INI Files');
      $wmi_ini=open_ini_file($wmi_ini);

      my $ini_section='';
      if (defined($wmi_ini)) {

         # there are 2 ways a section in the ini file is matched
         # 1) [MODE] - $opt_mode matches the whole section name
         # 2) [MODE SUBMODE] = $opt_mode is a Config::IniFiles Group and $opt_submode is a MemberName
         # first see if there is a section named $opt_mode 
   
         if ($wmi_ini->SectionExists($opt_mode)) {
            $debug && print "Found Section $opt_mode\n";
            $ini_section=$opt_mode;
         } else {
            # now check for a group and a member
            # load the ini file groups into an array - a group is a mode
            my @ini_modes=$wmi_ini->Groups();
            # see if we have found the mode
            # $debug && print "INI FILE MODES " . Dumper(\@ini_modes);
            my @found_modes=grep(/^$opt_mode$/,@ini_modes);
            if ($#found_modes==0) {
               $debug && print "Found Group $opt_mode\n";
               # now use $opt_submode to match a membername
               my @group_members=$wmi_ini->GroupMembers($opt_mode);
               $debug && print "GROUP MEMBERS " . Dumper(\@group_members);
               my @found_members=grep(/^$opt_mode +$opt_submode$/,@group_members); # could be any number of spaces between group and member
               if ($#found_members==0) {
                  $debug && print "Found Member $opt_submode\n";
                  $ini_section=$found_members[0];
               }
               
            }
         }
      } else {
         print "INIFILE and/or INIDIR are set but there were no ini file(s) or an error occurred trying to read them.\n";
      }
      $use_pro_library && endtimer('Read INI Files');
      
      if ($ini_section) {
         checkini($wmi_ini,$ini_section);
      } elsif ($opt_inihelp) {
         show_ini_help_overview();
      } else {
         print "A valid MODE and/or SUBMODE must be specified\n";
         include_help();
         short_usage();
      }

   }

   print "A valid MODE and/or SUBMODE must be specified\n";
   include_help();
   short_usage();
}

# if we get to here we default to an OK exit
finish_program($ERRORS{'OK'});

#==============================================================================
#================================== FUNCTIONS =================================
#==============================================================================

#-------------------------------------------------------------------------
sub include_help {
if (-f "$base_dir/check_wmi_plus_help.pl") {
   if (do "$base_dir/check_wmi_plus_help.pl") {
      $debug && print "Help Library is present\n";
   } else {
      print "Help Library exists but does not compile: $@\n";
      exit 1;
   }
}
}
#-------------------------------------------------------------------------
sub check_module_versions {
my ($force_show)=@_;
no strict "refs"; # just turn off strict refs for a little so we can use strings as variables names!
my $versions_ok=1;
foreach my $moduleversion (keys %good_module_versions) {
   # do as little as possible in this loop to make it faster
   if ($$moduleversion lt $good_module_versions{$moduleversion}) {
      # found a bad one - jump out of loop
      $versions_ok=0;
      last;
   }
}

if (!$versions_ok || $force_show) {
   $versions_ok || print "Warning - one or more of your Perl Modules are out of date and this may cause plugin problems. If you are having any problems with Check WMI Plus you must upgrade your Perl Modules before contacting support (since they'll just tell you to upgrade!). You can override this warning at your peril by using the --IgnoreMyOutDatedPerlModuleVersions command line option or the \"\$ignore_my_outdated_perl_module_versions\" setting in the conf file ($conf_file). Version Information on the next line.\n";
   printf("%-19s %19s %7s %-10s\n",'MODULE_NAME','INSTALLED_VERSION','STATUS','DESIRED_VERSION');
   foreach my $moduleversion (keys %good_module_versions) {
      my $status='ok';
      if ($$moduleversion lt $good_module_versions{$moduleversion}) {
         $status='BAD';
      }
      my $module_name=$moduleversion;
      $module_name=~s/::VERSION$//;
      if ($module_name eq ']') {
         $module_name='Perl Version';
      }
      printf("%-19s %19s %7s %10s\n",$module_name,$$moduleversion,$status,$good_module_versions{$moduleversion});
   }
}

use strict "refs";
return $versions_ok;
}
#-------------------------------------------------------------------------
sub open_ini_file {
# pass in 
# the object that may already hold the ini file content
my ($wmi_ini)=@_;

if ($ini_files_already_opened) {
   # already open so just returned the passed in object
   $debug && print "Not reopening INI files since they have already been opened\n";
   return $wmi_ini;
} else {
   # ini files not open so open them
   my $ini_file;
   
   my $ini_is_new=0;
   
   if ($use_pro_library && $use_compiled_ini_files) {
      # when using pro we can compile the ini files so that we don't have to open and parse them all everytime we run
      $debug && print "Trying to use Pro compiled ini files ....\n";
      if (-s $compiled_ini_file) {
         $debug && print "Using Pro compiled ini file\n";
         $ini_file=use_compiled_ini_files();
      } else {
         $debug && print "No existing Pro compiled ini file\n";
      }
   }
   
   if (!$ini_file) {
   
      $use_pro_library && starttimer('Open INI Files');
      $debug && print "Opening Ini Files ...\n";
      
      if ($wmi_ini_file) {
         # firstly open the ini file configured 
         $debug && print "   opening first ini file: $wmi_ini_file\n";
         $ini_file=new Config::IniFiles( -file=>$wmi_ini_file, -allowcontinue=>1 );
         $ini_is_new=1;
      }
      
      if ($wmi_ini_dir) {
         # see what ini files are available in the dir
         my @ini_list=get_files_from_dir($wmi_ini_dir,'\.ini$');
         my $ini_count=$#ini_list+1;
         $debug && print "   checking ini dir $wmi_ini_dir, found $ini_count file(s)\n";
         foreach my $ini (@ini_list) {
            # open this ini file and it will be merged with and override any clashing settings in previously opened ini files
            my $next_ini_file;
            if (defined($ini_file)) {
               # there is a previous ini file so we need to -import it
               $debug && print "   opening ini file: $ini\n";
               $next_ini_file=new Config::IniFiles( -file=>"$wmi_ini_dir/$ini", -allowcontinue=>1, -import=>$ini_file );
            } else {
               # no previous ini file so do not use the -import
               $debug && print "   opening first ini file: $ini\n";
               $next_ini_file=new Config::IniFiles( -file=>"$wmi_ini_dir/$ini", -allowcontinue=>1);
            }
            
            if (!defined($next_ini_file)) {
               # got an error parsing the ini file
               print "There is a problem reading the ini file: $ini. The error(s) are:\n" . join("\n",@Config::IniFiles::errors);
               finish_program($ERRORS{'UNKNOWN'});
            }
            
            $ini_file=$next_ini_file;
            $ini_is_new=1;
         }
      }
      $use_pro_library && endtimer('Open INI Files');
   }
   
   if ($ini_is_new && $use_pro_library && $use_compiled_ini_files) {
      # we've just read the ini files and we are using the pro library so we can compile them
      $debug && print "Trying to use Pro to compile ini files ....\n";
      compile_ini_files($ini_file);
   }
   
   # check for variable defintions and load them to an array if found
   my @tmp_array=$ini_file->val('variables','static','');
   $use_pro_library && load_static_variables_from_array(\@tmp_array);
   $debug && print "Global Static Ini Variables: " . Dumper(\%ini_static_variables);
   
   $ini_files_already_opened=1;
   return $ini_file;
}
}
#-------------------------------------------------------------------------

sub show_warn_crit_field_info {
# shows consistent information about warn/crit fields for help modes
# pass in
# the ini file object
# the ini file mode (actually the complete section name)
my ($wmi_ini,$ini_mode)=@_;
my $output='';
my @test_fields_list=$wmi_ini->val($ini_mode,'test','');
if ($test_fields_list[0] ne '') {
   # show that the first field is the default
   $test_fields_list[0].=" (Default)";
   $output="\n   WARN/CRIT  can be used for this MODE. You need to specify a field name if not using the Default field eg -w FIELD=VALUE or simply -w VALUE for the Default field. Valid Warning/Critical Fields are: " . join(", ",@test_fields_list) . "\n";
} else {
   # need this to help keep man page indenting correct
   $output="\n   WARN/CRIT  Not used for this MODE.\n";
}
return $output;
}
#-------------------------------------------------------------------------
sub show_command_examples {
# pass in 
# the name of the template file to process
my ($example_file)=@_;

my $base_command="$0 -H $the_arguments{'_host'} -u $opt_username -p $opt_password --noishow --noicollect";
my $exe_dir=$0;
$exe_dir=~s/^(.*)\/(.*?)$/$1\//;

$debug && print "Base Command = $base_command\n";
$debug && print "Opening Command Examples Ini File: $example_file\n";

my %variables=();

if ( -f $example_file) {

   if ( open(EXAMPLE,$example_file) ) {
      $debug && print "File opened\n";
      foreach my $line (<EXAMPLE>) {
         chomp($line);
         $debug && print "LINE: $line\n";
         my $output=0;
         if ($line=~/^#/) {
            # ignore
         } elsif ($line=~/^!Define:(.*?):(.*)$/) {
            # a define line in the format !Define:Variable:Value
            $variables{$1}=$2;
            $debug && print "Definition: $1 = $2\n";
         } elsif ($line=~/^!T(.*)$/) {
            $output="<strong>$1</strong>";
         } elsif ($line=~/^!A(.*)$/) {
            # this is a command argument
            $output="Command: <code>$base_command $1</code>\n";
            
            my $cmd_output=`$base_command $1`;
            # remove final \n from commmand output
            $cmd_output=~s/\n$//;
            # highlight plugin display output and performance data output
            # performance data is
            # 1) between the first | and next \n
            # 2) between the first | and end of line if no \n
            # plugin display output is everything else
            # by default enclose everything in blue font and then go and find the performance data
            $cmd_output="<font color=$variables{'display'}>$cmd_output</font>";
            
            # if the $cmd_output contains a | followed by a \n then performance data is between | and \n
            if ($cmd_output=~/\|(.*?)\n/) {
               # close blue font and then start red
               # restart red font after perfdata
               $cmd_output=~s/\|(.*?)\n/<\/font>\|<font color=$variables{'perf'}>$1<\/font><font color=$variables{'display'}>/s;
            } elsif ($cmd_output=~/\|(.*)$/) {
               # performance data is everything after first |
               # close blue font and then start red
               $cmd_output=~s/\|(.*)$/<\/font>\|<font color=$variables{'perf'}>$1/s;
            }
            
            # if there are any [Triggered ...] brackets change their colour too
            if ($cmd_output=~/\[Triggered.*?\]/) {
               # close the existing <font> and start a new one
               $cmd_output=~s/(\[Triggered.*?\])/<\/font><font color=$variables{'trigger'}>$1<\/font><font color=$variables{'display'}>/gs;
            }
            
            $output.="Output : <code>$cmd_output</code>";
            
            if (! $opt_z) {
               # try and mask any user/password/host
               $output=~s/-H\s*(\S*?)\s/-H HOST /;
               $output=~s/-u\s*(\S*?)\s/-u USER /;
               $output=~s/-p\s*(\S*?)\s/-p PASS /;
               # also hide the full path of the command (to make the display smaller)
               $output=~s/$exe_dir//;
            }
            
         } else {
            $output="$line";
         }
         
         if ($output ne 0) {
            print "$output\n";
         }
      }
   } else {
      print "Warning - error when opening $example_file\n";
   }
} else {
   print "Warning - could not open $example_file\n";
}
}
#-------------------------------------------------------------------------
sub show_ini_help_overview {
# show ini help sections
# pass in
# 1 to get all inihelp detail, 0 to get just a one liner
my ($give_all_detail)=@_;

# it might be open already but just open it again
my $wmi_ini=open_ini_file($wmi_ini);
# here we need to list out the modes available in the ini file - with some of the text from their inihelp= field
my @ini_modes=$wmi_ini->Sections();
$debug && print "Showing inihelp for the following modes/submodes - " . Dumper(\@ini_modes);
my $text_for_overview="\n";
if (!$give_all_detail) {
   $text_for_overview="(Listed in summary form, one per line, as MODE SUBMODE - Help Text\n";
}

print<<EOT;
INI FILE HELP SUMMARY
 The ini file and/or dir provides the following Modes and/or Submodes $text_for_overview
EOT

# if we are lucky the env variable COLUMNS has been set to the width of the terminal
# if not lets just assume 132
my $term_width=132;
# make some room for the ...\n we might add to the end
$term_width-=4;
foreach my $ini_mode (sort @ini_modes) {
   my $query=$wmi_ini->val($ini_mode,'query','');
   # only do anything else if query is defined
   
   if ($query) {
      my $inihelp=$wmi_ini->val($ini_mode,'inihelp','No help available');

      my $display='';
      if ($give_all_detail) {
         # collect these next 2 values from the ini file
         # defaults should be the same as that collected during check_ini
         my $number_wmi_samples=$wmi_ini->val($ini_mode,'samples',$default_inifile_number_wmi_samples);
         my $ini_delay=$wmi_ini->val($ini_mode,'delay',$default_inifile_delay);
         
         # break up the ini_mode to MODE and SUBMODE and display them
         $ini_mode=~/^(\w+?)(\s+\w*?)*$/;
         my $inimode=$1 || '';
         my $inisubmode=$2 || '';
         my $title="$inimode";
         my $extra_title="(-m $inimode";
         if ($inisubmode) {
            # remove any spaces at the start
            $inisubmode=~s/\s*//g;
            $title.=", $inisubmode";
            $extra_title.=" -s $inisubmode";
         }
         $extra_title.=')';
         # we used to have inihelp include the mode and submode in the actual text, so remove it if it is still there
         # remove everything up to the end of the first line of ========= and the \n
         $inihelp=~s/^(.*?)(==)(=*\n)(.*?)$/$4/s;
         
         # make sure each line in $inihelp starts with exactly 3 spaces to ensure proper formatting when shown as a manpage
         $inihelp=~s/^(\s*)(.*?)$/   $2/mg;

         # check the required plugin version for this check
         my $requires_text='';
         my $requires_version=$wmi_ini->val($ini_mode,'requires',0);
         if ($VERSION < $requires_version) {
            # this is a problem
            $requires_text="   ----- Requires plugin version>=$requires_version. Will not work with this version -----  \n";
         }

         $display=" $title $extra_title  \n$requires_text$inihelp\n";
         
         # add automatic information about the DELAY parameter
         if ($number_wmi_samples>1) {
            $display.="\n   $default_help_text_delay Default is $ini_delay.\n";
         } else {
            # delay not required or meaningful for this MODE
         }
         
         $display.=show_warn_crit_field_info($wmi_ini,$ini_mode);
         
      } else {
         # we like to format our inihelp with a line as the title then a line full of ========= and then the text
         # lets only show the text, by removing the first stuff if it exists
         $inihelp=~s/^(.+?\n[= ]+\n)(.*)$/$2/s;
         # convert all line breaks and multiple spaces to single spaces
         $inihelp=~s/\n/ /sg;
         $inihelp=~s/( +)/ /sg;
         # remove leading spaces
         $inihelp=~s/^( *)//sg;
      
         $display="$ini_mode - $inihelp";            
         
         # if it is longer than $term_width chars then add .. to the end and truncate it to make it no longer than $term_width chars
         $display=~s/^(.{$term_width,$term_width})(.+){1,}$/$1\.\.\./s;
      }
      print "$display\n";
   }
}
finish_program($ERRORS{'UNKNOWN'});
}
#-------------------------------------------------------------------------
sub display_uptime {
# pass in an uptime string
# if it looks like it is in seconds then we convert it to look like days, hours minutes etc
my ($uptime_string)=@_;
my $new_uptime_string=$uptime_string;
if ($uptime_string=~/^[0-9\.]+$/) {
   # its in seconds, so convert it
   my $uptime_minutes=sprintf("%d",$uptime_string/60);
   my $uptime=$uptime_string;
   my $days=int($uptime/86400);
   $uptime=$uptime%86400;
   my $hours=int($uptime/3600);
   $uptime=$uptime%3600;
   my $mins=int($uptime/60);
   $uptime=$uptime%60;

   my $day_info='';
   if ($days==1) {
      $day_info="$days day";
   } elsif ($days>1) {
      $day_info="$days days";
   }
   $new_uptime_string="$day_info " . sprintf("%02d:%02d:%02d (%smin)",$hours,$mins,$uptime,$uptime_minutes);
}
return $new_uptime_string; 
}
#-------------------------------------------------------------------------
sub scaled_bytes {
# pass a number
my ($incoming)=@_;
if ($incoming ne '' && looks_like_number($incoming)) {
   # new code to now use Number::Format - instead of trying to do it ourselves
   # this is about half the speed BUT looks nicer an we don't use it that much to make a speed difference
   my %options=(
      precision => 3,         # hard coded precision - should be ok
      base      => $actual_bytefactor, 
   );
   return format_bytes($incoming,%options);

   ## from http://www.perlmonks.org/?node_id=378538
   ## very cool
   ## modified a little to protect against uninitialised variables and to remove the byte unit 
   #(sort { length $a <=> length $b }
   #map { sprintf '%.3f%s', $incoming/$actual_bytefactor**$_->[1], $_->[0] }
   #[""=>0],[K=>1],[M=>2],[G=>3],[T=>4],[P=>5],[E=>6])[0]
} else {
   return $incoming;
}
}
#-------------------------------------------------------------------------
sub get_wmi_data {
# perform the same WMI query 1 or more times with a time delay in between and return the results in an array
# good for using RAW performance data and gives me a standard way to perform queries and have the results loaded into a known structure
# pass in
# number of samples to get
# the WMI Name space to use, defaults to 'root/cimv2'
# the WMI query to get the values you are wanting
# the regular expression to extract the names of the values (comma list like $value_rege not supported as this parameter is not really needed or hardly ever)
# the regular expression to extract the results - we also support this being a comma delimited list of field numbers to be kept where we assume the field delimiter is | and that the field numbers start at 1 eg 1,4,5
# an array reference where the results wiel be placed. Index 0 will contain the first values, index 1 the second values
# the delay (passed to the sleep command) between queries. This is reference that "passed back" so that the calling sub can see what was actually used. Pass by reference using \$VARIABLE
# An array reference listing the column titles that we should provide sums for
#     There are several sums made available
#     - array index [0][ROWNUMBER] prefixed by _QuerySum_fieldname which sums up all the fieldnames across multiple queries
#     - array index [QUERYNUMBER][0] prefixed by _ColSum_fieldname which sums up all the fieldnames (columns) for multiple rows in a single query number QUERYNUMBER
# set $slash_conversion to 1 if we should replace all / in the WMI query with \\

# we return 
# 1) an empty string if it worked ok, a msg if it failed
# 2) the index of in the array of where the latest data is stored

my ($num_samples,$wmi_namespace,$wmi_query,$column_name_regex,$value_regex,$results,$specified_delay,$provide_sums,$slash_conversion)=@_;

# the array @[$results} will look something like this when we have loaded it
# @array[INDEX1][INDEX2]{HASH1}=VALUE
# where
# INDEX1 is number of the query eg if we do 2 queries then INDEX1 will be 0 and 1
# INDEX2 is the result line, with one index per line returned in the WMI query eg if we do a query which lists 5 processes INDEX2 will be from 0 to 4
# HASH1 will contain the field names eg ProcessorQueueLength
# the value will be the value of the field eg 16
# There are some special values also stored in this structure
# @array[0][0]{'_ChecksOK'}=the number of checks that were completed OK
# @array[INDEX1][0]{'_ItemCount'}=the number of rows returned by the WMI query number INDEX1
# So if you are doing only a single query that returns a single row then INDEX1 always=0 and then INDEX always=0 as well

# this will be set to the array index in $results (eg $$results[0] or $$results[1]) where the last WMI query data lives.
# this should then be used later on as the place to store all the custom fields and other calculated data
# we will also ensure fields provided by this sub are in that index also eg _ChecksOK, _QuerySum etc
my $final_data_array_index=0;

# put both the command line and wmiclient library arguments into this array
my @wmi_args=();

# $global_wmic_call_counter is already >0 then this means we are coming back into this sub to do another lot of wmi calls
# if this happens in test_generate mode then it means that we previously printed out an ini entry outputstring= to start collecting the general output of the plugin
# we need to close that ini setting off with an EOT so that it does not interfere with other ini settings this sub is about to make
$test_generate && $global_wmic_call_counter>0 && print "\nEOT\n";

# extract parameters from arguments
if ($$specified_delay) {
   if ($$specified_delay ge 0) {
   # all good - we assume
   } else {
      print "Delay not specified correctly. Should be a number >= zero.\n";
      finish_program($ERRORS{'UNKNOWN'});
   }
}

# check the WMI namespace and set default if needed
if ($wmi_namespace eq '') {
   $wmi_namespace='root/cimv2';
}

# the WMI query may contain "variables" where we substitute values into
# a variables looks like {SOMENAME}
# if we find one of these we substitute values from the hash %the_arguments
# eg {_arg1} gets replaced by the value held in $the_arguments{'_arg1'}
# this is how we pass command line arguments into the query
$wmi_query=~s/\{(.*?)\}/$the_arguments{$1}/g;

# we also need to make sure that any ' in the query are converted to "
$wmi_query=~s/'/\"/g;
#$wmi_query=~s/'/\\'/g; # we used to escape the '

if ($slash_conversion) {
   # replace any / in the WMI query \\ since \ are difficult to use in linux on the command line
   # we replace it with \\ to pass an actual \ to the csmmand line
   # use # as the delimiter for the regex to make it more readable (still need to escape / and \ though)
   $wmi_query=~s#\/#\\\\#g;   
}

# How to use an alternate namespace using wmic
# "SELECT * From rootdse" --namespace=root/directory/ldap
# check delimiter
# if it is not | then add it to the command line
if ($wmic_delimiter ne '|') {
   push(@wmi_args,'--delimiter',"$wmic_delimiter");
}

# build up the extra wmic arguments if defined
if ($#opt_extra_wmic_args>=0) {
   # Each array index should contain a complete argument for wmic eg --option=#client ntlmv2 auth#=Yes 
   # To save difficulty with quoting we translate # into "
   # So --option=#client ntlmv2 auth#=Yes becomes --option="client ntlmv2 auth"=Yes
   foreach my $arg (@opt_extra_wmic_args) {
      $arg=~s/#/"/g;
      # not sure if this will work when using the wmiclient library
      push(@wmi_args,$arg);
      $debug && print "Extra Wmic Arguments specified:$arg\n";
   }
}

my $wmi_query_quote="'";
if ($host_os =~ m/win32$/i) {
   # if running on Windows we need to deal with the ' in the query and change the command line to quote it using \"
   $wmi_query=~s/\"/\\\"/g;
   $wmi_query_quote='"';
}

# if user name/password specified they always override the auth file
if ($opt_username && $opt_password) {
   push(@wmi_args,'-U',"${opt_username}%${opt_password}");
} elsif ($opt_auth_file) {
   # quick check on the auth file
   if (-s -r $opt_auth_file || $opt_ignore_auth_file_warnings) {
      # now set up the auth file command line
      push(@wmi_args,'-A',$opt_auth_file);
   } else {
      print "The Authentication File \"$opt_auth_file\" either does not exist, can not be accessed or is empty. You need this to allow $wmic_command to authenticate to the Windows machine. See --help for information on the file requirements. You can ignore this warning and proceed, passing the file to wmic by specifying the --IgnoreAuthFileWarnings argument. If the file really does have access problems wmic will not work either and may fail in a not so nice way eg hang on waiting for STDIN.\n";
      if ($debug) {
         print "Details for \"$opt_auth_file\" and current User\n";
         print "ls -ln gives " . `ls -ln "$opt_auth_file"`;
         print "id gives " . `id`;
         if (-s $opt_auth_file) {
            print "File exists and size>0\n";
         } else {
            print "File size<=0\n";
         }
         if (-r $opt_auth_file) {
            print "File is readable\n";
         } else {
            print "File is not readable\n";
         }
         print "Perl says that current Effective Login ID = $> (Real = $<)\n";
         print "Perl says that current Group ID = $) (Real = $()\n";
      }
      finish_program($ERRORS{'UNKNOWN'});
   }
}

# now add the namespace, hostname and query arguments
push(@wmi_args,'--namespace',$wmi_namespace);
push(@wmi_args,"//$the_arguments{'_host'}");
push(@wmi_args,"$wmi_query");

# create wmi command line using the parameters in the array
my $output='';

# set up the command line
# enclose all parameters in the apprpriate host_os based quote character
my $wmi_commandline = "$wmic_command $wmi_query_quote" . join("$wmi_query_quote $wmi_query_quote",@wmi_args) . $wmi_query_quote;

my $all_output=''; # this holds information if any errors are encountered

my $failure=0;
my $checks_ok=0;
my @hardcoded_field_list;

my $get_data_for_the_first_time='the state file does not exist';
my $start_wmi_query_number=0;
my $keep_state_mode=0;
my $time_now=time();
if ($opt_keep_state && $num_samples>1) {
   # keep state mode only works if you specifiy the command line option and you need more than one WMI sample
   # make up a file name that will be unique to the check and various parameters
   # $opt_keep_state_id is just in case the user needs a more unique file name
   $keep_state_file="cwpss_${opt_mode}_${opt_submode}_${the_arguments{'_host'}}_${the_arguments{'_arg1'}}_${the_arguments{'_arg2'}}_${the_arguments{'_arg3'}}.${opt_keep_state_id}";
   $keep_state_file=~s/\W*//g;
   $keep_state_file="$tmp_dir/$keep_state_file.state";
   $debug && print "Starting Keep State Mode\nSTATE FILE: $keep_state_file\n";

   if ($test_ignorekeepstatefiles) {
      # ignore the reading of or testing for keep state files
   } elsif ( ! -s $keep_state_file) {
      $get_data_for_the_first_time="the previous state data file ($keep_state_file) contained no data";
   } elsif ( -f $keep_state_file) {
      # the keep state file exists so we read it, poke our existing data into the $results array
      # then do another WMI query to get the next lot of WMI data
      # first open the file and make sure it is valid

      # we consider the data expired if it is older than $opt_keep_state_expiry seconds
      my $expiry_limit=$time_now-$opt_keep_state_expiry;

      my $stored_results;
      eval {   $stored_results=retrieve($keep_state_file);  };
      if ($@) {
         # we seem to have got an error with the retrieve
         # check the fileage of the file
         # if it is older than $expiry_limit, delete the file and exit - next run will create it again
         my $file_mod_time=(stat($keep_state_file))[9] || 0;
         if ($file_mod_time<$expiry_limit) {
            # this file has expired anyway, delete it
            my $fileage=$time_now-$file_mod_time;
            $get_data_for_the_first_time="there was a problem retrieving the previous state data ($keep_state_file). The file has expired anyway ($fileage seconds old)";
         } else {
            # some other error
            print "There was a problem retrieving the previous state data ($keep_state_file). If this error persists you may need to remove the state data file. The error message was: $@";
            finish_program($ERRORS{'UNKNOWN'});
         }
      }
      
      # now check expiry
      $debug && print "Checking previous data's expiry - Timestamp $$stored_results[0][0]{'_KeepStateCreateTimestamp'} vs Expiry After $expiry_limit (Keep State Expiry setting is ${opt_keep_state_expiry}sec)\n";
      if (defined($$stored_results[0][0]{'_KeepStateCreateTimestamp'})) {
         if ($$stored_results[0][0]{'_KeepStateCreateTimestamp'}<$expiry_limit) {
            # data has expired
            # need to get it again
            $debug && print "Data has expired - getting data again\n";
            # by default we will now get the data again for the first time
            $get_data_for_the_first_time='the previously stored state data has expired';
         } else {
            # skip getting the data for the first time
            $get_data_for_the_first_time='';
            $start_wmi_query_number=1; # dont start at 0 (since we already have that data)
            $keep_state_mode=2;
            
            $debug && print "Using Existing WMI DATA of:" . Dumper($stored_results);
            $$results[0]=$$stored_results[0];
            
            # fudge delay parameter so that it the time between runs, instead of what was set on the command line
            $the_arguments{'_delay'}=$time_now-$$stored_results[0][0]{'_KeepStateCreateTimestamp'};
            # set the sample period into the results so that we can display it
            $$results[0][0]{'_KeepStateSamplePeriod'}=$the_arguments{'_delay'};
         }
      } else {
         # keep state timestamp was not found - data invalid
         # we will, by default now get the data again for the first time
         $debug && print "Data does not contain create timestamp - getting data again\n";
         $get_data_for_the_first_time='previously stored state data is invalid';
      }
   }

   if ($get_data_for_the_first_time) {
      # keep state file does not exist so we need to create it after doing a WMI Query
      # we only want to do the first WMI query, so reduce the $num_samples to 1
      $num_samples=1;
      $keep_state_mode=1;
      # make sure the results array is empty
      $results=();
   }
}

# initialise the sums if they have been asked for - since if you find no WMI results the sums would have been left unitialised
foreach my $field_name (@{$provide_sums}) {
   # we can only initialise the [0][0] instances but that is enough since they are only a problem if the QMI query returns empty
   $$results[0][0]{"_QuerySum_$field_name"}=0;
   $$results[0][0]{"_ColSum_$field_name"}=0;
}

# loop through the multiple queries
# 0 is the first one, 1 the second one etc
for (my $i=$start_wmi_query_number;$i<$num_samples;$i++) {
   # record the index where we are storing the latest WMI data
   $final_data_array_index=$i; 
   
   if ($debug) {
      # mask the user name and password in the wmic command, but not if $opt_z is set
      my $cmd=$wmi_commandline;
      if (! $opt_z) {
      $cmd=~s/-U$wmi_query_quote $wmi_query_quote(.*?)%(.*?)$wmi_query_quote /-U${wmi_query_quote} ${wmi_query_quote}USER%PASS${wmi_query_quote} /;
      }
      print "Round #" . ($i+1) . " of $num_samples\n";
      if ($use_wmilib && ! $force_wmic_command) {
         print "Using wmiclient library but displaying command line equivalent\nQUERY:$cmd\n";
      } else {
         print "QUERY: $cmd\n";
      }
   }
   $test_generate && print "wmiccmd=$wmi_commandline\n";

   my $wmic_cache_file="";
   my $run_wmic=1;
   if ($opt_use_cached_wmic_response || $use_cached_wmic_responses) {
      # if this option is set then we want to use the cached wmic response and not actually call wmic itself
      # we can only used the cached response if the cache file for this check exists
      
      # build up the cache file name
      $wmic_cache_file="cwpwc_${opt_mode}_${opt_submode}_${the_arguments{'_host'}}_${the_arguments{'_arg1'}}_${the_arguments{'_arg2'}}_${the_arguments{'_arg3'}}.${opt_keep_state_id}";
      $wmic_cache_file=~s/\W*//g;
      $wmic_cache_file="$tmp_dir/$wmic_cache_file.wmiccache";
      $debug && print "WMIC Cache File Name: $wmic_cache_file\n";
      
      if ( -f $wmic_cache_file) {
         my $last_results_ref;
         eval {   $last_results_ref=retrieve($wmic_cache_file);   };
         if ($@) {
            # we seem to have got an error with the retrieve
            # since this is a sort of debug mode we are not too concerned
            # we'll just rerun wmic and try and store the results again
            print "WARNING - Unable to retrieve cache WMIC results from file $wmic_cache_file. ";
         } else {
            # only don't run wmic if we have retrieved some previous results
            $run_wmic=0;
            # set the output to be the whatever we retrieved
            $output=$$last_results_ref;
            $debug && print "Using last cached WMIC response\n";
         }
      } else {
         $debug && print "No existing WMIC response, will cache this one\n";
      }
   }
   
   if ($run_wmic) {
      $global_wmic_call_counter++;
      if ($test_run && $test_wmic_file_base) {
         # we don't actually run wmic - we just pretend we do
         # we get the wmic output from a file
         my $test_wmic_filename="${test_wmic_file_base}_${test_number}_${global_wmic_call_counter}\n";
         if (open (WMICO,$test_wmic_filename)) {
            my @wmic_data=<WMICO>;
            $debug && print "Using Test Mode wmic output from $test_wmic_filename\n";
            $output=join('',@wmic_data);
            close(WMICO);
         } else {
            die("Can't get Test Mode WMIC Output from $test_wmic_filename\n");
         }
      } elsif ($use_wmilib && ! $force_wmic_command) {
         # add the debug parameter so that we get better output for when errors occur
         # push(@wmi_args,'-d','0');
         # get the wmi data using the library
         my $exitcode='';
         my %extraargs=(
            Timeout  => $TIMEOUT,
            );
         starttimer('wmic library');
         ($exitcode,$output) = invoke_wmiclient(\%extraargs, \@wmi_args);
         endtimer('wmic library');
         $wmic_library_calls++;
         $debug && print "WMIClient Lib Exit Code = $exitcode\n";
      } else {
         # get the wmi data using the command line
         $use_pro_library && starttimer('wmic');
         $output = `$wmi_commandline 2>&1`;
         $use_pro_library && endtimer('wmic');
         $wmic_calls++;
      }

      if ($opt_use_cached_wmic_response || $use_cached_wmic_responses) {
         # if this option is set then we want to store the wmic response for the next time we are supposed to call wmic
         $debug && print "Caching WMIC response for next run\n";
         eval {
            my $out=\$output;
            store($out,$wmic_cache_file);
         };
         check_for_store_errors($@);
         
      }
   }

#   ########### FOR TESTING ONLY to make it look like there are multiple CPUs from the test machine
   if ($output=~/DeviceID.Name.NumberOfCores/) {
      $output=$output . "CPU1|Intel(R) Core(TM) i5-6500 CPU @ 3.20GHz|2\n";
   }

   $all_output.=$output;
   $debug && print "OUTPUT: $output\n";
   $test_generate && print "wmicoutput_${test_number}_${global_wmic_call_counter}=<<EOT\n${output}\nEOT\n";

   # now we have to verify and parse the returned query
   # a valid return query comes back in the following format
   # CLASS: <WMICLASSNAME>
   # <FIELDNAMES separated by |>
   # <Row 1 DATA VALUES separated by |>
   # <Row 2 DATA VALUES separated by |>
   # <Row n DATA VALUES separated by |>
   #
   # Sometimes queries only return a single data row

   # could be something like this:
   # CLASS: Win32_PerfRawData_PerfOS_Processor
   # Name|PercentProcessorTime|Timestamp_Sys100NS
   # _Total|2530739524720|129476821059431200

   # There are 3 typical types of outputs:
   # 1) the query works fine and returns data - this looks like above
   # 2) the query worked but found no data eg you are looking for specific process names then $output will be empty
   # 3) an error occurred - the error message is returned
   
   if ($output eq '') {
      # the query probably worked but just returned no data
      # lets set some variables
      $$results[0][0]{'_ChecksOK'}++;
      $$results[$i][0]{'_ItemCount'}=0;
   } else {
      # now we have 2 possibilities left
      # 1) good results formatted nicely
      # 2) errors
      
      my $class_row_content='';
      if ($output=~/(CLASS: \w+)\n/sg) {
         # looks like we have some results
         # sometimes the CLASS line repeats, so we store it for later
         $class_row_content=$1;
         $debug && print "Storing Class Row:$class_row_content\n";
         
         # now, if $column_name_regex is specified then we have to use the regex to look for the column names
         # else we just look for the next line and split it on |
         my $got_header=0;
         my $last_header_field_number=-1;
         my $header_row_content='';
         my @column_names=();
         # doing this check each time helps validate the results
         if ($column_name_regex) {
            if ($output=~/$column_name_regex/sg) {
               $got_header=1;
               my $j=0;
               # I'd really like to use a perl 5.10 construct here (Named Capture buffers ie the hash $+) to make it much nicer code but have decided to do it an ugly way to accomodate older versions
               # so now we have to go through $1, $2 one at a time in a hardcoded fashion (is there a better way to do this?) 
               # this places a hard limit on the number of fields we can find in our regex
               # of course this is only a problem if you need to specify a specific regex to find your field data in the WMI results
               #------------------------------------------------------
               # add more hardcoding here as needed - yuk - at some point we will use %+ - when enough people are on perl 5.10 or more
               # this is the first of 2 places you need to change this hardcoding
               # hopefully putting these to zero if they do not have any value will be ok, need a way to tell if $1 is '' or 0 really
               @hardcoded_field_list=( $1||0,$2||0,$3||0,$4||0,$5||0,$6||0,$7||0,$8||0,$9||0 );
               #------------------------------------------------------
               $debug && print "COLUMNS:";
               foreach my $regex_field (@hardcoded_field_list) {
                  $debug && print "$regex_field, ";
                  if ($regex_field ne '') {
                     $column_names[$j]=$regex_field;
                  }
                  $j++;
               }
               $last_header_field_number=$j-1;
               $debug && print " (last index=$last_header_field_number cols)\n";
               # increment the ok counter
               $$results[0][0]{'_ChecksOK'}++;
            }
         } else {
            # we just do a regex that grabs the next line of output
            if ($output=~/(.*?)\n/sg) {
               $got_header=1;
               $header_row_content=$1;
               $debug && print "Storing Header Row:$header_row_content\n";

               # we just use split to break out the column titles
               @column_names=split(/$wmic_split_delimiter/,$1);
               $last_header_field_number=$#column_names;
               $debug && print "COLUMNS(last index=$last_header_field_number):$1\n";
               $$results[0][0]{'_ChecksOK'}++;
            }
         }
         
         if ($got_header) {
            # since we have the header titles we can now look for the data
            # just like the column titles the user might have specified a regex to find the fields
            # we do this because sometimes there are queries the return a different number of fields in the titles to the data
            # eg the page file query - 3 fields in the title and 5 fields in the data!
            #CLASS: Win32_OperatingSystem
            #FreePhysicalMemory|Name|TotalVisibleMemorySize
            #515204|Microsoft Windows XP Professional|C:\WINDOWS|\Device\Harddisk0\Partition1|1228272   
            my $use_split=1;
            my $field_finding_regex='(.*?)\n'; # this is the default
            my %keep_certain_fields=();
            if ($value_regex) {
               # $value_regex has 2 possibilities
               # 1) a comma delimited list of data field numbers to be kept eg 1,2,4
               # 2) a regular express to find the fields (still needed if the data contains \n)
               if ($value_regex=~/([\d,]+)/) {
                  # we will just use this regex to break up the fields
                  # FORMAT: NUM:FIELDLIST where FIELDLIST is a comma delimited list of field numbers we want to retrieve
                  # load up the hash that tells us which fields to keep
                  foreach my $field (split(',',$value_regex)) {
                     $keep_certain_fields{$field}=1;
                  }
                  # adjust the number of 
                  $debug && print "KEEP ONLY THESE FIELDS=$value_regex\n";
               } else {
                  # we assume that this is a regex
                  $field_finding_regex=$value_regex;
                  $use_split=0; # do not use the split
                  $debug && print "Using Custom Regex to find FIELDS\n";
               }
            }
            
            # now loop through the returned records
            $debug && print "Now looking for $field_finding_regex (use_split=$use_split)\n";
            my $found=0;
            my @field_data;
            while ($output=~/$field_finding_regex/sg) {
               # now we have matched a result row, so break it up into fields
               my $row_data_valid=1;
               my $row_data=$1; # this is the entire string matched (only works if $use_split=1)
               # use of $& slows down all program regexes - only turn this on if needed
               $debug && print "\nLooking at Data Row: $&";
               if ($use_split) {
                  @field_data=split(/$wmic_split_delimiter/,$row_data);
                  
                  # check that the row data looks valid
                  # to be valid
                  # 1) the row should have the same number of fields (it can be up to only 1 field less) as the header row (there have been reports that the CLASS: line and/or the header line repeats throughout the content
                  # 2) the row should not be the same as the header row (there have been reports that the header row sometimes repeats throughout the content)
                  # If we are using $value_regex to find the fields then all that goes out the window and we have to assume it is ok
                  # we allow it to be up to one field less because in some cases if the row data is like
                  # 1|2|3| and the 4th field is empty, the split actually only returns an array with 3 elements instead of 4
                  # checkdrivesize with drives that do not have volume names have this problem
                  # so to fix this the field count should be the same as the header row or only one less
                  if ( ($last_header_field_number-$#field_data<=1 && $row_data ne $header_row_content && $row_data ne $class_row_content) || $value_regex) {
                     my $header_field_number=0;
                     my $data_field_number=1; # these ones start from 1 since it makes it easier for the user to define - take care
                     $debug && print "FIELDS (via Split):";
                     foreach my $field (@field_data) {
                        my $use_field=1;
                        if ($value_regex && ! exists($keep_certain_fields{$data_field_number})) {
                           $debug && print "Drop Field #$data_field_number=$field\n";
                           $use_field=0;
                        }
                        if ($use_field) {
                           $debug && print "COLNAME=$column_names[$header_field_number],FIELD=$field\n";
                           # If you got the regex wrong or some fields come back with | in them you will get 
                           # "Use of uninitialized value within @column_names in hash element" error when using $column_names[$header_field_number]
                           # hence use $column_names[$header_field_number]||''

                           if ($the_arguments{'_convertslash'}) {
                              # convert \ to /
                              $field=~s/\\/\//g;
                           }

                           $$results[$i][$found]{$column_names[$header_field_number]||''}=$field;
                           # only increment the header field number when we use it 
                           $header_field_number++;
                        }
                        # always increment the data field number
                        $data_field_number++;
                     }
                  } else {
                     $row_data_valid=0;
                     $debug && print "Row data is not valid\n";
                  }
               } else {
                  my $j=0;
                  #------------------------------------------------------
                  # add more hardcoding here as needed - yuk - at some point we will use %+ - when enough people are on perl 5.10 or more
                  # this is the second of 2 places you need to change this hardcoding
                  # hopefully putting these to zero if they do not have any value will be ok, need a way to tell if $1 is '' or 0 really
                  @hardcoded_field_list=( $1||0,$2||0,$3||0,$4||0,$5||0,$6||0,$7||0,$8||0,$9||0 );
                  #------------------------------------------------------
                  $debug && print "FIELDS (via Hardcoding):";
                  foreach my $regex_field (@hardcoded_field_list) {
                     $debug && print "$regex_field, ";
                     if ($regex_field ne '') {
                        # If you got the regex wrong or some fields come back with | in them you will get 
                        # "Use of uninitialized value within @column_names in hash element" error when using $column_names[$j]
                        # hence use $column_names[$j]||''
                        $$results[$i][$found]{$column_names[$j]||''}=$regex_field;
                     }
                     $j++;
                  }
               }
               
               # only process and count as found if the row data is valid
               $debug && print "Row Data Valid = $row_data_valid\n";
               if ($row_data_valid) {
                  $debug && print "\n";
                  $debug && print "Row Data Found OK\n";
                  # provide Sums if the parameter is defined
                  foreach my $field_name (@{$provide_sums}) {
                     # we have to sum up all the fields named $field_name
                     # we can assume that they are numbers
                     # and we also assume that they are valid for this WMI query! ie that the programmer got it right!
                     # this first sum, sums up all the $field_name across all the queries for the Row Number $i
                     $debug && print "Summing for FIELD:\"$field_name\"\n";
                     $$results[0][$found]{"_QuerySum_$field_name"}+=$$results[$i][$found]{$field_name};
                     # this sum, sums up all the $field_names (columns) within a single query - ie where multiple rows are returned
                     $$results[$i][0]{"_ColSum_$field_name"}+=$$results[$i][$found]{$field_name};
                  }
                  # increment the results counter for this query
                  $found++;
               } else {
                  $debug && print "Probably an invalid row. Valid row test is $last_header_field_number-$#field_data<=1 && $row_data ne $header_row_content && $row_data ne $class_row_content\n";
               }
            }
            # record the number of rows found for this query
            $$results[$i][0]{'_ItemCount'}=$found;
         } else {
            $debug && print "Could not find the column title line\n";
            $failure++;
         }
         
      } else {
         $debug && print "Could not find the CLASS: line - an error occurred\n";
         $failure++;
      }
   }
      
   if ($i+1!=$num_samples) {
      # only need to sleep the first time round and its not the last
      $debug && print "Sleeping for $$specified_delay seconds ... ($i,$num_samples)\n";
      sleep $$specified_delay;
   }
   
}

$debug && print "WMI DATA:" . Dumper($results);

# if testing, any other output is now part of the script output
$test_generate && print "outputstring_${test_number}=<<EOT\n";

my $sub_result='';
if ($failure>0) {
   $sub_result=$all_output;
}

#$running_within_nagios
if ($keep_state_mode==1) {
   # done one WMI query and need to store it in the file for next time
   # check for wmi errors first
   check_for_data_errors($sub_result);
   # add a create timestamp to the data
   $debug && print "Storing WMI results in the state file for the first time\n";
   store_state_data($results);
   # now exit the plugin with an unknown state since we only have the first lot of WMI data
   $plugin_output.="Collecting first WMI sample because $get_data_for_the_first_time. Results will be shown the next time the plugin runs.\n";
   finish_program($ERRORS{'UNKNOWN'});
} elsif ($keep_state_mode==2) {
   # we retrieved WMI data this time round from the file
   # we then did one more WMI query to get a complete set
   # now we need to write the WMI data from the second query to the file for the next time the plugin runs
   # we have to munge the data a little first

   # check for wmi errors first
   check_for_data_errors($sub_result);

   my $stored_results;
   $$stored_results[0]=$$results[1];
   # now munge the data
   # we need to set a value for _ChecksOK, since there will not be one
   # we do this since we just took WMI query 1 and it will become WMI query 0 next plugin run and we will expect a value for _ChecksOK next run
   # each WMI query already has an ItemCount, if this is set to at least 1 then the query was ok
   if (defined($$stored_results[0][0]{'_ItemCount'})) {
      if ($$stored_results[0][0]{'_ItemCount'} ge 1) {
         $$stored_results[0][0]{'_ChecksOK'}=1; 
      }
   }
   $debug && print "Storing new WMI results in the state file " . Dumper($stored_results);
   store_state_data($stored_results);
}

# if $final_data_array_index is not zero then we have to copy some fields to the new index
# we wrote them to the 0 index since it was guaranteed to be in existence throughout the WMI query process
if ($final_data_array_index>0) {
   $debug && print "Copying predefined fields to the last WMI result set [0] to [$final_data_array_index]\n";

   # we want to move the following fields
   # _KeepStateCreateTimestamp
   # _KeepStateSamplePeriod
   # _ChecksOK
   # these ones are always in WMI Query #0 and in row #0
   $$results[$final_data_array_index][0]{'_ChecksOK'}=$$results[0][0]{'_ChecksOK'};
   $$results[$final_data_array_index][0]{'_KeepStateCreateTimestamp'}=$$results[0][0]{'_KeepStateCreateTimestamp'};
   $$results[$final_data_array_index][0]{'_KeepStateSamplePeriod'}=$$results[0][0]{'_KeepStateSamplePeriod'};

   # delete the old data just to make sure we are no longer using it in our code
   delete $$results[0][0]{'_ChecksOK'};
   delete $$results[0][0]{'_KeepStateCreateTimestamp'};
   delete $$results[0][0]{'_KeepStateSamplePeriod'};
   
   # Those first ones were easy since they are always in the same place
   # Now we want to get any _QuerySum fields
   # They are always in WMI query #zero as well but can be in each row of the result set, plus the field name starts with _QuerySum
   # we already know the fields that are being summed since they are stored in @{$provide_sums}
   # we drive this outside loop based on @{$provide_sums}, since if that is empty nothing will happen
   foreach my $field_name (@{$provide_sums}) {
      my $found=0;
      foreach my $row (@{$$results[0]}) {
         # grab the $field_name from array index [0][$found] and copy it to the last array index
         $debug && print "   Copying _QuerySum_$field_name ...\n";
         $$results[$final_data_array_index][$found]{"_QuerySum_$field_name"}=$$results[0][$found]{"_QuerySum_$field_name"};
         # delete the old data just to make sure we are no longer using it in our code
         delete $$results[0][$found]{"_QuerySum_$field_name"};
      }
   }

   $debug && print "NEW WMI DATA:" . Dumper($results);
}

return $sub_result,$final_data_array_index;
}
#-------------------------------------------------------------------------
sub store_state_data {
# pass in
# reference to what you want to store (which is a a WMI result set)
my ($results)=@_;
$$results[0][0]{'_KeepStateCreateTimestamp'}=time();
eval {   store($results,$keep_state_file);   };
check_for_store_errors($@);
}
#-------------------------------------------------------------------------
sub combine_display_and_perfdata {
my ($display,$perfdata)=@_;
# pass in
# a nagios display string
# a nagios performance data string
my $combined='';
# now build the combined string (we are providing multiple options for programming flexibility)
# we have to make sure that we follow these rules for performance data
# if there is a \n in the $display_string, place |PERFDATA just before it
# if there is no \n, place |PERFDATA at the end
# we'll try and improve this to make it a single regex - one day .....
#$debug && print "Building Combined Display/Perfdata ... ";
# look for an actual \n as a single ascii character
if ($display=~/\n/) {
   #$debug && print "Found LF\n";
   $combined=$display;
   # stick the perf data just before the \n
   $combined=~s/^(.*?)\n(.*)$/$1|$perfdata\n$2/s;

# now also look for an actual \ and an n ie 2 ascii characters. This can happen, for example, when \n is defined in the display= or predisplay= settings in an ini file
} elsif ($display=~/\\n/) {
   #$debug && print "Found embedded LF\n";
   $combined=$display;
   # stick the perf data just before the \n, make sure we are replacing the literal \n ie 2 ascii characters
   $combined=~s/^(.*?)\\n(.*)$/$1|$perfdata\n$2/s;
} else {
   #$debug && print "No LF\n";
   $combined="$display|$perfdata\n";
}

# if there is no perfdata | will be the last character - remove | if it is at the end
$combined=~s/\|$//;

if ($the_arguments{'_truncate_output'}) {
   my $output_length=length($combined);
   if ($output_length>$the_arguments{'_truncate_output'}) {
      $debug && print "Truncating output from $output_length bytes to $the_arguments{'_truncate_output'} bytes\n";
      $combined=substr($combined,0,$the_arguments{'_truncate_output'});
   }
}

#$debug && print "IN:$display|$perfdata\n";
$debug && print "OUT:$combined\n";
return $combined;
}
#-------------------------------------------------------------------------
sub create_display_and_performance_data {
# creates a standardised display for the results and performance data
# may not be totally suitable for all checks but should get most of them
my ($values,$display_fields,$performance_data_fields,$warning_specs,$critical_specs)=@_;
# pass in
# the values in a hash ref that you want to display/ create perf data for
# a list of the fields you actually want to display
# a list of the units matching the display fields
# a list of the fields you want to create perf data for
# a list of the units matching the perf data fields
# a hash of the warning specifications by field name
# a hash of the critical specifications by field name
my $display_string='';
my $performance_data_string='';
my $delimiter=', ';

# add the arguments hash into the incoming data values
foreach my $key (keys %the_arguments) {
   # their names should already be starting with _ to reduce the chance that they clash
   $$values{$key}=$the_arguments{$key};
}


# ------------------ create display data
$debug && print "---------- Building Up Display\n";
$debug && print "Incoming Data " . Dumper($values);
foreach my $field (@{$display_fields}) {
   $debug && print "------- Processing $field\n";
   my $this_delimiter=$delimiter;
   my $this_real_field_name='';
   my $this_display_field_name=''; # default display name
   my $this_sep='='; # default separator
   my $this_unit=''; # default display unit
   my $this_value=''; # default display value
   my $this_enclose='';
   my $this_start_bracket='';
   my $this_end_bracket='';

   # the field name comes in this format
   # 1) FIELD|UNITS|DISPLAY|SEP|DELIM|START|END
   # 2) FIELD|UNITS
   # 3) FIELD
   
   if ($field=~/^(.*)\|(.*)\|(.*)\|(.*)\|(.*)\|(.*)\|(.*)$/) {
      $debug && print "Complex Format:$1,$2,$3,$4,$5,$6,$7\n";
      $this_real_field_name=$1;
      $this_unit=$2;
      $this_display_field_name=$3 || $this_real_field_name;
      $this_sep=$4 || '=';
      $this_delimiter=$5 || $delimiter;
      $this_start_bracket=$6;
      $this_end_bracket=$7;

      # change ~ to nothing
      $this_display_field_name=~s/~//g;
      $this_sep=~s/~//g;
      $this_delimiter=~s/~//g;

   } elsif ($field=~/^(.*)\|(.*)$/) {
      $debug && print "Simple Format:$1,$2\n";
      $this_real_field_name=$1;
      $this_unit=$2;
      $this_display_field_name=$this_real_field_name;
      
   } elsif ($field!~/\|/) { # no | characters
      $debug && print "Field Only Format:$field\n";
      $this_real_field_name=$field;
      $this_display_field_name=$this_real_field_name;
      
   } else {
      print "Invalid Display FIELD Specification: $field\n";
   }

   {
      no warnings;
      # see if there are any "variables" in display name - they are enclosed in {} and match a key of the $value hash
      # eg this replaces {DeviceID} by the value held in $$values{'DeviceID'}
      $this_display_field_name=~s/\{(.*?)\}/$$values{$1}/g;
      $this_start_bracket=~s/\{(.*?)\}/$$values{$1}/g;
      $this_end_bracket=~s/\{(.*?)\}/$$values{$1}/g;
   }
  
   $debug>=2 && print "Loading up value using FIELD=$this_real_field_name\n";
   # now we can extract the value
   if (defined($$values{$this_real_field_name})) {
      $this_value=$$values{$this_real_field_name};
   } else {
      $this_value='NO_WMI_DATA';
   }
   
   # now see if we need to change the display value/unit
   # by default we expect this just to be UNIT
   # However, if prefixed with a # ie #UNIT eg #B, then we apply scaling to the UNIT
   if ($this_unit=~/^#(.*)$/) {
      # use the function to display the value and units
      $this_value=scaled_bytes($this_value);
      $this_unit=$1;
   }
   
   # apply static variable substituions if any on the values (this is a reverse subtitute to turn a value into a name)
   $use_pro_library && substitute_static_variables(1,\$this_value,$this_real_field_name);
   
   $debug && print "$field ----> $this_start_bracket$this_display_field_name$this_sep$this_value$this_unit$this_end_bracket$this_delimiter\n";
   $display_string.="$this_start_bracket$this_display_field_name$this_sep$this_value$this_unit$this_end_bracket$this_delimiter";
}
# remove the last delimiter
$display_string=~s/$delimiter$//;

# ------------------- create performance data
$debug && print "---------- Building Up Performance Data\n";
foreach my $field (@{$performance_data_fields}) {
   no warnings;
   $debug && print "------- Processing $field\n";
   my $this_real_field_name=$field;
   my $this_display_field_name=''; # default display name
   my $this_unit=''; # default display unit
   my $this_value=''; # default display value


   # the field name comes in this format
   # 1) FIELD|UNITS|DISPLAY
   # 2) FIELD|UNITS
   # 3) FIELD
   
   if ($field=~/^(.*)\|(.*)\|(.*)$/) {
      $debug && print "Complex Format:$1,$2,$3\n";
      $this_real_field_name=$1;
      $this_unit=$2;
      $this_display_field_name=$3;
      
   } elsif ($field=~/^(.*)\|(.*)$/) {
      $debug && print "Simple Format:$1,$2\n";
      $this_real_field_name=$1;
      $this_unit=$2;
      $this_display_field_name=$this_real_field_name;
      
   } elsif ($field!~/\|/) { # no | characters
      $debug && print "Field Only Format:$field\n";
      $this_real_field_name=$field;
      $this_display_field_name=$this_real_field_name;
   } else {
      print "Invalid Performance Data FIELD Specification: $field\n";
   }

   # see if there are any "variables" in display name - they are enclosed in {} and match a key of the $value hash
   # eg this replaces {DeviceID} by the value held in $$values{'DeviceID'}
   $this_display_field_name=~s/\{(.*?)\}/$$values{$1}/g;
   $this_unit=~s/\{(.*?)\}/$$values{$1}/g;
   
   # $debug && print "Loading up value using FIELD=$this_real_field_name\n";
   # now we can extract the value
   if (defined($$values{$this_real_field_name})) {
      $this_value=$$values{$this_real_field_name};
      if (looks_like_number($this_value)) {
         # now see if we need to change the display value/unit
         # by default we expect this just to be UNIT
         # However, if prefixed with a # ie #UNIT eg #B, then we apply scaling to the UNIT
         if ($this_unit=~/^#(.*)$/) {
            # use the function to display the value and units
            $this_value=scaled_bytes($this_value);
            $this_unit=$1;
         }
         
         # more protection against uninitialised variables!
         # in this case if you have a field specified for perf data which does not exist in the WMI class or fails to get calculated <---- I think that's the case
         # it also only happens if the field is specified as a performance data field AND not as a warn/critical field
         my $warn_perf_spec='';
         if (defined($$warning_specs{$this_real_field_name})) {
            $warn_perf_spec=$$warning_specs{$this_real_field_name};
         }
         my $crit_perf_spec='';
         if (defined($$critical_specs{$this_real_field_name})) {
            $crit_perf_spec=$$critical_specs{$this_real_field_name};
         }
   
         $debug && print "$field (Field=$this_real_field_name) ----> '$this_display_field_name'=$this_value$this_unit;$warn_perf_spec;$crit_perf_spec; \n";
         # we always add a space at the end of the performance data to make sure it is separated from any following performance data
         $performance_data_string.="'$this_display_field_name'=$this_value$this_unit;$warn_perf_spec;$crit_perf_spec; ";
      } else {
         # the perf data does not even look like a number so it may make the perf data handling software fail
         # so do not even bother including it
         $debug && print "Ignoring perf data since it is not numeric\n";
      }
   } else {
      $debug && print "Ignoring perf data since it has no value\n";
   }
}

# remove any trailing ;; from performance data so that it contains only the minimum required
$_=$performance_data_string;
# the performance data always ends in a one space since we added it a few lines above
# hence trailing ;; will be followed by a space and we need to maintain the space at the end
while ($performance_data_string=~s/;; /; /g) {}

$debug && print "---------- Done\n";

my $combined_string=combine_display_and_perfdata($display_string,$performance_data_string);
 
if ($opt_show_fields) {
   # user has asked to see all the fields that this check uses
   # this is normally only run when the user is tryigng to work out what fields they can use in a specific check
   # our best bet is to look in the hash $values
   print "Fields available/used in this check are:\n";
   print "========================================\n";
   printf("\%-30s %s\n",'FIELDNAME','SAMPLE VALUE');
   printf("\%-30s %s\n",'---------','------------');
   foreach my $key (sort keys %{$values}) {
      printf("\%-30s %s\n",$key,$$values{$key}||'');
   }
   print "\n";
}

return $display_string,$performance_data_string,$combined_string;
}
#-------------------------------------------------------------------------
sub no_data_check {
# controls how the plugin responds if no data is returned from the WMI query
# the plugin can exit in this sub
# pass in
# the number of items returned in the WMI query ie the value of _ItemCount
my ($itemcount)=@_;
if ($the_arguments{'_nodatamode'}) {
   # this means that the users wants to test eg ItemCount using warn/crit criteria 
   # so we will not do our default behaviour
   # default behaviour is to go warning/critical if the $itemcount==0 ie no data was returned
   # this might mean that some other values might not be initialised so you will need to initialise them within each check before you call this sub eg for checkfilesize the value of FileSize will not get set if we do not find the file
} else {
   # we have to go warning/critical if there is not data returned by the WMI query
   if ($itemcount eq '0') {
      # if there is a custom string defined then use that
      $plugin_output.=$the_arguments{'_nodatastring'};
      # we exit with the value the user specified in $the_arguments{'_nodataexit'}, if any
      if ($the_arguments{'_nodataexit'} ge 0 && $the_arguments{'_nodataexit'} le 3) {
         $debug && print "Exit with user defined exit code $the_arguments{'_nodataexit'}\n";
         finish_program($the_arguments{'_nodataexit'});
      } else {
         finish_program($ERRORS{'CRITICAL'});
      }
   }
}
}
#-------------------------------------------------------------------------
sub check_for_invalid_calculation_result {
# check calculated field results for validity
# pass in 
# a value by reference (so we can change it in place)
my ($result)=@_;
# sometimes on virtual machines, because of clock problems, it is possible to get negative numbers. Just make it zero.
if ($$result<0) {
   $debug && print " $$result - less than zero (possible hardware timing problem), forcing to ";
   $$result=0;
}
}
#-------------------------------------------------------------------------
sub calc_new_field {
no warnings;
# calculate new fields using "builtin" functions
# pass in
# the name of the new field
# the name of the function to perform
# a comma delimited list of parameters for the function (each function can vary)
# an array reference to the collected WMI data array
# the array index which points us to the array index of the WMI query that contains the last WMI query data. This is also where we should put the calculated results eg $$wmidata[WMI query index]
# the array index to the the returned WMI data row where we should extract the field data from  eg $$wmidata[xx][WMI Data Row]
my ($newfield,$function,$function_parameters,$wmidata,$query_index,$which_row)=@_;
# we poke the results back into row [0][$which_row] of the $wmidata array
# if $newfield clashes with something else then we overwrite it

# these functions are often used on WMI data from a "Win32_PerfRawData" class
$debug && print "Creating '$newfield' (WMIQuery:$query_index, Row:$which_row) using '$function' (Parameters: $function_parameters)\n";

# any of the function parameters may contain "variables" where we substitute argument into
# a variables looks like {SOMENAME}
# if we find one of these we substitute values from the hash %the_arguments
# eg {arg1} gets replaced by the value held in $the_arguments{'_arg1'}
# this is how we pass command line arguments into the calculations
$function_parameters=~s/\{(.*?)\}/$the_arguments{$1}/g;

# wrap all the calcs in an eval to catch any divide by zero errors, bit bit nicer than just dying
eval {

# functions can be some function name I define or we also use the WMI Raw data types eg PERF_100NSEC_TIMER_INV
if ($function eq 'PERF_100NSEC_TIMER_INV') {
   # refer http://technet.microsoft.com/en-us/library/cc757283%28WS.10%29.aspx
   # this is a calculation like for checkcpu found on 
   # it requires two completed WMI queries (sample=2)
   # Formula = (1- (   (N2 - N1) / (D2 - D1) /F   )) x 100
   # we assume that the Timefield (D) we need is Timestamp_Sys100NS
   # 
   # the parameters for this "function" are
   # SOURCEFIELD,SPRINTF_SPEC
   # where 
   # SOURCEFIELD [0] is the WMI Field to base this on eg PercentProcessorTime - required
   # SPRINTF_SPEC [1] - a format specification passed directly to sprintf to format the result (can leave blank)
   # MAXIMUM VALUE [2] - the maximum value that this "function" will return (optional)
   #
   my $final_result='CALC_FAIL';
   # this function requires exactly 2 WMI data results ie you should have done 2 WMI queries - if you did more that's your problem
   # check this first
   if ($$wmidata[$query_index][0]{'_ChecksOK'}>=2) {
      my @parameter=split(',',$function_parameters);
      if (looks_like_number($$wmidata[$query_index][$which_row]{$parameter[0]})) {
         $debug && print "Core Calc: (1 - ($$wmidata[$query_index][$which_row]{$parameter[0]} - $$wmidata[0][$which_row]{$parameter[0]}) / 
                           ($$wmidata[$query_index][$which_row]{Timestamp_Sys100NS} - $$wmidata[0][$which_row]{Timestamp_Sys100NS})  ) * 100 = ";
         $final_result=(1 - ($$wmidata[$query_index][$which_row]{$parameter[0]} - $$wmidata[0][$which_row]{$parameter[0]}) / 
                           ($$wmidata[$query_index][$which_row]{Timestamp_Sys100NS} - $$wmidata[0][$which_row]{Timestamp_Sys100NS})  ) * 100;
         check_for_invalid_calculation_result(\$final_result);
         $debug && print " $final_result\n";
         if (defined($parameter[2])) {
            if ($final_result>$parameter[2]) {
               $final_result=$parameter[2];
            }
         }
         if ($parameter[1]) {
            $final_result=sprintf($parameter[1],$final_result);
         }
      } else {
         $debug && print "WARNING: The value in the requested field ($parameter[0]) does not look like a number - we got '$$wmidata[$query_index][$which_row]{$parameter[0]}'\n";
      }
   } else {
      # not enough WMI data to return result
      $final_result='Need at least 2 WMI samples';
   }
   $debug && print "   Setting $newfield to $final_result\n";
   $$wmidata[$query_index][$which_row]{$newfield}=$final_result;
} elsif ($function eq 'PERF_100NSEC_TIMER') {
   # refer http://technet.microsoft.com/en-us/library/cc728274%28WS.10%29.aspx
   # it requires two completed WMI queries (sample=2)
   # Formula = (Nx - N0) / (Dx - D0) x 100
   # we assume that the Timefield (D) we need is Timestamp_Sys100NS
   # 
   # the parameters for this "function" are
   # SOURCEFIELD,SPRINTF_SPEC
   # where 
   # SOURCEFIELD [0] is the WMI Field to base this on eg PercentProcessorTime - required
   # SPRINTF_SPEC [1] - a format specification passed directly to sprintf to format the result (can leave blank)
   # MAXIMUM VALUE [2] - the maximum value that this "function" will return (optional)
   #
   my $final_result='CALC_FAIL';
   # this function requires exactly 2 WMI data results ie you should have done 2 WMI queries - if you did more that's your problem
   # check this first
   if ($$wmidata[$query_index][0]{'_ChecksOK'}>=2) {
      my @parameter=split(',',$function_parameters);
      if (looks_like_number($$wmidata[$query_index][$which_row]{$parameter[0]})) {
         $debug && print "Core Calc: (  ($$wmidata[$query_index][$which_row]{$parameter[0]} - $$wmidata[0][$which_row]{$parameter[0]}) / 
                           ($$wmidata[$query_index][$which_row]{Timestamp_Sys100NS} - $$wmidata[0][$which_row]{Timestamp_Sys100NS})  ) * 100 = ";
         $final_result=(  ($$wmidata[$query_index][$which_row]{$parameter[0]} - $$wmidata[0][$which_row]{$parameter[0]}) / 
                           ($$wmidata[$query_index][$which_row]{Timestamp_Sys100NS} - $$wmidata[0][$which_row]{Timestamp_Sys100NS})  ) * 100;
         check_for_invalid_calculation_result(\$final_result);
         $debug && print " $final_result\n";
         if (defined($parameter[2])) {
            if ($final_result>$parameter[2]) {
               $final_result=$parameter[2];
            }
         }
         if ($parameter[1]) {
            $final_result=sprintf($parameter[1],$final_result);
         }
      } else {
         $debug && print "WARNING: The value in the requested field ($parameter[0]) does not look like a number - we got '$$wmidata[$query_index][$which_row]{$parameter[0]}'\n";
      }
   } else {
      # not enough WMI data to return result
      $final_result='Need at least 2 WMI samples';
   }
   $debug && print "   Setting $newfield to $final_result\n";
   $$wmidata[$query_index][$which_row]{$newfield}=$final_result;
} elsif ($function eq 'PERF_COUNTER_COUNTER' || $function eq 'PERF_COUNTER_BULK_COUNT') {
   # refer http://technet.microsoft.com/en-us/library/cc740048%28WS.10%29.aspx
   # it requires two completed WMI queries (sample=2)
   # Formula = (Nx - N0) / ((Dx - D0) / F)
   # we assume that the Timefield (D) we need is Timestamp_Sys100NS
   # we assume that the Frequency (F) we need is Frequency_Sys100NS
   # 
   # the parameters for this "function" are
   # SOURCEFIELD,SPRINTF_SPEC
   # where 
   # SOURCEFIELD [0] is the WMI Field to base this on eg PercentProcessorTime - required
   # SPRINTF_SPEC [1] - a format specification passed directly to sprintf to format the result (can leave blank)
   #
   my $final_result='CALC_FAIL';
   # this function requires exactly 2 WMI data results ie you should have done 2 WMI queries - if you did more that's your problem
   # check this first
   if ($$wmidata[$query_index][0]{'_ChecksOK'}>=2) {
      my @parameter=split(',',$function_parameters);
      if (looks_like_number($$wmidata[$query_index][$which_row]{$parameter[0]})) {
         $debug && print "Core Calc: ($$wmidata[$query_index][$which_row]{$parameter[0]} - $$wmidata[0][$which_row]{$parameter[0]}) / 
                       (    ($$wmidata[$query_index][$which_row]{Timestamp_Sys100NS} - $$wmidata[0][$which_row]{Timestamp_Sys100NS})  /  $$wmidata[$query_index][$which_row]{Frequency_Sys100NS} ) = ";
         $final_result=($$wmidata[$query_index][$which_row]{$parameter[0]} - $$wmidata[0][$which_row]{$parameter[0]}) / 
                       (    ($$wmidata[$query_index][$which_row]{Timestamp_Sys100NS} - $$wmidata[0][$which_row]{Timestamp_Sys100NS})  /  $$wmidata[$query_index][$which_row]{Frequency_Sys100NS} ) ;
         check_for_invalid_calculation_result(\$final_result);
         $debug && print " $final_result\n";
         if ($parameter[1]) {
            $final_result=sprintf($parameter[1],$final_result);
         }
      } else {
         $debug && print "WARNING: The value in the requested field ($parameter[0]) does not look like a number - we got '$$wmidata[$query_index][$which_row]{$parameter[0]}'\n";
      }
   } else {
      # not enough WMI data to return result
      $final_result='Need at least 2 WMI samples';
   }
   $debug && print "   Setting $newfield to $final_result\n";
   $$wmidata[$query_index][$which_row]{$newfield}=$final_result;
} elsif ($function eq 'PERF_AVERAGE_TIMER') {
   # NOT YET TESTED
   # refer https://msdn.microsoft.com/en-us/library/ms804010.aspx?f=255&MSPPError=-2147217396
   # it requires two completed WMI queries (sample=2)
   # Formula = ((Nx - N0)/F ) / ((Dx - D0) )
   # we assume that the Timefield (D) we need is Timestamp_Sys100NS
   # we assume that the Frequency (F) we need is Frequency_Sys100NS
   # 
   # the parameters for this "function" are
   # SOURCEFIELD,SPRINTF_SPEC
   # where 
   # SOURCEFIELD [0] is the WMI Field to base this on eg PercentProcessorTime - required
   # SPRINTF_SPEC [1] - a format specification passed directly to sprintf to format the result (can leave blank)
   #
   my $final_result='CALC_FAIL';
   # this function requires exactly 2 WMI data results ie you should have done 2 WMI queries - if you did more that's your problem
   # check this first
   if ($$wmidata[$query_index][0]{'_ChecksOK'}>=2) {
      my @parameter=split(',',$function_parameters);
      if (looks_like_number($$wmidata[$query_index][$which_row]{$parameter[0]})) {
#         Old Calc which has the timestamp as the denominator - new calc inverts it
#         $debug && print "OLD Core Calc: ( ($$wmidata[$query_index][$which_row]{$parameter[0]} - $$wmidata[0][$which_row]{$parameter[0]}) / $$wmidata[$query_index][$which_row]{Frequency_Sys100NS} ) / 
#                       (    ($$wmidata[$query_index][$which_row]{Timestamp_Sys100NS} - $$wmidata[0][$which_row]{Timestamp_Sys100NS}) ) = ";
#         # old - maybe incorrect
#         $final_result=( ($$wmidata[$query_index][$which_row]{$parameter[0]} - $$wmidata[0][$which_row]{$parameter[0]})  /  $$wmidata[$query_index][$which_row]{Frequency_Sys100NS} )/ 
#                       (    ($$wmidata[$query_index][$which_row]{Timestamp_Sys100NS} - $$wmidata[0][$which_row]{Timestamp_Sys100NS}) ) ;
         # divide by zero protection
         $debug && print "Core Calc: ( ($$wmidata[$query_index][$which_row]{Timestamp_Sys100NS} - $$wmidata[0][$which_row]{Timestamp_Sys100NS})  /  $$wmidata[$query_index][$which_row]{Frequency_Sys100NS} )/ 
                       (    ($$wmidata[$query_index][$which_row]{$parameter[0]} - $$wmidata[0][$which_row]{$parameter[0]}) ) = ";
         if (  ($$wmidata[$query_index][$which_row]{$parameter[0]} - $$wmidata[0][$which_row]{$parameter[0]})==0  ) {
           $debug && print "Denominator is zero - cannot calculate result - forcing result to zero\n"; 
           $final_result=0;
         } else {
            $final_result=( ($$wmidata[$query_index][$which_row]{Timestamp_Sys100NS} - $$wmidata[0][$which_row]{Timestamp_Sys100NS})  /  $$wmidata[$query_index][$which_row]{Frequency_Sys100NS} )/ 
                       (    ($$wmidata[$query_index][$which_row]{$parameter[0]} - $$wmidata[0][$which_row]{$parameter[0]}) ) ;
         }
         check_for_invalid_calculation_result(\$final_result);
         $debug && print " $final_result\n";
         if ($parameter[1]) {
            $final_result=sprintf($parameter[1],$final_result);
         }
      } else {
         $debug && print "WARNING: The value in the requested field ($parameter[0]) does not look like a number - we got '$$wmidata[$query_index][$which_row]{$parameter[0]}'\n";
      }
   } else {
      # not enough WMI data to return result
      $final_result='Need at least 2 WMI samples';
   }
   $debug && print "   Setting $newfield to $final_result\n";
   $$wmidata[$query_index][$which_row]{$newfield}=$final_result;
} elsif ($function eq 'PERF_AVERAGE_BULK' || $function eq 'PERF_SAMPLE_FRACTION') {
   # NOT YET TESTED
   # refer https://msdn.microsoft.com/en-au/library/ms803755.aspx
   # it requires two completed WMI queries (sample=2)
   # Formula = N1 - N0 / D1 - D0
   #
   # the parameters for this "function" are
   # SOURCEFIELD_N,SOURCEFIELD_D,MULTIPLIER,SPRINTF_SPEC
   # where 
   # SOURCEFIELD [0] is the WMI Field to base this on eg PercentProcessorTime - required
   # SOURCEFIELD [1] is the WMI Field to base this on - required
   # MULTIPLIER [2] is a multiplier useful to make the fraction a percentage eg 100 - probably set to 1 for PERF_AVERAGE_BULK and set to 100 for PERF_SAMPLE_FRACTION
   # SPRINTF_SPEC [3] - a format specification passed directly to sprintf to format the result (can leave blank)
   #
   my $final_result='CALC_FAIL';
   # this function requires exactly 2 WMI data results ie you should have done 2 WMI queries - if you did more that's your problem
   # check this first
   if ($$wmidata[$query_index][0]{'_ChecksOK'}>=2) {
      my @parameter=split(',',$function_parameters);
      if (looks_like_number($$wmidata[$query_index][$which_row]{$parameter[0]}) && looks_like_number($$wmidata[$query_index][$which_row]{$parameter[1]})) {
         $debug && print "Core Calc: ($$wmidata[$query_index][$which_row]{$parameter[0]} - $$wmidata[0][$which_row]{$parameter[0]}) / 
                       ($$wmidata[$query_index][$which_row]{$parameter[1]} - $$wmidata[0][$which_row]{$parameter[1]}) = ";
         # divide by zero protection
         if (  ($$wmidata[$query_index][$which_row]{$parameter[1]} - $$wmidata[0][$which_row]{$parameter[1]})==0  ) {
           $debug && print "Denominator is zero - cannot calculate result - forcing result to zero\n"; 
           $final_result=0;
         } else {
            $final_result=($$wmidata[$query_index][$which_row]{$parameter[0]} - $$wmidata[0][$which_row]{$parameter[0]}) / 
                       ($$wmidata[$query_index][$which_row]{$parameter[1]} - $$wmidata[0][$which_row]{$parameter[1]});
         }
         check_for_invalid_calculation_result(\$final_result);
         $debug && print " $final_result\n";
         if ($parameter[2]) {
            $final_result=$final_result*$parameter[2];
         }
         if ($parameter[3]) {
            $final_result=sprintf($parameter[3],$final_result);
         }
      } else {
         $debug && print "WARNING: The value in the requested field ($parameter[0] or $parameter[1]) does not look like a number - we got '$$wmidata[$query_index][$which_row]{$parameter[0]}' and '$$wmidata[$query_index][$which_row]{$parameter[1]}'\n";
      }
   } else {
      # not enough WMI data to return result
      $final_result='Need at least 2 WMI samples';
   }
   $debug && print "   Setting $newfield to $final_result\n";
   $$wmidata[$query_index][$which_row]{$newfield}=$final_result;
} elsif ($function eq 'PERF_PRECISION_100NS_TIMER' || $function eq 'PERF_COUNTER_100NS_QUEUELEN_TYPE') {
   # refer http://technet.microsoft.com/en-us/library/cc756128%28WS.10%29.aspx
   # it requires two completed WMI queries (sample=2)
   # Formula = N1 - N0 / D1 - D0
   # we assume that the Timefield (D) we need is Timestamp_Sys100NS
   #
   # REfer http://technet.microsoft.com/en-us/library/cc781696%28WS.10%29.aspx for PERF_COUNTER_100NS_QUEUELEN_TYPE
   # This one seems to give correct results calculated like this but has a slightly different formula on the reference page?
   # 
   # the parameters for this "function" are
   # SOURCEFIELD,MULTIPLIER,SPRINTF_SPEC
   # where 
   # SOURCEFIELD [0] is the WMI Field to base this on eg PercentProcessorTime - required
   # SPRINTF_SPEC [1] - a format specification passed directly to sprintf to format the result (can leave blank)
   # MULTIPLIER [2] is a multiplier useful to make the fraction a percentage eg 100
   # INVERT [3] take the value away from this number. Useful in the following example eg set this value to 100 to show busy percentage where counter value is an idle percentage. Applied after the multiplier
   #
   my $final_result='CALC_FAIL';
   # this function requires exactly 2 WMI data results ie you should have done 2 WMI queries - if you did more that's your problem
   # check this first
   if ($$wmidata[$query_index][0]{'_ChecksOK'}>=2) {
      my @parameter=split(',',$function_parameters);
      if (looks_like_number($$wmidata[$query_index][$which_row]{$parameter[0]})) {
         $debug && print "Core Calc: ($$wmidata[$query_index][$which_row]{$parameter[0]} - $$wmidata[0][$which_row]{$parameter[0]}) / 
                       ($$wmidata[$query_index][$which_row]{Timestamp_Sys100NS} - $$wmidata[0][$which_row]{Timestamp_Sys100NS}) = ";
         $final_result=($$wmidata[$query_index][$which_row]{$parameter[0]} - $$wmidata[0][$which_row]{$parameter[0]}) / 
                       ($$wmidata[$query_index][$which_row]{Timestamp_Sys100NS} - $$wmidata[0][$which_row]{Timestamp_Sys100NS});
         check_for_invalid_calculation_result(\$final_result);
         $debug && print " $final_result\n";
         if ($parameter[2]) {
            $final_result=$final_result*$parameter[2];
         }
         if ($parameter[3]) {
            $final_result=$parameter[3]-$final_result;
         }
         if ($parameter[1]) {
            $final_result=sprintf($parameter[1],$final_result);
         }
      } else {
         $debug && print "WARNING: The value in the requested field ($parameter[0]) does not look like a number - we got '$$wmidata[$query_index][$which_row]{$parameter[0]}'\n";
      }
   } else {
      # not enough WMI data to return result
      $final_result='Need at least 2 WMI samples';
   }
   $debug && print "   Setting $newfield to $final_result\n";
   $$wmidata[$query_index][$which_row]{$newfield}=$final_result;
} elsif ($function eq 'PERF_ELAPSED_TIME') {
   # refer http://technet.microsoft.com/en-us/library/cc756820%28WS.10%29.aspx
   # it requires one completed WMI queries (sample=2)
   # Formula = (D0 - N0) / F
   # we assume that the Timefield (D) we need is Timestamp_Object (Timestamp_Sys100NS seemed to be strange on Server 2003 for doing uptime in Class Win32_PerfRawData_PerfOS_System)
   # we assume that the Frequency (F) we need is Frequency_Sys100NS
   #
   # the parameters for this "function" are
   # SOURCEFIELD,SPRINTF_SPEC
   # where 
   # SOURCEFIELD [0] is the WMI Field to base this on eg PercentProcessorTime - required
   # SPRINTF_SPEC [1] - a format specification passed directly to sprintf to format the result (can leave blank)
   #
   my $final_result='CALC_FAIL';
   # this function requires only 1 WMI data result set. don't worry about checking it
   my @parameter=split(',',$function_parameters);
   if (looks_like_number($$wmidata[$query_index][$which_row]{$parameter[0]})) {
      $debug && print "Core Calc: ($$wmidata[$query_index][$which_row]{Timestamp_Sys100NS} - $$wmidata[$query_index][$which_row]{$parameter[0]}) / 
                    $$wmidata[$query_index][$which_row]{Timestamp_Object} = ";
      $final_result=($$wmidata[$query_index][$which_row]{Timestamp_Object} - $$wmidata[$query_index][$which_row]{$parameter[0]}) / 
                    $$wmidata[$query_index][$which_row]{Frequency_Sys100NS};
      check_for_invalid_calculation_result(\$final_result);
      $debug && print " $final_result\n";
      if ($parameter[1]) {
         $final_result=sprintf($parameter[1],$final_result);
      }
   } else {
      $debug && print "WARNING: The value in the requested field ($parameter[0]) does not look like a number - we got '$$wmidata[$query_index][$which_row]{$parameter[0]}'\n";
   }
   $debug && print "   Setting $newfield to $final_result\n";
   $$wmidata[$query_index][$which_row]{$newfield}=$final_result;
} elsif ($function eq 'percent') {
   # it requires one completed WMI queries 
   # the parameters for this "function" are
   # SOURCEFIELD1,SOURCEFIELD2,SPRINTF_SPEC
   # where 
   # SOURCEFIELD1 [0] is a WMI field name which contains some number
   # SOURCEFIELD2 [1] is a WMI field name which contains some number
   # SPRINTF_SPEC [2] - a format specification passed directly to sprintf to format the result (can leave blank)
   # INVERT [3] take the resulting value away from this number. Useful in the following example eg set this value to 100 to show busy percentage where counter value is an idle percentage.
   # Formula is 100 * SOURCEFIELD1/SOURCEFIELD2
   #
   my $final_result='CALC_FAIL';
   # this function requires only 1 WMI data result set. don't worry about checking it
   my @parameter=split(',',$function_parameters);
   if (looks_like_number($$wmidata[$query_index][$which_row]{$parameter[0]}) && looks_like_number($$wmidata[$query_index][$which_row]{$parameter[1]})) {
      $debug && print "Core Calc: 100 * ($$wmidata[$query_index][$which_row]{$parameter[0]} / $$wmidata[$query_index][$which_row]{$parameter[1]}) = ";
      # protect against divide by zero - if you get one you will get a CALC_FAIL result
      if ($$wmidata[$query_index][$which_row]{$parameter[1]} != 0) {
         $final_result=100 * ($$wmidata[$query_index][$which_row]{$parameter[0]} / $$wmidata[$query_index][$which_row]{$parameter[1]});
         $debug && print " $final_result\n";
         if ($parameter[3]) {
            $final_result=$parameter[3]-$final_result;
         }
         if ($parameter[2]) {
            $final_result=sprintf($parameter[2],$final_result);
         }
      }
   } else {
      $debug && print "WARNING: The value in one of the requested fields ($parameter[0] or $parameter[1]) does not look like a number - we got '$$wmidata[$query_index][$which_row]{$parameter[0]}' and '$$wmidata[$query_index][$which_row]{$parameter[1]}'\n";
   }
   $debug && print "   Setting $newfield to $final_result\n";
   $$wmidata[$query_index][$which_row]{$newfield}=$final_result;
} elsif ($function eq 'basicmaths') {
   # it requires one completed WMI queries 
   # the parameters for this "function" are
   # SOURCEFIELD1,OPERATOR,SOURCEFIELD2,SPRINTF_SPEC
   # where 
   # SOURCEFIELD1 [0] is a WMI field name which contains some number or just a number 
   # OPERATOR     [1] is one of + - * /
   # SOURCEFIELD2 [2] is a WMI field name which contains some number or just a number 
   # SPRINTF_SPEC [3] - a format specification passed directly to sprintf to format the result (can leave blank)
   # Formula is SOURCEFIELD1 OPERATOR SOURCEFIELD2
   # eg 2 * 3
   #
   my $final_result='CALC_FAIL';
   # this function requires only 1 WMI data result set. don't worry about checking it
   my @parameter=split(',',$function_parameters);

   my $first_value=$parameter[0];
   my $second_value=$parameter[2];
   if (!looks_like_number($first_value)) {
      # assume it is actually a WMI field name and so use the value in the field
      $first_value=$$wmidata[$query_index][$which_row]{$parameter[0]};
      $debug && print "BasicMaths: Assuming that the specified value ($parameter[0]) is actually a WMI Field name and hence using the value '$first_value' for the calculation\n";
   }
   if (!looks_like_number($second_value)) {
      # assume it is actually a WMI field name and so use the value in the field
      $second_value=$$wmidata[$query_index][$which_row]{$parameter[2]};
      $debug && print "BasicMaths: Assuming that the specified value ($parameter[2]) is actually a WMI Field name and hence using the value '$second_value' for the calculation\n";
   }
   
   if (looks_like_number($first_value) && looks_like_number($second_value)) {
      $debug && print "Core Calc: $first_value $parameter[1] $second_value = ";
      if ($parameter[1] eq '+') {
         $final_result=$first_value + $second_value;
      } elsif ($parameter[1] eq '-') {
         $final_result=$first_value - $second_value;
      } elsif ($parameter[1] eq '*') {
         $final_result=$first_value * $second_value;
      } elsif ($parameter[1] eq '/' && $second_value != 0) {
         $final_result=$first_value / $second_value;
      }
      $debug && print " $final_result\n";
      if ($parameter[3]) {
         $final_result=sprintf($parameter[3],$final_result);
      }
   } else {
      $debug && print "WARNING: The value in one of the requested fields ($parameter[0] or $parameter[2]) does not look like a number - we got '$first_value' and '$second_value'\n";
   }
   $debug && print "   Setting $newfield to $final_result\n";
   $$wmidata[$query_index][$which_row]{$newfield}=$final_result;
} elsif ($function eq 'v_real32tofloat') {
   # it requires one completed WMI queries 
   # the parameters for this "function" are
   # SOURCEFIELD1,SPRINTF_SPEC
   # where 
   # SOURCEFIELD1 [0] is a WMI field name which contains some number or just a number 
   # SPRINTF_SPEC [1] - a format specification passed directly to sprintf to format the result (can leave blank)
   #
   my $final_result='CALC_FAIL';
   # this function requires only 1 WMI data result set. don't worry about checking it
   my @parameter=split(',',$function_parameters);

   my $first_value=$parameter[0];
   if (!looks_like_number($first_value)) {
      # assume it is actually a WMI field name and so use the value in the field
      $first_value=$$wmidata[$query_index][$which_row]{$parameter[0]};
      $debug && print "v_real32tofloat: Assuming that the specified value ($parameter[0]) is actually a WMI Field name and hence using the value '$first_value' for the calculation\n";
   }
   
   if (looks_like_number($first_value)) {
      $debug && print "Core Calc: v_real32tofloat $first_value = ";
      $final_result=unpack "f", pack "L", $first_value;
      $debug && print " $final_result\n";
      if ($parameter[1]) {
         $final_result=sprintf($parameter[1],$final_result);
      }
   } else {
      $debug && print "WARNING: The value in one of the requested fields ($parameter[0]) does not look like a number - we got '$first_value'\n";
   }
   $debug && print "   Setting $newfield to $final_result\n";
   $$wmidata[$query_index][$which_row]{$newfield}=$final_result;
} elsif ($function eq 'WMITimestampToAgeSec') {
   # it requires one completed WMI query
   # the parameters for this "function" are
   # SOURCEFIELD1
   # where 
   # SOURCEFIELD1 [0] is a WMI timestamp like 20100528105127.000000+600
   # This timestamp is a GMT time, we convert it to an age in seconds
   #
   my $final_result='CALC_FAIL';
   # this function requires only 1 WMI data result set. don't worry about checking it
   my @parameter=split(',',$function_parameters);
   my ($timestamp_sec,$age)=convert_WMI_timestamp_to_seconds($$wmidata[$query_index][$which_row]{$parameter[0]});
   if ($timestamp_sec ne '') {
      $final_result=$age;
      $debug && print " $final_result\n";
   } else {
      $debug && print "WARNING: Could not convert the WMI timestamp field ($parameter[0]) with a value of '$$wmidata[$query_index][$which_row]{$parameter[0]}' to a number of seconds\n";
   }
   $debug && print "   Setting $newfield to $final_result\n";
   $$wmidata[$query_index][$which_row]{$newfield}=$final_result;
} elsif ($function eq 'SectoDay') {
   # converts a number of seconds to days
   # it requires one completed WMI query
   # the parameters for this "function" are
   # SOURCEFIELD1,SPRINTF_SPEC
   # where 
   # SOURCEFIELD1 [0] is a number of seconds
   # SPRINTF_SPEC [1] - a format specification passed directly to sprintf to format the result (can leave blank)
   #
   my $final_result='CALC_FAIL';
   # this function requires only 1 WMI data result set. don't worry about checking it
   my @parameter=split(',',$function_parameters);
   if (looks_like_number($$wmidata[$query_index][$which_row]{$parameter[0]})) {
      $debug && print "Core Calc: $$wmidata[$query_index][$which_row]{$parameter[0]}/86400 = ";
      $final_result=$$wmidata[$query_index][$which_row]{$parameter[0]}/86400;
      $debug && print " $final_result\n";
      if ($parameter[1]) {
         $final_result=sprintf($parameter[1],$final_result);
      }
   } else {
      $debug && print "WARNING: The value in the requested field ($parameter[0]) does not look like a number - we got '$$wmidata[$query_index][$which_row]{$parameter[0]}'\n";
   }
   $debug && print "   Setting $newfield to $final_result\n";
   $$wmidata[$query_index][$which_row]{$newfield}=$final_result;
} elsif ($function eq 'KBtoB') {
   # converts a number of kilo bytes to bytes - then we can use our standard scaling routine on the number for a nicer display
   # BYTEFACTOR is used in this calculation
   # it requires one completed WMI query
   # the parameters for this "function" are
   # SOURCEFIELD1,SPRINTF_SPEC
   # where 
   # SOURCEFIELD1 [0] is a number of KB
   # SPRINTF_SPEC [1] - a format specification passed directly to sprintf to format the result (can leave blank)
   #
   my $final_result='CALC_FAIL';
   # this function requires only 1 WMI data result set. don't worry about checking it
   my @parameter=split(',',$function_parameters);
   if (looks_like_number($$wmidata[$query_index][$which_row]{$parameter[0]})) {
      $debug && print "Core Calc: $$wmidata[$query_index][$which_row]{$parameter[0]}*$actual_bytefactor = ";
      $final_result=$$wmidata[$query_index][$which_row]{$parameter[0]}*$actual_bytefactor;
      $debug && print " $final_result\n";
      if ($parameter[1]) {
         $final_result=sprintf($parameter[1],$final_result);
      }
   } else {
      $debug && print "WARNING: The value in the requested field ($parameter[0]) does not look like a number - we got '$$wmidata[$query_index][$which_row]{$parameter[0]}'\n";
   }
   $debug && print "   Setting $newfield to $final_result\n";
   $$wmidata[$query_index][$which_row]{$newfield}=$final_result;
} elsif ($function eq 'HYPERV_TOTALVM_MEMORY') {
   # used for calculating HyperV memory
   # customfield=_almost_total_vm_memory,HYPERV_TOTALVM_MEMORY,Value1GGPApages,Value2MGPApages,Value4KGPApages,DepositedPages 
   # select Name,Value1GGPApages,Value2MGPApages,Value4KGPApages,DepositedPages from Win32_PerfRawData_HvStats_HyperVHypervisorPartition 
   # it requires 1 completed WMI queries (sample=1)
   # almost_total_vm_memory = "1G GPA Pages" * 1024 + ("2M GPA Pages" * 2) + (("4K GPA Pages" + "Deposited pages") / 256)
   # 
   # the parameters for this "function" are
   # Value1GGPApages,Value2MGPApages,Value4KGPApages,DepositedPages,SPRINTF_SPEC
   # where 
   # Value1GGPApages [0] is the WMI Field for 1G pages - required
   # Value2MGPApages [1] is the WMI Field for 2M pages - required
   # Value4KGPApages [2] is the WMI Field for 4K pages - required
   # DepositedPages  [3] is the WMI Field for Deposited pages - required
   # SPRINTF_SPEC [4] - a format specification passed directly to sprintf to format the result (can leave blank)
   #
   my $final_result='CALC_FAIL';
   my @parameter=split(',',$function_parameters);
   if (looks_like_number($$wmidata[$query_index][$which_row]{$parameter[0]})) {
      $debug && print "Core Calc: $$wmidata[$query_index][$which_row]{$parameter[0]} * 1024 + 
                     ($$wmidata[$query_index][$which_row]{$parameter[1]} * 2) + 
                     (($$wmidata[$query_index][$which_row]{$parameter[2]} + $$wmidata[$query_index][$which_row]{$parameter[3]}) / 256) = ";
      $final_result=$$wmidata[$query_index][$which_row]{$parameter[0]} * 1024 + 
                     ($$wmidata[$query_index][$which_row]{$parameter[1]} * 2) + 
                     (($$wmidata[$query_index][$which_row]{$parameter[2]} + $$wmidata[$query_index][$which_row]{$parameter[3]}) / 256);
      $debug && print " $final_result\n";
      if ($parameter[4]) {
         $final_result=sprintf($parameter[4],$final_result);
      }
   } else {
      $debug && print "WARNING: The value in the requested field ($parameter[0]) does not look like a number - we got '$$wmidata[$query_index][$which_row]{$parameter[0]}'\n";
   }
   $debug && print "   Setting $newfield to $final_result\n";
   $$wmidata[$query_index][$which_row]{$newfield}=$final_result;
} elsif ($function eq 'test') {
   # it requires one completed WMI queries 
   # the parameters for this "function" are
   # SOURCEFIELD1SPRINTF_SPEC
   # where 
   # SOURCEFIELD1 [0] is some number
   # Formula is 1 * SOURCEFIELD1
   #
   my $final_result='';
   # this function requires only 1 WMI data result set. don't worry about checking it
   my @parameter=split(',',$function_parameters);
   if (looks_like_number($parameter[0])) {
      $debug && print "Core Calc: 1 * $$wmidata[$query_index][$which_row]{$parameter[0]} = ";
      $final_result=1 * $$wmidata[$query_index][$which_row]{$parameter[0]};
      $debug && print " $final_result\n";
   } else {
      $debug && print "WARNING: The value '$parameter[0]' does not look like a number\n";
   }
   if ($parameter[2]) {
      $final_result=sprintf($parameter[2],$final_result);
   }
   $debug && print "   Setting $newfield to $final_result\n";
   $$wmidata[$query_index][$which_row]{$newfield}=$final_result;
} else {
   print "ERROR: Invalid function '$function' specified for calculating custom fields\n";
}

}; # end of eval
if ($@) {
   # some calc got an error
   if ($@=~/division by zero/) {
      if ($opt_use_cached_wmic_response || $use_cached_wmic_responses) {
         print "Divide by Zero error. This is a direct result of using cached WMIC responses. This particular check requires different WMI data to work correctly.";
      } else {
         print "Divide by Zero error. Sometimes this happens if you are using a Win32_PerfFormattedData class when you should be using a Win32_PerfRAWData class (this check will continually get this error). It can also happen if the 2nd WMI query, for a check that requires 2 WMI queries, fails (this might be a transient problem). Also, you might have forgotten to include a time-based field (eg Timestamp_Sys100NS, Frequency_Sys100NS), which is required for the calculation, in your WMI query.";
      }
   }
   $plugin_output.="The actual error text is: $@ ";
   finish_program($ERRORS{'UNKNOWN'});
}

}
#-------------------------------------------------------------------------
sub process_custom_fields_list {
# run through a list of custom field parameters from an ini file and create the values requested
# pass in 
# an array of values from the ini file
# the wmi data array @collected_data
# 0 if we are not to process each row - but only process row 0
# array index into the wmi data (also the last index)
my ($list,$wmidata,$process_each_row,$last_wmi_data_index)=@_;

my $num_rows_in_last_wmi_result=$#{$$wmidata[$last_wmi_data_index]};

if ($process_each_row eq '0') {
   $num_rows_in_last_wmi_result=0;
}

$debug && print "customfield definitions in this section: " . Dumper($list);
foreach my $item (@{$list}) {
   # old version of config::inifiles set the array to a single undefined value - we have to test for it
   if (defined($item)) {
      $debug && print "Creating Custom Field for $item\n";
      # the format of this field is
      # NEWFIELDNAME,FUNCTION,FUNCTIONPARAMETERS
      # where FUNCTIONPARAMETERS itself is a comma delimited list
      # we want to split it into the 3 fields
      if ($item=~/(.*?),(.*?),(.*)/) {
         # $1 is the NEWFIELDNAME
         # $2 is the FUNCTION
         # $3 is the FUNCTIONPARAMETERS
         
         # look at query number $last_wmi_data_index and then process each row in that query
         for (my $i=0;$i<=$num_rows_in_last_wmi_result;$i++) {
            calc_new_field($1,$2,$3,$wmidata,$last_wmi_data_index,$i);
         }
      } else {
         print "WARNING: Could not correctly parse \"customfield\" definition in ini file: $item (for $opt_mode)\n";
      }
   }
}
}
#-------------------------------------------------------------------------
sub process_custom_lists {
# run through a list of custom field parameters from an ini file and create the values requested
# pass in 
# an array of values from the ini file
# the wmi data array @collected_data
# array index into the wmi data
my ($list,$wmidata,$last_wmi_data_index)=@_;

$debug && print "createlist definitions in this section: " . Dumper($list);
foreach my $item (@{$list}) {
   # old version of config::inifiles set the array to a single undefined value - we have to test for it
   if (defined($item)) {
      $debug && print "Creating Custom List for $item\n";
      # the format of this field is
      #      1           2         3         4          5
      # NEWFIELDNAME|LINEDELIM|FIELDDELIM|UNIQUE|FIELD1,FIELD2,etc
      # we want to split it into the fields
      if ($item=~/^(.*?)\|(.*?)\|(.*?)\|(.*?)\|(.*?)$/) {
         # $5 must be turned into an array
         my $newfield=$1;
         my $linedelim=$2;
         my $fielddelim=$3;
         my $unique=$4;
         my $sourcefields=$5;
         my @fieldlist=split(',',$sourcefields);
         #print "$newfield,$linedelim,$fielddelim,$unique and $sourcefields=" . Dumper(\@fieldlist);
         $$wmidata[$last_wmi_data_index][0]{$newfield}=list_collected_values_from_all_rows($wmidata,\@fieldlist,$linedelim,$fielddelim,$unique);
         #print "   Set to: $$wmidata[$last_wmi_data_index][0]{$newfield}\n";
      } else {
         print "WARNING: Could not correctly parse \"createlist\" definition in ini file: $item (for $opt_mode)\n";
      }
   }
}
}
#-------------------------------------------------------------------------
sub process_queryextension_fields_list {
# enhance the query with queryextensions
# pass in 
# the query
# array reference to the query extensions from the ini file
my ($query,$queryextension)=@_;

my $new_query=$query;
$debug && print "Query Extensions: " . Dumper($queryextension);
foreach my $qe (@{$queryextension}) {
   if (defined($qe)) {
      $debug && print "Processing QueryExtension: $qe\n";
      # parse it 
      # Format - NAME|SUBSTRING|ARG|REGEX|DEFAULT
      if ($qe=~/^(.*?)\|(.*?)\|(.*?)\|(.*?)\|(.*?)$/) {
         my $name=$1;
         my $substring=$2;
         my $arg=$3;
         my $regex=$4;
         my $default=$5;
         
         # set the default arg value
         my $arg_value=$default;
         my $use_default=1;
         
         # look in %the_arguments to see if the argument is defined and has a value
         if (defined($the_arguments{$arg})) {
            if ($the_arguments{$arg} ne '') {
               # see if the argument value matches the test value
               if ($the_arguments{$arg}=~/$regex/i) {
                  $arg_value=$the_arguments{$arg};
                  $debug && print "   $arg matches regex: $regex\n";
                  $use_default=0;
               } else {
                  # does not match regex so use no value
                  $debug && print "   $arg DOES NOT match regex: $regex\n";
               }
            }
         }
         
         # if there is an arg value then use this extension
         $debug && print "   Using Arg Value of \"$arg_value\"\n";
         if ($arg_value eq 'NOTUSED') {
            # the default of NOTUSED means that we will not use $name and will set it to blank
            $debug && print "   Removing $name from query\n";
            $new_query=~s/$name//g;
         } elsif ($use_default) {
            $debug && print "   Using default value - Substituting $default for $name\n";
            # now do the substitution into the query
            $new_query=~s/$name/$default/g;
         } elsif ($arg_value ne '') {
            $debug && print "   Substituting $substring for $name\n";
            # now do the substitution into the query
            $new_query=~s/$name/$substring/g;
         }
         
      } else {
         print "WARNING: Could not correctly parse \"queryextension\" definition in ini file: $qe (for $opt_mode)\n";
      }

   }
}

$debug && print "   Original Query:$query\n        New Query:$new_query\n";
return $new_query;
}
#-------------------------------------------------------------------------
sub check_for_store_errors {
# pass in 
# the output of the eval ie $@
my ($data_errors)=@_;
if ($data_errors) {
   $plugin_output.="UNKNOWN - ";
   if ($data_errors=~/Permission denied/i) {
      $plugin_output.="Permission denied when trying to store the state data. Sometimes this happens if you have been testing the plugin from the command line as a different user to the Nagios process user. You will need to change the permissions on the file or remove it. ";
   } else {
      $plugin_output.="There was an error while trying to store the state data. ";
   }
   $plugin_output.="The actual error text is: $data_errors";
   finish_program($ERRORS{'UNKNOWN'});
}
}
#-------------------------------------------------------------------------
sub check_for_data_errors {
# pass in 
# the output of the wmi query sub
my ($data_errors)=@_;
if ($data_errors) {
   $plugin_output.="UNKNOWN - The WMI query had problems.";
   if ($data_errors=~/NT_STATUS_ACCESS_DENIED/i) {
      my $extra_msg='';
      if ($opt_auth_file) {
         $extra_msg=" Your Authentication File might be incorrectly formatted or inaccessible. ";
      }
      $plugin_output.=" You might have your username/password wrong or the user's access level is too low. ${extra_msg}Wmic error text on the next line.\n";
   } elsif ($data_errors=~/0x80041010/i) {
      $plugin_output.=" The plugin is having trouble finding the required WMI Classes on the target host ($the_arguments{_host}). There can be multiple reasons for this (please go through them and check) including permissions problems (try using an admin login) or software that creates the class is not installed (eg if you are trying to checkiis but IIS is not installed). It can also happen if your version of Windows does not support this check (this might be because the WMI fields are named differently in different Windows versions or your version of Windows does not even have the required WMI class). Sometimes, some systems 'lose' WMI Classes and you might need to rebuild your WMI repository. Sometimes the WMI service is not running, other times a reboot can fix it. Other causes include mistyping the WMI namesspace/class/fieldnames. There may be other causes as well. You can use wmic from the command line to troubleshoot. Wmic error text on the next line.\n";
   } elsif ($data_errors=~/0x8007000e/i) { 
      $plugin_output.=" We're not exactly sure what this error is. When we've seen it, it only seems to affect checks of services. Restarting the WMI service can fix it. A reboot can fix it as well. If you can tell us more about this error contact us via www.edcint.co.nz/checkwmiplus. Wmic error text on the next line.\n";
   } elsif ($data_errors=~/0x80041003/i) { 
      $plugin_output.=" This is most likely a WMI permissions error. The process trying to access the WMI namespace most likely does not have the correct WMI permissions. The following link is believed to be relevant for Windows Server 2003, 2008R2 and 2012R2 - http://support.microsoft.com/kb/907460. Wmic error text on the next line.\n";
   } elsif ($data_errors=~/0x80041004/i) { 
      $plugin_output.=" We're not exactly sure what this error is. When we've seen it, it only seems to affect checks of processes. Restarting the WMI service can fix it. A reboot can fix it as well. If you can tell us more about this error contact us via www.edcint.co.nz/checkwmiplus. Wmic error text on the next line.\n";
   } elsif ($data_errors=~/0x80041045/i) { 
      $plugin_output.=" We're not exactly sure what this error is. Restarting the WMI service can fix it. A reboot can fix it as well. If you can tell us more about this error contact us via www.edcint.co.nz/checkwmiplus. Wmic error text on the next line.\n";
   } elsif ($data_errors=~/0x80041045/i) { 
      $plugin_output.=" We're not exactly sure what this error is. Restarting the WMI service can fix it. A reboot can fix it as well. If you can tell us more about this error contact us via www.edcint.co.nz/checkwmiplus. Wmic error text on the next line.\n";
   } elsif ($data_errors=~/0x800706ba|c00000b5/i) { 
      $plugin_output.="  This error can appear when the Windows firewall on the target machine is blocking the connection. There may be other causes. Wmic error text on the next line.\n";
   } elsif ($data_errors=~/0x800705af/i) { 
      # error reported by toni.garcia@sistel.es
      $plugin_output.="  This error appears to mean that the paging file is too small for this operation to complete, but if there sufficient paging space, you can reboot the $the_arguments{_host} as a workaround.\n. If you can tell us more about this error contact us via www.edcint.co.nz/checkwmiplus. Wmic error text on the next line.\n";
   } elsif ($data_errors=~/NT_STATUS_IO_TIMEOUT/i) {
      $plugin_output.=" The target host ($the_arguments{_host}) might not be reachable over the network. Is it down? Is $the_arguments{_host} the correct hostname?. The host might even be up but just too busy. Wmic error text on the next line.\n";
   } elsif ($data_errors=~/NT_STATUS_HOST_UNREACHABLE/i) {
      $plugin_output.=" The target host ($the_arguments{_host}) might not be reachable over the network. Is it down? Looks like a valid name/IP Address. $the_arguments{_host} is probably not even pingable. Wmic error text on the next line.\n";
   } elsif ($data_errors=~/NT_STATUS_UNEXPECTED_NETWORK_ERROR/i) {
      $plugin_output.=" This error has been reported when your DNS lookup configuration is not quite right. $the_arguments{_host} might be using a FQDN and/or you have no 'search' setting in your /etc/resolv.conf file. Wmic error text on the next line.\n";
   } elsif ($data_errors=~/NT_STATUS_CONNECTION_REFUSED/i) {
      $plugin_output.=" The target host ($the_arguments{_host}) did not allow our network connection. It is a valid name/IP Address. A firewall might be blocking us. There might be some critical services not running. Is it even running Windows?  Wmic error text on the next line.\n";
   } elsif ($data_errors=~/^.{0,5}TIMEOUT.{0,5}$/i) {
      $plugin_output.=" The WMI Client Library timed out. There are multiple possible reasons for this, some of them include - The host $the_arguments{_host} might just be really busy, it might not even be running Windows. Error text on the next line.\n";
   } else {
      $plugin_output.=" The error text from wmic is: ";
   }
   $plugin_output.=$data_errors;
   finish_program($ERRORS{'UNKNOWN'});
}
}
#-------------------------------------------------------------------------
sub clude_wmi_data {
# pass in 
# whether to include or exclude the specifications 1: for include, 0 for exclude
# the array of include/exclude specifications
# the wmi data array @collected_data
# 0 if we are not to process each row - but only process row 0
# array index into the wmi data (also the last index)
my ($include_mode,$specifications,$wmidata,$process_each_row,$last_wmi_data_index)=@_;

if ($#$specifications>=0) {

   my @new_wmi_query_data=(); # data from the last wmi goes in here
   my @new_first_wmi_query_data=(); # data from the first wmi query goes in here
   my $num_inclusions=0;
   my $num_exclusions=0;
   
   $debug && print "################# Looking to perform data clusions Mode=$include_mode_text{$include_mode} ################# \n";
   $debug && print "WMI DATA BEFORE:" . Dumper($wmidata);
   foreach my $clusion_spec (@{$specifications}) {
      # old version of config::inifiles set the array to a single undefined value - we have to test for it
      if (defined($clusion_spec)) {
         $debug && print "Looking to $include_mode_text{$include_mode} data matching: $clusion_spec\n";
   
         my $inclusions_for_this_spec=0;
         my $exclusions_for_this_spec=0;
      
         # Now loop through the rows of data in the last WMI query
         # we only need to look at the last wmi query since this is the row that contains all the data we will user for display/test/perf data
         # we only need to delete any excluded data from the last row since everything is driven from this row and it does not matter if we leave old info behind in the other WMI queries
         # the loop through the wmi data goes inside the spec loop since if all data is removed then checks on other specs will go faster since there is no data to check
         my $row=0;
         foreach my $wmiquerydata (@{$$wmidata[$last_wmi_data_index]}) {
            $debug && print "-------- Looking at Row #$row " . Dumper($wmiquerydata);
            # the first check is to see if this data has already been exluded by some other exclusion
            if ($$wmiquerydata{'_Exclude_Data'}) {
               $debug && print "******** Data previously excluded by $$wmiquerydata{'_Exclude_Data'}\n";
            } else {
               my ($result,$perf,$display,$test_field)=parse_limits($clusion_spec,$wmiquerydata);
               my $include_this_data=0; # the default position is to exclude the data, we change this to 1 when we want to keep the data
               if ($result) {
                  $debug && print " --- Range Specification was met\n";
                  # criteria is triggered so we know that the data meets the range criteria
                  if ($include_mode) {
                     # we are including data and this data met the requirement so we have to include it
                     $include_this_data=1;
                  }
               } else {
                  $debug && print " --- Range Specification was NOT met\n";
                  # criteria is not met
                  if (!$include_mode) { # ie if excluding then ....
                     # we are excluding data and this one did not met the requirements for exclusion so include it
                     $include_this_data=1;
                  }
               }
                     
               if ($include_this_data) {
                  $debug && print "******** Marking row #$row as INCLUDED\n";
                  $inclusions_for_this_spec++;
                  if ($include_mode) {
                     # flag that this data was included because it is in include mode and which inclusion spec included it
                     $$wmiquerydata{'_Include_Data'}=$clusion_spec;
                  }
               } else {
                  $exclusions_for_this_spec++;
                  if (!$include_mode) {
                     # flag that this data was excluded because it is in exclude mode and which exclusion spec excluded it
                     $$wmiquerydata{'_Exclude_Data'}=$clusion_spec;
                  }
                  $debug && print "******** Marking row #$row as NOT included\n";
               }
            }
            $row++;
         }
   
         $num_exclusions+=$exclusions_for_this_spec;
         $num_inclusions+=$inclusions_for_this_spec;
         $debug && print "-------- There were $inclusions_for_this_spec inclusions and $exclusions_for_this_spec exclusions for this specification\n";
      }
   }
   
   # now we need to go through the WMI data and pull out all the ones that ended up being excluded or not included (since we could have had multiple includes or excludes)
   $debug && print "Now checking all inclusions/exclusions for building the final list\n";
   my $row=0;
   foreach my $wmiquerydata (@{$$wmidata[$last_wmi_data_index]}) {
      $debug && print "-------- Looking at Row #$row " . Dumper($wmiquerydata);
      my $include_this_data=0;
      if ($include_mode) {
         # in include mode, only include items that are specifically included
         if ($$wmiquerydata{'_Include_Data'}) {
            $debug && print "******** Data included by $$wmiquerydata{'_Exclude_Data'}\n";
            $include_this_data=1;
         }
      } elsif (!$include_mode) {
         # in exclude mode, only exclude items that are specifically excluded
         if ($$wmiquerydata{'_Exclude_Data'}) {
            $debug && print "******** Data excluded by $$wmiquerydata{'_Exclude_Data'}\n";
         } else {
            $include_this_data=1;
         }
      }
      if ($include_this_data) {
         $debug && print "******** Including row #$row\n";
         push(@new_wmi_query_data,$wmiquerydata);
         # we also have to keep the equivalent row from the first wmi query
         push(@new_first_wmi_query_data,$$wmidata[0][$row]);
      }      
      $row++;
   }

   check_for_and_fix_row_zero(\@new_wmi_query_data,\%{$$wmidata[$last_wmi_data_index][0]});

   # only need to check this if we excluded data
   if ($num_exclusions>0) {
      # load the new data into the data array for the new last query data
      @{$$wmidata[$last_wmi_data_index]}=@new_wmi_query_data;
      
      # I can't think why I would ever have wanted to do this - the include/excludes work on the $last_wmi_data_index only
      # So why would we want to change the previous results to the same as the new results?
      # first discovered that this was wrong with checkprintjobs      
      # load the new first wmi query data, if we have not already
      #if ($last_wmi_data_index>0) {
      #   @{$$wmidata[0]}=@new_first_wmi_query_data;
      #}
      # run a no data check since we changed the data

      no_data_check($$wmidata[$last_wmi_data_index][0]{'_ItemCount'});
   }

   $debug && print "WMI DATA AFTER $include_mode_text{$include_mode}:" . Dumper($wmidata);
   $debug && print "################# Data $include_mode_text{$include_mode} completed $num_inclusions row(s) included, $num_exclusions row(s) excluded ################# \n"; 
   
}

}
#-------------------------------------------------------------------------
sub check_for_and_fix_row_zero {
# after manipulating returned WMI query data we sometimes might remove Row 0 - which contains special fields
# we have to put them back
# pass in 
# a reference to the whole last WMI query (the new version) (an array)
# a reference to the old Row 0 from the last WMI query (the original version)
my ($new_data_array,$old_data_hash)=@_;

# now check to make sure the zero row is still place and also update the _ItemCount field with a new value
# we need to save this value since the "exists" check, while it does not create the hash entry still puts an array entry in there
my $new_num_wmi_rows=$#{$new_data_array};
$debug && print "NEW WMI Data is " . Dumper($new_data_array) . " with last index=$new_num_wmi_rows\n";

if (!exists($$new_data_array[0]{'_ItemCount'})) {
   # the original Row 0 has been excluded
   # we can't actually just drop row 0 since it contains special data eg _ItemCount and maybe other fields
   # we can drop it if it is the only row since then it is the same as not finding anything in our WMI query
   # so what we do is -
   # if there is a row after this one then we compare them and copy all fields from row 0 that are not in row 1 from row 0 to row 1

   # if there is zero rows in the last WMI query now, then we actually only want to set 
   # _ItemCount, _ChecksOK, _KeepStateCreateTimestamp', _KeepStateSamplePeriod

   if ($new_num_wmi_rows>=0) {
      $debug && print "Moving all original special ROW 0 fields to the new row 0 .....\n";
      foreach my $field (keys %{$old_data_hash}) {
         # see if this key exists in the new Row 0
         if (!exists($$new_data_array[0]{$field})) {
            $debug && print "Copying field $field (Value=$$old_data_hash{$field})\n";
            $$new_data_array[0]{$field}=$$old_data_hash{$field};
         }
      }
   } else {
      # since there is no WMI data then we only need to update the following
      # _ItemCount (will get done a couple of lines later outside the if), _ChecksOK (do this one here)
      $$new_data_array[0]{'_ChecksOK'}=$$old_data_hash{'_ChecksOK'};
   }
}

# update the _ItemCount value in row 0 with the new number of rows in the last WMI query
$$new_data_array[0]{'_ItemCount'}=$new_num_wmi_rows+1;
$debug && print "Setting _ItemCount to $$new_data_array[0]{'_ItemCount'}\n";
}
#-------------------------------------------------------------------------
sub make_data_alignment_hashkey {
my ($wmiquerydata,$fields)=@_;
my $hashkey='';
# make up the hash key for the lookup table out of the data contained within the fields identified as thedata alignment fields
foreach my $field (@{$fields}) {
   no warnings;
   $hashkey.="$$wmiquerydata{$field},"
}
return $hashkey;
}
#-------------------------------------------------------------------------
sub align_data {
# for checks that have 2 WMI queries, if the data in the rows changes between queries, we can have a problem
# this sub tidies that condition up
# Pass in
# the wmi data array @collected_data
# array index into the wmi data (also the last index)
# comman delimited list of fields used to align the data
my ($wmidata,$last_wmi_data_index,$data_alignment_fields)=@_;

################ FOR TESTING - we manually remove data 
#splice(@{$$wmidata[0]},0,1);
#splice(@{$$wmidata[$last_wmi_data_index]},1,1);

$debug && print "Checking Data Alignment\n";
$debug && print "Pre-alignment data: " . Dumper($wmidata);

my @fields=split(',',$data_alignment_fields);

# loop through the first wmi query to build up a lookup table
my $row=0;
my %wmi_lookup=();
my @new_wmi_query_data=();
$debug && print "----------- Creating Lookup Table\n";
foreach my $wmiquerydata (@{$$wmidata[0]}) {
   my $hashkey=make_data_alignment_hashkey($wmiquerydata,\@fields);
   $debug && print "-------- Looking at Row #$row of first WMI Query (which has hash key of $hashkey) " . Dumper($wmiquerydata);
   $wmi_lookup{$hashkey}=$row;
   $row++;
}

# loop through the last wmi query
$row=0;
my $corrections=0;
$debug && print "----------- Checking Alignment\n";
foreach my $wmiquerydata (@{$$wmidata[$last_wmi_data_index]}) {
   my $hashkey=make_data_alignment_hashkey($wmiquerydata,\@fields);
   $debug && print "-------- Looking at Row #$row of Last WMI Query (which has hash key of $hashkey) " . Dumper($wmiquerydata);
   # see which row this hashkey is in in the first wmiquery
   my $first_wmi_query_row=$wmi_lookup{$hashkey};
   if (defined($first_wmi_query_row)) {
      $debug && print "Located in Row $first_wmi_query_row of first query vs $row of last query\n";
      # we found the data in the first query
      if ($row==$first_wmi_query_row) {
         # data is good 
         $new_wmi_query_data[$first_wmi_query_row]=$wmiquerydata;
         $debug && print "Storing Data as is\n";
      } else {
         # this data is in the wrong row, so correct its location
         $new_wmi_query_data[$first_wmi_query_row]=$wmiquerydata;
         $corrections++;
         $debug && print "Correcting - realigning index\n";
      }
   } else {
      $debug && print "Does not exist in the first query\n";
      # this data does not exist is the first query
      # so do not include it in the new data
      $corrections++;
      $debug && print "Correcting - ignoring this data\n";
   }
   $row++;
}

if ($corrections) {
   $debug && print "We made $corrections correction(s)\n";
   # now go through the array one more time
   # if we find any data which is not initialised it means that there is data in the first wmi query, but not in the second
   # so in that case we should delete the array indexes from both arrays
   for (my $row=0;$row<=$#new_wmi_query_data;$row++) {
      if (!defined($new_wmi_query_data[$row])) {
         $debug && print "Row $row in last query is undefined - removing from both WMI queries\n";
         splice(@{$$wmidata[0]},$row,1);
         splice(@new_wmi_query_data,$row,1);
      }
   }
   
   check_for_and_fix_row_zero(\@new_wmi_query_data,\%{$$wmidata[$last_wmi_data_index][0]});
   
   @{$$wmidata[$last_wmi_data_index]}=@new_wmi_query_data;
   
   # since we have changed stuff we need a nodata check
   no_data_check($$wmidata[$last_wmi_data_index][0]{'_ItemCount'});
   
}
$debug && print "Aligned Data: " . Dumper($wmidata);
}
#-------------------------------------------------------------------------
sub process_join_queries {
# process joins as specified in the ini file
# pass in
# the join configuration array reference
# the join query array reference
# a reference to @collected_data
# the $last_wmi_data_index
my ($join_config_list,$join_query_list,$collected_data,$last_wmi_data_index)=@_;
$debug && print "JOIN PARAMETERS  " . Dumper($join_config_list,$join_query_list,$collected_data,$last_wmi_data_index);

# see if there are any joins to be processed
my $i=0;
foreach my $join_config (@{$join_config_list}) {
   # for each join config item we need a matching join query
   if (defined($$join_query_list[$i])) {
      $debug && print "Processing JOIN for $join_config WITH $$join_query_list[$i]\n";
      # process this join
      # get the join parameters from the config
      #       0   1     2           3           4             5           6            7             8           9         
      # join=ID,INDEX,BASEFIELD,BASEREGEX,BASEREPLACEMENT,EXTRAFIELD,EXTRAREGEX,EXTRAREPLACEMENT,NUMQUERIES,WMINAMESPACE
      my @jc=split(/,/,$join_config);
      my @join_data=(); # temp array for join data from wmi query
      my ($dummy_data_errors,$dummy_last_wmi_data_index)=wmi_data_join($jc[0],$collected_data,$last_wmi_data_index,$jc[2],$jc[3],$jc[4],$jc[5],$jc[6],$jc[7],$jc[8],$jc[9],
         $$join_query_list[$i],'','',\@join_data,\$the_arguments{'_delay'},undef,0);
      $debug && print "JOIN DATA  " . Dumper(\@join_data);
   }
   $i++;
}
}
#-------------------------------------------------------------------------
sub checkini {
# run a check as defined in the ini file
my ($wmi_ini,$ini_section)=@_;
# pass in 
# the config::inifiles object
# the section name in the ini file we have to process
$debug && print "Processing INI Section: $ini_section\n";
$use_pro_library && starttimer('Process INI Check');

# change the $opt_mode to be the same as the section name
# we need this since some things look up values by $opt_mode
$opt_mode=$ini_section;

$debug && print "Settings for this section are:\n" . show_ini_section($wmi_ini,$ini_section);

# grab the query
my $query=$wmi_ini->val($ini_section,'query','');

if ($query) {

   $use_pro_library && starttimer('Preparation');
   
   $ini_based_check=1;
   
   # see if there are any WMI join queries
   # these come in 2 separate fields, join= and joinquery=
   my @join_config_list=$wmi_ini->val($ini_section,'join',undef);
   my @join_query_list=$wmi_ini->val($ini_section,'joinquery',undef);

   # see if there are any query extensions
   my @query_extension_list=$wmi_ini->val($ini_section,'queryextension',undef);

   # now, optionally we need some fields to check warn/crit against
   # these are in the testfield parameter(s)
   # initialise this list to at least '' so save checking it for fields later on
   my @test_fields_list=$wmi_ini->val($ini_section,'test','');

   # now we need some display fields (at least one)
   my @pre_display_fields_list=$wmi_ini->val($ini_section,'predisplay');

   # now we need some display fields (at least one)
   my @display_fields_list=$wmi_ini->val($ini_section,'display');
   
   # and optionally get some perf data fields
   my @perfdata_fields_list=$wmi_ini->val($ini_section,'perf');

   # and optionally get some substitution fields
   my @tmp_array=$wmi_ini->val($ini_section,'static');
   $use_pro_library && load_static_variables_from_array(\@tmp_array);
   $debug && print "All Static Ini Variables: " . Dumper(\%ini_static_variables);

   # need at least one pre-display or display field so that the plugin shows something!
   if ($#display_fields_list>=0 || $#pre_display_fields_list>=0) {

      # add all the test, display and perfdata fields to the global config variables so that our functions can find them when needed
      $valid_test_fields{$opt_mode}=\@test_fields_list;
      $pre_display_fields{$opt_mode}=\@pre_display_fields_list;
      $display_fields{$opt_mode}=\@display_fields_list;
      $performance_data_fields{$opt_mode}=\@perfdata_fields_list;
      
      my $requires_version=$wmi_ini->val($ini_section,'requires',0);
      if ($VERSION < $requires_version) {
         # this is a problem
         print "This check ($opt_mode) requires at least version $requires_version of the plugin\nThere are probably features implemented in that version that this check uses.\n";
         finish_program($ERRORS{'UNKNOWN'});
      }
      
      # if --inihelp has been specified then show the help for this mode
      if ($opt_inihelp) {
         my $inihelp=$wmi_ini->val($ini_section,'inihelp','');
         short_usage(1);
         if ($inihelp) {
            print "\n$inihelp\n";
         }
         print "\n";
         print show_warn_crit_field_info($wmi_ini,$ini_section);
         exit;
      }
      
      my $custom_header_regex=$wmi_ini->val($ini_section,'headerregex','');
      my $custom_data_regex=$wmi_ini->val($ini_section,'dataregex','');
      
      # see how many samples to get
      my $number_wmi_samples=$wmi_ini->val($ini_section,'samples',$default_inifile_number_wmi_samples);
      
      # see what delay to use
      # the setting in the ini file defines the default delay
      my $ini_delay=$wmi_ini->val($ini_section,'delay',$default_inifile_delay); 
      if ($the_arguments{'_delay'} eq '') {
         $the_arguments{'_delay'}=$ini_delay;
      }

      # extract the calc field if any and get it ready
      my $calc_list=$wmi_ini->val($ini_section,'calc',''); 
      my @calc_array=();
      if ($calc_list) {
         @calc_array=split(',',$calc_list);
      }
      
      # see if --keepstate should be enabled or not
      # only disable, never enable as this is the default anyway
      if ($wmi_ini->val($ini_section,'keepstate','') eq '0') {
         $debug && print "--keepstate disabled by ini file\n";
         $opt_keep_state=0;
      }

      # set the namespace 
      my $ini_namespace=$wmi_ini->val($ini_section,'namespace',$opt_wminamespace); 
      if ($ini_namespace) {
         # if the namespace is set in the ini file, set the command line option to that value so that it gets used by the query
         $opt_wminamespace=$ini_namespace;
      }

      # prepare the query extension if any
      $query=process_queryextension_fields_list($query,\@query_extension_list);

      $use_pro_library && endtimer('Preparation');

      my @collected_data;
      my ($data_errors,$last_wmi_data_index)=get_wmi_data($number_wmi_samples,$ini_namespace,$query,
         $custom_header_regex,$custom_data_regex,\@collected_data,\$the_arguments{'_delay'},\@calc_array,$wmi_ini->val($ini_section,'slashconversion',''));
      
      check_for_data_errors($data_errors);

      # add any join data
      process_join_queries(\@join_config_list,\@join_query_list,\@collected_data,$last_wmi_data_index);

      $use_pro_library && process_helper_query($wmi_ini,$ini_section,\@collected_data,$last_wmi_data_index);

      my $process_each_row=$wmi_ini->val($ini_section,'processallrows','');
      my $num_rows_in_last_wmi_result=$#{$collected_data[$last_wmi_data_index]};

      no_data_check($collected_data[$last_wmi_data_index][0]{'_ItemCount'});

      $use_pro_library && starttimer('Post Processing');
      my $data_alignment_fields=$wmi_ini->val($ini_section,'aligndata','');
      if ($data_alignment_fields) {
         align_data(\@collected_data,$last_wmi_data_index,$data_alignment_fields);
      }
      
      # calculate custom fields, if any defined
      my @customfield_fields_list=$wmi_ini->val($ini_section,'customfield');
      process_custom_fields_list(\@customfield_fields_list,\@collected_data,$process_each_row,$last_wmi_data_index);

      # include/remove collected/calculated wmi data if required
      # collect any include/exclude specifications from the ini file
      # unfortunately these add at least one element to each array
      my @ini_includes=$wmi_ini->val($ini_section,'includedata');
      my @ini_excludes=$wmi_ini->val($ini_section,'excludedata');

      my @all_includes=(@opt_include_data, @ini_includes);
      my @all_excludes=(@opt_exclude_data, @ini_excludes);

      clude_wmi_data(1,\@all_includes,\@collected_data,$process_each_row,$last_wmi_data_index);
      clude_wmi_data(0,\@all_excludes,\@collected_data,$process_each_row,$last_wmi_data_index);
      # the number of rows might have changed so update it
      $num_rows_in_last_wmi_result=$#{$collected_data[$last_wmi_data_index]};

      # process any list specifications
      # calculate custom list fields, if any defined
      my @customlists_list=$wmi_ini->val($ini_section,'createlist');
      process_custom_lists(\@customlists_list,\@collected_data,$last_wmi_data_index);

      my $overall_display_info='';
      my $overall_performance_data='';
      if ($process_each_row eq '0') {
         # don't loop around each row as what we want will be in ROW 0 only
         # this might apply if your check is calculating all customfields and therefore does not need each row to be displayed/checked for warn/critical
         $num_rows_in_last_wmi_result=0;
      }
      for (my $row=0;$row<=$num_rows_in_last_wmi_result;$row++) {
         $debug && print "================== Processing WMI Data Row $row =================\n";
         $collected_data[$last_wmi_data_index][$row]{_TestResult}=test_limits($opt_warn,$opt_critical,$collected_data[$last_wmi_data_index][$row],\%warn_perf_specs_parsed,\%critical_perf_specs_parsed,\@warn_spec_result_list,\@critical_spec_result_list);
         my ($this_display_info,$this_performance_data,$this_combined_data)=create_display_and_performance_data($collected_data[$last_wmi_data_index][$row],$display_fields{$opt_mode},$performance_data_fields{$opt_mode},\%warn_perf_specs_parsed,\%critical_perf_specs_parsed);

         my $show_this_one=1;
         if ($use_pro_library) {
            $show_this_one=advanced_pro_filters($collected_data[$last_wmi_data_index][$row]);
         }
         
         # we may exclude some from the display
         if ($show_this_one) {
            $debug && print "THIS ROW'S DISPLAY=$this_display_info\n";
            $overall_display_info.=$this_display_info;
         }
         
         # but we always include them in performance data
         $overall_performance_data.=$this_performance_data;
      }

      # work out the overall result - some fields in [$last_wmi_data_index][0] are overwritten by this call
      my $overall_test_result=work_out_overall_exit_code(\@collected_data,$process_each_row,$last_wmi_data_index);

      # work out the pre display and stick to the front of the output string
      my ($this_display_info,$this_performance_data,$this_combined_data)=create_display_and_performance_data($collected_data[$last_wmi_data_index][0],$pre_display_fields{$opt_mode},undef,undef,undef);
      $overall_display_info="$this_display_info$overall_display_info";

      # there might be some (Sample Period xx sec) contained in the $overall_display_info (left over from when we displayed each row individually)
      # if there is remove it since we are going to display it as an overall now, only leave the first one in place
      # we have to remove it after the fact since we add it to each row before adding the overall status
      # and we only sometimes do the overall status
      # only row 0 or the query might have it so that means there is only ever going to be 2 and we have to remove the 2nd one
      $overall_display_info=~s/(.*?Sample Period.*?) \(Sample Period \d+ sec\)(.*)/$1$2/; # now remove any other ones

      my $overall_combined_data=combine_display_and_perfdata($overall_display_info,$overall_performance_data);
      $plugin_output.=$overall_combined_data;
   
      $use_pro_library && endtimer('Post Processing');
      $use_pro_library && endtimer('Process INI Check');
      finish_program($overall_test_result);
      
   } else {
      $plugin_output.="UNKNOWN - No predisplay or display field(s) specified in ini file section '$ini_section'\n";
      finish_program($ERRORS{'UNKNOWN'});
   }

} else {
   $plugin_output.="UNKNOWN - Query not specified in ini file section '$ini_section'\n";
   finish_program($ERRORS{'UNKNOWN'});
}

}
#-------------------------------------------------------------------------
sub checkgeneric {
# I use this when I am playing around ........
my @collected_data;
my ($data_errors,$last_wmi_data_index)=get_wmi_data(1,'',
   "SELECT * FROM Win32_PerfFormattedData_PerfDisk_PhysicalDisk where name = \"c:\"",
   '','',\@collected_data,\$the_arguments{'_delay'},undef,0);

check_for_data_errors($data_errors);
my $test_result=test_limits($opt_warn,$opt_critical,$collected_data[$last_wmi_data_index][0],\%warn_perf_specs_parsed,\%critical_perf_specs_parsed,\@warn_spec_result_list,\@critical_spec_result_list);
my ($this_display_info,$this_performance_data,$this_combined_data)=create_display_and_performance_data($collected_data[$last_wmi_data_index][0],$display_fields{$opt_mode},$performance_data_fields{$opt_mode},\%warn_perf_specs_parsed,\%critical_perf_specs_parsed);
$plugin_output.=$this_combined_data;

finish_program($test_result);

}
#-------------------------------------------------------------------------
sub checkcpu {

# set default delay for this mode
if ($the_arguments{'_delay'} eq '') {
   $the_arguments{'_delay'}=5;
}

my @collected_data;
my ($data_errors,$last_wmi_data_index)=get_wmi_data(2,'',
   "select PercentProcessorTime,Timestamp_Sys100NS from Win32_PerfRawData_PerfOS_Processor where Name=\"_Total\"",
   '','',\@collected_data,\$the_arguments{'_delay'},undef,0);

check_for_data_errors($data_errors);
# at this point we can assume that we have all the data we need stored in @collected_data
# this is a counter type of PERF_100NSEC_TIMER_INV, refer http://technet.microsoft.com/en-us/library/cc757283%28WS.10%29.aspx
calc_new_field('_AvgCPU','PERF_100NSEC_TIMER_INV','PercentProcessorTime,%.2f,100',\@collected_data,$last_wmi_data_index,0);

my $test_result=test_limits($opt_warn,$opt_critical,$collected_data[$last_wmi_data_index][0],\%warn_perf_specs_parsed,\%critical_perf_specs_parsed,\@warn_spec_result_list,\@critical_spec_result_list);
my ($this_display_info,$this_performance_data,$this_combined_data)=create_display_and_performance_data($collected_data[$last_wmi_data_index][0],$display_fields{$opt_mode},$performance_data_fields{$opt_mode},\%warn_perf_specs_parsed,\%critical_perf_specs_parsed);
$plugin_output.=$this_combined_data;

finish_program($test_result);
}
#-------------------------------------------------------------------------
sub checknetwork {
my @collected_data;
my @mac_mapping;
my @netid_mapping;

my $num_samples=2;
my $results_text='';
my $result_code=$ERRORS{'UNKNOWN'};
my $performance_data='';

# for network stuff we often want $actual_bytefactor to be 1000
# so lets use that unless the user has set something else
# check the saved bytefactor argument value
if (!$the_arguments{'_savedbytefactor'}) {
   $actual_bytefactor=1000;
}

# set default delay for this mode
if ($the_arguments{'_delay'} eq '') {
   $the_arguments{'_delay'}=5;
}

if ($the_arguments{'_arg1'} eq '') {
   # only need 1 WMI query when _arg1 not specified
   $num_samples=1; 
}

# default interface stats query for server 2012 and above
my $interface_query='select CurrentBandwidth,BytesReceivedPerSec,BytesSentPerSec,Name,Frequency_Sys100NS,OutputQueueLength,PacketsReceivedErrors,PacketsReceivedPerSec,PacketsSentPerSec,Timestamp_Sys100NS from Win32_PerfRawData_Tcpip_NetworkAdapter';

if ($the_arguments{'_arg2'} eq 'legacy') {
   $interface_query='select CurrentBandwidth,BytesReceivedPerSec,BytesSentPerSec,Name,Frequency_Sys100NS,OutputQueueLength,PacketsReceivedErrors,PacketsReceivedPerSec,PacketsSentPerSec,Timestamp_Sys100NS from Win32_PerfRawData_Tcpip_NetworkInterface';
}

my ($data_errors,$last_wmi_data_index)=get_wmi_data($num_samples,'',$interface_query,'','',\@collected_data,\$the_arguments{'_delay'},undef,0);

check_for_data_errors($data_errors);

## now join the mapping between mac address and the network data device name
## have to replace all the non alpha characters in both items to get a match
## we specify these joins as being able to use a state file since we expect them to be quite static
$debug && print "Data Join on the Name to find the MAC address\n";
my ($dummy_data_errors,$dummy_last_wmi_data_index)=wmi_data_join('NetMacMap',\@collected_data,$last_wmi_data_index,'Name','\W','_','Description','\W','_',1,'',
   "select ipaddress,description,macaddress,ipsubnet,defaultipgateway,dhcpenabled,dhcpserver,dnsdomain,servicename from win32_networkadapterconfiguration where macaddress like '%:%'",
   '','',\@mac_mapping,\$the_arguments{'_delay'},undef,0);

## now join the mapping between mac address connection netconnectionid
## have to replace all the non alpha characters in both items to get a match
## we specify these joins as being able to use a state file since we expect them to be quite static
$debug && print "Data Join on the MAC Address to find the NetConnectionID (Windows friendly name)\n";
($dummy_data_errors,$dummy_last_wmi_data_index)=wmi_data_join('NetNameMap',\@collected_data,$last_wmi_data_index,'MACAddress','',undef,'MACAddress','',undef,1,'',
   "select macaddress,netconnectionID from win32_networkadapter where netconnectionid like '%'",
   '','',\@netid_mapping,\$the_arguments{'_delay'},undef,0);

# process includes and excludes of WMI data for Pro - after all WMI queries and joins and after check_for_data_errors - before we start looking through the returned WMI data
$use_pro_library && process_cludes_like_a_pro(\@opt_include_data,\@opt_exclude_data,\@collected_data,1,$last_wmi_data_index);

# now loop through the results, showing the ones requested
my $i=0; # we need to count the rows of data as we process them as this is used by calc_new_field()
$collected_data[$last_wmi_data_index][0]{'_NumInterfaces'}=0;
foreach my $row (@{$collected_data[$last_wmi_data_index]}) {
   # make sure all fields we will look for to match an adapter are initialised
   $$row{'Name'}=$$row{'Name'} || '';
   $$row{'NetConnectionID'}=$$row{'NetConnectionID'} || '';
   $$row{'IPAddress'}=$$row{'IPAddress'} || '';
   $$row{'MACAddress'}=$$row{'MACAddress'} || '';
   
   # also initialised the row test result variables for all rows to 0 so that when we look at the overall result, rows we have not actually included do not count for anything
   $$row{'_TestResult'}=0;
   $$row{'_StatusType'}='';
   $$row{'_Triggers'}='';
   
   $debug && print "Looking for a match to the command line argument '$the_arguments{'_arg1'}' in Name:'$$row{'Name'}' or NetConnectionID:'$$row{'NetConnectionID'}' or IPAddress:'$$row{'IPAddress'}' or MACAddress:'$$row{'MACAddress'}'\n";
   # see if $the_arguments{'_arg1'} matches any of ipaddress,macaddress,netconnectionid or the original network adapter name from the Win32_PerfRawData_Tcpip_NetworkInterface query
   if (  $$row{'Name'}=~/$the_arguments{'_arg1'}/i ||
         $$row{'NetConnectionID'}=~/$the_arguments{'_arg1'}/i || 
         $$row{'IPAddress'}=~/$the_arguments{'_arg1'}/i || 
         $$row{'MACAddress'}=~/$the_arguments{'_arg1'}/i
      ) {
   
      $debug && print "Matched and now looking at " . Dumper($row);
      
      $$row{'_DisplayName'}=$$row{'NetConnectionID'} || $$row{'IPAddress'} || $$row{'MACAddress'} || $$row{'Name'};
      $collected_data[$last_wmi_data_index][0]{'_NumInterfaces'}++;

      # these are a counter type of PERF_COUNTER_COUNTER, refer http://technet.microsoft.com/en-us/library/cc740048%28WS.10%29.aspx
      calc_new_field('_BytesReceivedPersec','PERF_COUNTER_COUNTER','BytesReceivedPersec,%.0f',\@collected_data,$last_wmi_data_index,$i);
      calc_new_field('_BytesSentPersec','PERF_COUNTER_COUNTER','BytesSentPersec,%.0f',\@collected_data,$last_wmi_data_index,$i);
      calc_new_field('_PacketsReceivedPersec','PERF_COUNTER_COUNTER','PacketsReceivedPersec,%.0f',\@collected_data,$last_wmi_data_index,$i);
      calc_new_field('_PacketsSentPersec','PERF_COUNTER_COUNTER','PacketsSentPersec,%.0f',\@collected_data,$last_wmi_data_index,$i);

      # calculate the interface bandwidth in bytes (it is bits from the WMI query), divide the bits by 8 
      calc_new_field('_CurrentBandwidthBytes','basicmaths',"CurrentBandwidth,/,8,%.2f",\@collected_data,$last_wmi_data_index,$i);
      
      # calculate the interface utilisation using the new interface bandwidth in bytes
      calc_new_field('_ReceiveBytesUtilisation','percent','_BytesReceivedPersec,_CurrentBandwidthBytes,%.2f',\@collected_data,$last_wmi_data_index,$i);
      calc_new_field('_SendBytesUtilisation','percent','_BytesSentPersec,_CurrentBandwidthBytes,%.2f',\@collected_data,$last_wmi_data_index,$i);

   # the parameters for this "function" are
   # SOURCEFIELD1,SOURCEFIELD2,SPRINTF_SPEC
   # where 
   # SOURCEFIELD1 [0] is a WMI field name which contains some number
   # SOURCEFIELD2 [1] is a WMI field name which contains some number
   # SPRINTF_SPEC [2] - a format specification passed directly to sprintf to format the result (can leave blank)
   # INVERT [3] take the resulting value away from this number. Useful in the following example eg set this value to 100 to show busy percentage where counter value is an idle percentage.
   # Formula is 100 * SOURCEFIELD1/SOURCEFIELD2
   #


      
      # store the test result so we can access it for an overall test result
      $$row{'_TestResult'}=test_limits($opt_warn,$opt_critical,$row,\%warn_perf_specs_parsed,\%critical_perf_specs_parsed,\@warn_spec_result_list,\@critical_spec_result_list);
      
      my ($this_display_info,$this_performance_data,$this_combined_data)=create_display_and_performance_data($row,$display_fields{$opt_mode},$performance_data_fields{$opt_mode},\%warn_perf_specs_parsed,\%critical_perf_specs_parsed);
      
      # concatenate the per drive results together
      $results_text.="$this_display_info    ";
      $performance_data.=$this_performance_data;
   
   }

   $i++;
}

if ($collected_data[$last_wmi_data_index][0]{'_NumInterfaces'}>0) {
   my $overall_test_result=work_out_overall_exit_code(\@collected_data,1,$last_wmi_data_index);
   my ($overall_display_info,$overall_performance_data,$overall_combined_data)=create_display_and_performance_data($collected_data[$last_wmi_data_index][0],$pre_display_fields{$opt_mode},undef,\%warn_perf_specs_parsed,\%critical_perf_specs_parsed);
   
   $overall_combined_data=combine_display_and_perfdata("$overall_display_info$results_text",$performance_data);
   
   # there might be some (Sample Period xx sec) contained in the $overall_display_info (left over from when we displayed each row individually)
   # if there is remove it since we are going to display it as an overall now, only leave the first one in place
   # we have to remove it after the fact since we add it to each row before adding the overall status
   # and we only sometimes do the overall status
   # only row 0 or the query might have it so that means there is only ever going to be 2 and we have to remove the 2nd one
   $overall_combined_data=~s/(.*?Sample Period.*?) \(Sample Period \d+ sec\)(.*)/$1$2/; # now remove any other ones
   
   $plugin_output.=$overall_combined_data;
   
   finish_program($overall_test_result);
} else {
   $plugin_output.="No Network Interfaces specified. Valid Interface Names are:\n" . list_collected_values_from_all_rows(\@collected_data,['Name','NetConnectionID','IPAddress','MACAddress'],"\n",', ',0) . "\nSpecify the -a parameter with an adapter name. Use ' ' around the adapter name.\n";
   finish_program($ERRORS{'UNKNOWN'});

}

}
#-------------------------------------------------------------------------
sub checkcpuq {
# set default delay for this mode
if ($the_arguments{'_delay'} eq '') {
   $the_arguments{'_delay'}=1;
}

# set default number of checks if not specified
if (!$the_arguments{'_arg1'}) {
   $the_arguments{'_arg1'}=3;
}

# disable keep state for this check
$opt_keep_state=0;

my @collected_data;
my ($data_errors,$last_wmi_data_index)=get_wmi_data($the_arguments{'_arg1'},'',
   "select ProcessorQueueLength from Win32_PerfRawData_PerfOS_System",
   '','',\@collected_data,\$the_arguments{'_delay'},[ 'ProcessorQueueLength' ],0);

check_for_data_errors($data_errors);
# at this point we can assume that we have all the data we need stored in @collected_data
$collected_data[$last_wmi_data_index][0]{'_AvgCPUQLen'}=sprintf("%.1f",$collected_data[$last_wmi_data_index][0]{'_QuerySum_ProcessorQueueLength'}/$collected_data[$last_wmi_data_index][0]{'_ChecksOK'});
$collected_data[$last_wmi_data_index][0]{'_CPUQPoints'}=list_collected_values_from_all_rows(\@collected_data,['ProcessorQueueLength'],', ','',0);

my $test_result=test_limits($opt_warn,$opt_critical,$collected_data[$last_wmi_data_index][0],\%warn_perf_specs_parsed,\%critical_perf_specs_parsed,\@warn_spec_result_list,\@critical_spec_result_list);
my ($this_display_info,$this_performance_data,$this_combined_data)=create_display_and_performance_data($collected_data[$last_wmi_data_index][0],$display_fields{$opt_mode},$performance_data_fields{$opt_mode},\%warn_perf_specs_parsed,\%critical_perf_specs_parsed);
$plugin_output.=$this_combined_data;
finish_program($test_result);

}
#-------------------------------------------------------------------------
sub do_dns_lookup {
# pass in
# a hostname or IP
# return a hash results (only the hash keys are loaded)
my ($lookup)=@_;
my %lookup_results=();
my $res   = Net::DNS::Resolver->new;
my $query = $res->query($lookup);
$debug && print "DNS:Lookup for $lookup\n";
if ($query) {
   foreach my $rr ($query->answer) {
      if ($rr->type eq 'A') {
         # get the addresses
         $debug && print "DNS:Found A " . $rr->address ."\n";
         $lookup_results{$rr->address}=1;
      } elsif ($rr->type eq 'PTR') {
         # get the pointer name
         $debug && print "DNS:Found PTR " . $rr->ptrdname ."\n";
         $lookup_results{$rr->ptrdname}=1;
      } else {
         print "DNS:Found TYPE=" . $rr->type ."\n";
      }
   }
} else {
   $lookup_results{'DNS Lookup failed with error ' . $res->errorstring}=1;
}
return %lookup_results;
}
#-------------------------------------------------------------------------
#sub checkdnsrecords {
## we want to be able to do a DNS lookup for this check
#use Net::DNS;
#
## decide if the _host parameter is a hostname or an IP Address
#my $request_type='Hostname';
#my $is_hostname=1;
#if ($the_arguments{'_host'}=~/^[0-9\.]+$/) {
#   $request_type='IP Address';
#   $is_hostname=0;
#}
#
#my %wmi_host_lookup_results=();
#my %wmi_ip_lookup_results=();
#
#my @collected_data;
#
#my ($data_errors,$last_wmi_data_index)=get_wmi_data(1,'',
#   "Select dnsdomain,dnshostname,ipaddress,ipsubnet,macaddress,description from Win32_NetworkAdapterConfiguration",
#   '','',\@collected_data,\$the_arguments{'_delay'},undef,1);
#
#check_for_data_errors($data_errors);
#no_data_check($collected_data[$last_wmi_data_index][0]{'_ItemCount'});
#
## so now we have a long list of WMI info - only some have ip addresses
## we want to get a list of hostnames/ips
#foreach my $row (@{$collected_data[$last_wmi_data_index]}) {
#   if ($$row{'IPAddress'}=~/[0-9\.]+/) {
#         # $$row{'IPAddress'} sometimes has () around it
#         $$row{'IPAddress'}=~s/[\(\)]//g;
#         # make the host name by concatenating 2 WMI fields and removing any . at the end
#         my $host="$$row{'DNSHostName'}.$$row{'DNSDomain'}";
#         $host=~s/\.$//;
#         # store hostname against IP address
#         $wmi_ip_lookup_results{$$row{'IPAddress'}}{$host}=1;
#         # now store the lookup by hostname as well
#         $wmi_host_lookup_results{$host}{$$row{'IPAddress'}}=1;
#   }
#}
#
#print Dumper(\%wmi_ip_lookup_results,\%wmi_host_lookup_results);
#
##$collected_data[$last_wmi_data_index][0]{'_DNSDetails'}="DNS Lookup of $request_type $the_arguments{'_host'} returns " . join(', ',@lookup_results);;
#$collected_data[$last_wmi_data_index][0]{'_WMIDetails'}="WMI Host(s): " . join(', ',sort keys %wmi_host_lookup_results) . ". WMI IP Address(es): ". join(', ',sort keys %wmi_ip_lookup_results) ;
#
## go through WMI host names and IP Addresses and do a DNS lookup for each and make sure they all match
#foreach my $wmi_key (sort keys %wmi_host_lookup_results) {
#   my %dns_info=do_dns_lookup($wmi_key);
#   print "Lookup HOST:$wmi_key: " . Dumper(\%dns_info);
#   # see if the WMI records match the DNS records
#   foreach my $wmi_data (sort keys %{$wmi_host_lookup_results{$wmi_key}}) {
#      # see if this wmi data exists is the dns data
#      if (defined($dns_info{$wmi_data})) {
#         print "WMI: $wmi_data matches DNS data\n";
#      } else {
#         print "WMI: $wmi_data - no DNS data\n";
#      }
#   }
#}
#foreach my $wmi_key (sort keys %wmi_ip_lookup_results) {
#   my %dns_info=do_dns_lookup($wmi_key);
#   print "Lookup IP:$wmi_key: " . Dumper(\%dns_info);
#   # see if the WMI records match the DNS records
#   foreach my $wmi_data (sort keys %{$wmi_ip_lookup_results{$wmi_key}}) {
#      # see if this wmi data exists is the dns data
#      if (defined($dns_info{$wmi_data})) {
#         print "WMI: $wmi_data matches DNS data\n";
#      } else {
#         print "WMI: $wmi_data - no DNS data\n";
#      }
#   }
#}
#
#if ($is_hostname) {
#   # compare the argument against the resolved hostname
#} else {
#   # compare the argument against a WMI-discovered IP Address
#}
#
#my $test_result=test_limits($opt_warn,$opt_critical,$collected_data[$last_wmi_data_index][0],\%warn_perf_specs_parsed,\%critical_perf_specs_parsed,\@warn_spec_result_list,\@critical_spec_result_list);
#my ($this_display_info,$this_performance_data,$this_combined_data)=create_display_and_performance_data($collected_data[$last_wmi_data_index][0],$display_fields{$opt_mode},$performance_data_fields{$opt_mode},\%warn_perf_specs_parsed,\%critical_perf_specs_parsed);
#print $this_combined_data;;
#
#finish_program($test_result);
#}
#-------------------------------------------------------------------------
sub checkmem {
# pass in
# 0 or 1 to signal that it should return the values rather than run like a normal check and print out the plugin display. this allows this sub to be called to get the memory values to be used in other functions
my ($return_values)=@_;

# note that for this check WMI returns data in kilobytes so we have to multiply it up to get bytes before using scaled_bytes

my @collected_data;
my $data_errors='';
my $last_wmi_data_index=0;

my $display_type='';
# still support for the old usage of arg1
# also enter first part of the if, if $return_values is specified
if ($return_values || $the_arguments{'_arg1'}=~/phys/i || $opt_submode=~/phys/i || ($opt_submode eq '' && $the_arguments{'_arg1'} eq '') ) {
   # expect output like
   #CLASS: Win32_OperatingSystem
   #FreePhysicalMemory|Name|TotalVisibleMemorySize
   #515204|Microsoft Windows XP Professional|C:\WINDOWS|\Device\Harddisk0\Partition1|1228272   
   # this means that we need to specify a regular expression to retrieve the data since there are more fields in the data than column headings
   # we only want data fields 1 4 5 so that we match the column headings
   ($data_errors,$last_wmi_data_index)=get_wmi_data(1,'',
   "Select Name,FreePhysicalMemory,TotalVisibleMemorySize from Win32_OperatingSystem",
   '','1,4,5',\@collected_data,\$the_arguments{'_delay'},undef,0);

   # this query returns FreePhysicalMemory,TotalVisibleMemorySize - we move them to the standard fields of _MemFreeK and _MemTotalK so that we can process them in a standard way
   # if there has been a problem with the query then they might not be set
   $collected_data[$last_wmi_data_index][0]{'MemType'}='Physical Memory';
   $collected_data[$last_wmi_data_index][0]{'_MemFreeK'}=$collected_data[$last_wmi_data_index][0]{'FreePhysicalMemory'}||0;
   $collected_data[$last_wmi_data_index][0]{'_MemTotalK'}=$collected_data[$last_wmi_data_index][0]{'TotalVisibleMemorySize'}||0;

} elsif ($the_arguments{'_arg1'}=~/page/i || $opt_submode=~/page/i) {
   print "This Mode is no longer used as it was proven to be inaccurate. Automatically using -m checkpage instead. ";
   $opt_mode='checkpage';
   &checkpage();
   finish_program($ERRORS{'UNKNOWN'}); # should never get here
   
   # This is the old check ............
   #   $collected_data[0][0]{'MemType'}='Page File';
   #   # expect output like
   #   #CLASS: Win32_OperatingSystem
   #   #FreeVirtualMemory|Name|TotalVirtualMemorySize
   #   #2051912|Microsoft Windows XP Professional|C:\WINDOWS|\Device\Harddisk0\Partition1|2097024
   #   # this means that we need to specify a regular expression to retrieve the data since there are more fields in the data than column headings
   #   # we only want data fields 1 4 5 so that we match the column headings
   #   $data_errors=get_wmi_data(1,'',
   #   "Select Name,FreeVirtualMemory,TotalVirtualMemorySize from Win32_OperatingSystem",
   #   '','1,4,5',\@collected_data,\$the_arguments{'_delay'},undef,0);
   #
   #   # this query returns FreePhysicalMemory,TotalVisibleMemorySize - we move them to the standard fields of _MemFreeK and _MemTotalK so that we can process them in a standard way
   #   # if there has been a problem with the query then they might not be set
   #   $collected_data[0][0]{'_MemFreeK'}=$collected_data[0][0]{'FreeVirtualMemory'}||0;
   #   $collected_data[0][0]{'_MemTotalK'}=$collected_data[0][0]{'TotalVirtualMemorySize'}||0;

} else {
   $plugin_output.="UNKNOWN - invalid SUBMODE in the checkmem function - should be page or physical.\n";
   finish_program($ERRORS{'UNKNOWN'});
}

check_for_data_errors($data_errors);

# at this point we can assume that we have all the data we need stored in @collected_data
$collected_data[$last_wmi_data_index][0]{'_MemUsedK'}=$collected_data[$last_wmi_data_index][0]{'_MemTotalK'}-$collected_data[$last_wmi_data_index][0]{'_MemFreeK'};
$collected_data[$last_wmi_data_index][0]{'_MemUsed%'}=sprintf("%.0f",$collected_data[$last_wmi_data_index][0]{'_MemUsedK'}/$collected_data[$last_wmi_data_index][0]{'_MemTotalK'}*100);
$collected_data[$last_wmi_data_index][0]{'_MemFree%'}=sprintf("%.0f",$collected_data[$last_wmi_data_index][0]{'_MemFreeK'}/$collected_data[$last_wmi_data_index][0]{'_MemTotalK'}*100);
$collected_data[$last_wmi_data_index][0]{'_MemUsed'}=$collected_data[$last_wmi_data_index][0]{'_MemUsedK'}*$actual_bytefactor;
$collected_data[$last_wmi_data_index][0]{'_MemFree'}=$collected_data[$last_wmi_data_index][0]{'_MemFreeK'}*$actual_bytefactor;
$collected_data[$last_wmi_data_index][0]{'_MemTotal'}=$collected_data[$last_wmi_data_index][0]{'_MemTotalK'}*$actual_bytefactor;

if ($return_values) {
   # we now want to return the results as part of the function output
   return @collected_data;
}

my $test_result=test_limits($opt_warn,$opt_critical,$collected_data[$last_wmi_data_index][0],\%warn_perf_specs_parsed,\%critical_perf_specs_parsed,\@warn_spec_result_list,\@critical_spec_result_list);
   
my ($this_display_info,$this_performance_data,$this_combined_data)=create_display_and_performance_data($collected_data[$last_wmi_data_index][0],$display_fields{$opt_mode},$performance_data_fields{$opt_mode},\%warn_perf_specs_parsed,\%critical_perf_specs_parsed);
$plugin_output.=$this_combined_data;
finish_program($test_result);
  
}
#-------------------------------------------------------------------------
sub checkpage {
# note that for this check WMI returns data in MB so we have to multiply it up to get bytes before using scaled_bytes
my @collected_data;
my @page_size_mapping;

my ($data_errors,$last_wmi_data_index)=get_wmi_data(1,'',
   "Select Name,AllocatedBaseSize,CurrentUsage,PeakUsage from Win32_PageFileUsage",
   '','',\@collected_data,\$the_arguments{'_delay'},['CurrentUsage','AllocatedBaseSize', 'PeakUsage'],0);

check_for_data_errors($data_errors);
no_data_check($collected_data[$last_wmi_data_index][0]{'_ItemCount'});

# we only want this is -a auto is specified
if ($the_arguments{'_arg1'}=~/auto/) {
   ## now join the mapping between page file utilisation and its max and initial sizes
   ## have to remove all \ in both items to get a match
   ## so replace all the non alpha characters in both items to get a match
   ## we specify these joins as being able to use a state file since we expect them to be quite static
   my ($dummy_data_errors,$dummy_last_wmi_data_index)=wmi_data_join('PageMap',\@collected_data,$last_wmi_data_index,'Name','\W*','','Name','\W*','',1,'',
      "Select InitialSize,MaximumSize from Win32_PageFileSetting",
      '','',\@page_size_mapping,\$the_arguments{'_delay'},undef,0);
}

if ($the_arguments{'_arg2'} eq '') {
   # no page file specified
   # we will use . to include all page files by default
   $the_arguments{'_arg2'}='.';
}

my $results_text='';
my $result_code=$ERRORS{'UNKNOWN'};
my $performance_data='';
my $num_critical=0;
my $num_warning=0;
my $alldisk_identifier='Overall Pagefile';

my @ram_data=();
if ($the_arguments{'_arg4'}) {
   # using arg4 specifies that we should add the RAM values to the page file values
   # we automatically turn on arg3 to show system totals and also disable showing of individual page files by setting arg2 to some bogus value
   # you can not use arg1=auto either
   $the_arguments{'_arg1'}='';
   $the_arguments{'_arg3'}=1;
   $the_arguments{'_arg2'}='Disable Display of Individual Page Files for This Option';
   # go and get the RAM values
   # @ram_data will END up looking like @collected_data ie the ram results will be in index [0][0] of the array which will contain a hash
   $debug && print "Collecting RAM Data\n";
   @ram_data=checkmem(1);
   # for RAM we are interested in 
   # [0][0]{'_MemUsed'}
   # [0][0]{'_MemFree'}
   # [0][0]{'_MemTotal'}
   $alldisk_identifier='Overall Pagefile+RAM';
   # modify the display - do not use peak fields anymore plus change some text
   $pre_display_fields{'checkpage'}=undef;
   $display_fields{'checkpage'}=[ '_DisplayMsg||~|~| - ||', 'Name||~|~| ||', '_Total|#B|Total|: | - ||', '_Used|#B|Used|: | ||', '_Used%|%|~|~| - |(|)', '_Free|#B|Free|: | ||', '_Free%|%|~|~||(|)' ];
   $performance_data_fields{'checkpage'}=[ '_Total|Bytes|{Name} Page+RAM Size', '_Used|Bytes|{Name} Used', '_Used%|%|{Name} Utilisation', ], 
}

if ($the_arguments{'_arg3'}) {
   # include the system totals
   # now we want to add a index before 0 so we copy everything from index 0 and unshift it to the front
   # we do it like this so that all the derived values normally stored in index 0 will remain there
   # then we overwrite the fields we want with new fake ones
   # note that the sum fields will be the orginal totals etc
   # now add this on to the existing data

   my %new_row=%{$collected_data[$last_wmi_data_index][0]};
   unshift(@{$collected_data[$last_wmi_data_index]},\%new_row);

   # now we have index 1 and index 0 the same data
   # add the new fake system total info
   # we make it look like WMI returned info about a disk call SystemTotalDisk
   $collected_data[$last_wmi_data_index][0]{'Name'}=$alldisk_identifier;
   $collected_data[$last_wmi_data_index][0]{'CurrentUsage'}=$collected_data[$last_wmi_data_index][0]{'_ColSum_CurrentUsage'};
   $collected_data[$last_wmi_data_index][0]{'AllocatedBaseSize'}=$collected_data[$last_wmi_data_index][0]{'_ColSum_AllocatedBaseSize'};
   $collected_data[$last_wmi_data_index][0]{'PeakUsage'}=$collected_data[$last_wmi_data_index][0]{'_ColSum_PeakUsage'};

}

# process includes and excludes of WMI data for Pro - after all WMI queries and joins and after check_for_data_errors - before we start looking through the returned WMI data
$use_pro_library && process_cludes_like_a_pro(\@opt_include_data,\@opt_exclude_data,\@collected_data,1,$last_wmi_data_index);

# now loop through the results, showing the ones requested
foreach my $row (@{$collected_data[$last_wmi_data_index]}) {

   if ( $$row{'Name'}=~/$the_arguments{'_arg2'}/i || ($$row{'Name'} eq $alldisk_identifier && $the_arguments{'_arg3'}) ) {
      # include this drive in the results

      if ($the_arguments{'_arg4'}) {
         # if arg4 is set then this is the only row being shown and it is the totals
         # we have to add the RAM values (in bytes) to the page values (in MBytes)
         # we now have to munge the page data
         # convert all the RAM amounts to MB to match the page file units
         $$row{'_MemTotalMB'}=$ram_data[0][0]{'_MemTotal'}/$actual_bytefactor/$actual_bytefactor;
         $$row{'_MemUsedMB'}=$ram_data[0][0]{'_MemUsed'}/$actual_bytefactor/$actual_bytefactor;

         $debug && print "Adding RAM Data to Page data - Used:$$row{'_MemUsedMB'}, Total:$$row{'_MemTotalMB'}\n";
         $debug && print "Page Data Before - Used:$$row{'CurrentUsage'}, Total:$$row{'AllocatedBaseSize'}\n";

         # firstly there is the total page size - AllocatedBaseSize, it is in MB
         $$row{'AllocatedBaseSize'}+=$$row{'_MemTotalMB'};
         # then there is the current usage 
         $$row{'CurrentUsage'}+=$$row{'_MemUsedMB'};
         # and then there is the free amount
         $debug && print "Page Data After - Used:$$row{'CurrentUsage'}, Total:$$row{'AllocatedBaseSize'}\n";
         
      }

      # at this point we can assume that we have all the data we need stored in @collected_data
      $$row{'_FreeMB'}=$$row{'AllocatedBaseSize'}-$$row{'CurrentUsage'};
      $$row{'_PeakFreeMB'}=$$row{'AllocatedBaseSize'}-$$row{'PeakUsage'};
      
      if ($$row{'_FreeMB'}<0) {
         $$row{'_FreeMB'}=0
      }
      
      if ($$row{'_PeakFreeMB'}<0) {
         $$row{'_PeakFreeMB'}=0
      }
      
      $$row{'_Used%'}=sprintf("%.0f",$$row{'CurrentUsage'}/$$row{'AllocatedBaseSize'}*100);
      $$row{'_PeakUsed%'}=sprintf("%.0f",$$row{'PeakUsage'}/$$row{'AllocatedBaseSize'}*100);
      $$row{'_Free%'}=sprintf("%.0f",$$row{'_FreeMB'}/$$row{'AllocatedBaseSize'}*100);
      $$row{'_PeakFree%'}=sprintf("%.0f",$$row{'_PeakFreeMB'}/$$row{'AllocatedBaseSize'}*100);
      $$row{'_Used'}=$$row{'CurrentUsage'}*$actual_bytefactor*$actual_bytefactor;
      $$row{'_PeakUsed'}=$$row{'PeakUsage'}*$actual_bytefactor*$actual_bytefactor;
      $$row{'_Free'}=$$row{'_FreeMB'}*$actual_bytefactor*$actual_bytefactor;
      $$row{'_PeakFree'}=$$row{'_PeakFreeMB'}*$actual_bytefactor*$actual_bytefactor;
      $$row{'_Total'}=$$row{'AllocatedBaseSize'}*$actual_bytefactor*$actual_bytefactor;
      
      if ($the_arguments{'_arg1'}=~/auto/) {
         # automatically set warning and critical levels
         # to do this we need to retrieve the users settings for page file size, initial size and maximum size
         # warning at 100% of initial size, critical at 80% of maximum size
         $debug && print "Automatically setting warning and critical levels\n";
         if ($$row{'InitialSize'} || '' ne '' and $$row{'MaximumSize'} || '' ne '') {
            # set the warn and criticals - overwriting anything else passed in on the command line
            # have to convert figures from MB to bytes and we test against the calculated field _Used
            $opt_warn=[ "_Used=" . ($$row{'InitialSize'}*$actual_bytefactor*$actual_bytefactor) ];
            $opt_critical=[ "_Used=" . (0.8*$$row{'MaximumSize'}*$actual_bytefactor*$actual_bytefactor) ];
            $debug && print "Setting levels (using Initial:$$row{'InitialSize'} and Max:$$row{'MaximumSize'}) to (for Warn and Crit) " . Dumper($opt_warn,$opt_critical);
         } else {
            # query returned but with no data
            $debug && print "WMI Join Query must not have returned InitialSize and/or MaximumSize data\n";
         }
      }
      
      my $test_result=test_limits($opt_warn,$opt_critical,$row,\%warn_perf_specs_parsed,\%critical_perf_specs_parsed,\@warn_spec_result_list,\@critical_spec_result_list);
   
      # check for Critical/Warning
      if ($test_result==$ERRORS{'CRITICAL'}) {
         $num_critical++;
      } elsif ($test_result==$ERRORS{'WARNING'}) {
         $num_warning++;
      }
         
      my ($this_display_info,$this_performance_data,$this_combined_data)=create_display_and_performance_data($row,$display_fields{$opt_mode},$performance_data_fields{$opt_mode},\%warn_perf_specs_parsed,\%critical_perf_specs_parsed);
      # concatenate the per drive results together
      $results_text.="$this_display_info     ";
      $performance_data.=$this_performance_data;
   }
}


if ($results_text) {
   # show the results
   # remove the last ", "
   $results_text=~s/, +$//;

   my $exit_type=$ERRORS{'OK'};
   $collected_data[$last_wmi_data_index][0]{'_OverallResult'}='OK';
   
   if ($num_critical>0) {
      $exit_type=$ERRORS{'CRITICAL'};
      $collected_data[$last_wmi_data_index][0]{'_OverallResult'}='CRITICAL';
   } elsif ($num_warning>0) {
      $exit_type=$ERRORS{'WARNING'};
      $collected_data[$last_wmi_data_index][0]{'_OverallResult'}='WARNING';
   }

   my ($overall_display_info,$overall_performance_data,$overall_combined_data)=create_display_and_performance_data($collected_data[$last_wmi_data_index][0],$pre_display_fields{$opt_mode},undef,\%warn_perf_specs_parsed,\%critical_perf_specs_parsed);
   $overall_combined_data=combine_display_and_perfdata("$overall_display_info$results_text",$performance_data);
   $plugin_output.=$overall_combined_data;

   finish_program($exit_type);
} else {
   $plugin_output.="UNKNOWN - Could not find a drive matching '$the_arguments{'_arg2'}' or the WMI data returned is invalid. Available Page Files are " . list_collected_values_from_all_rows(\@collected_data,['Name'],', ','',0);
   finish_program($ERRORS{'UNKNOWN'});
}

}
#-------------------------------------------------------------------------
sub checkfileage {
# initial idea from steav on github.com
# its a good idea and we modified to for our use using our programming techniques and 
# ensuring that the warning/critical criteria were consistently used
# this is where we also first introduced the time multipliers

my $perf_data_unit='hr'; # default unit is hours
# if the user specifies it but it is not valid we silently fail
if (defined($time_multipliers{$the_arguments{'_arg2'}})) {
   # looks like the user has specified a valid time multiplier for use in the performance data
   $perf_data_unit=$the_arguments{'_arg2'};  
}
my $perf_data_divisor=$time_multipliers{$perf_data_unit};

# we can not support full performance data with warn/crit since we want to divide it by whatever units the user specifies
$opt_z=''; 

my @collected_data;

my ($data_errors,$last_wmi_data_index)=get_wmi_data(1,'',
   "Select name,lastmodified from CIM_DataFile where name=\"$the_arguments{'_arg1'}\"",
   '','',\@collected_data,\$the_arguments{'_delay'},undef,1);

check_for_data_errors($data_errors);

# check to see if we found the file
if ($collected_data[$last_wmi_data_index][0]{'Name'}) {
   my $lastmodified=$collected_data[$last_wmi_data_index][0]{'LastModified'};
   my ($lastmod_sec,$fileage)=convert_WMI_timestamp_to_seconds($lastmodified);
   
   if ($lastmod_sec ne '') {
      $collected_data[$last_wmi_data_index][0]{'_FileAge'}=$fileage;
      
      my $test_result=test_limits($opt_warn,$opt_critical,$collected_data[$last_wmi_data_index][0],\%warn_perf_specs_parsed,\%critical_perf_specs_parsed,\@warn_spec_result_list,\@critical_spec_result_list);

      $collected_data[$last_wmi_data_index][0]{'_DisplayFileAge'}=sprintf("%.2f",$fileage/$perf_data_divisor);
      $collected_data[$last_wmi_data_index][0]{'_NicelyFormattedFileAge'}=display_uptime($fileage);
      $collected_data[$last_wmi_data_index][0]{'_PerfDataUnit'}=$perf_data_unit;
      
      # apply the /$perf_data_divisor throughout the performance data
      # have to take special care if no warn/crit specified
      # also, we want to apply these new warning/critical specs against the "_DisplayFileAge" field
      $warn_perf_specs_parsed{'_DisplayFileAge'}='';
      if ($warn_perf_specs_parsed{'_FileAge'} ne '') {
         $warn_perf_specs_parsed{'_DisplayFileAge'}=$warn_perf_specs_parsed{'_FileAge'}/$perf_data_divisor;
      }
      $critical_perf_specs_parsed{'_DisplayFileAge'}='';
      if ($critical_perf_specs_parsed{'_FileAge'} ne '') {
         $critical_perf_specs_parsed{'_DisplayFileAge'}=$critical_perf_specs_parsed{'_FileAge'}/$perf_data_divisor;
      }
      
      my ($this_display_info,$this_performance_data,$this_combined_data)=create_display_and_performance_data($collected_data[$last_wmi_data_index][0],$display_fields{$opt_mode},$performance_data_fields{$opt_mode},\%warn_perf_specs_parsed,\%critical_perf_specs_parsed);
      $plugin_output.=$this_combined_data;
      
      finish_program($test_result);
   } else {
      $plugin_output.="UNKNOWN - Could not correct recognise the returned time format $lastmodified";
      finish_program($ERRORS{'UNKNOWN'});
   }
} else {
   $plugin_output.="UNKNOWN - Could not find the file $the_arguments{'_arg1'}";
   finish_program($ERRORS{'UNKNOWN'});
}
   
}
#-------------------------------------------------------------------------
sub checkfilesize {
my @collected_data;
my ($data_errors,$last_wmi_data_index)=get_wmi_data(1,'',
   "Select name,filesize from CIM_DataFile where name=\"$the_arguments{'_arg1'}\"",
   '','',\@collected_data,\$the_arguments{'_delay'},undef,1);

# have to initialise this incase the file is not found
$collected_data[$last_wmi_data_index][0]{'FileSize'}=$collected_data[$last_wmi_data_index][0]{'FileSize'} || 0;
$collected_data[$last_wmi_data_index][0]{'_FileCount'}=$collected_data[$last_wmi_data_index][0]{'_FileCount'} || 0;

check_for_data_errors($data_errors);

no_data_check($collected_data[$last_wmi_data_index][0]{'_ItemCount'});

my $test_result=test_limits($opt_warn,$opt_critical,$collected_data[$last_wmi_data_index][0],\%warn_perf_specs_parsed,\%critical_perf_specs_parsed,\@warn_spec_result_list,\@critical_spec_result_list);
my ($this_display_info,$this_performance_data,$this_combined_data)=create_display_and_performance_data($collected_data[$last_wmi_data_index][0],$display_fields{$opt_mode},$performance_data_fields{$opt_mode},\%warn_perf_specs_parsed,\%critical_perf_specs_parsed);
$plugin_output.=$this_combined_data;;

finish_program($test_result);
}
#-------------------------------------------------------------------------
sub checkfoldersize {
# make sure the path ends with a / to make sure we only get matching folders
if ($the_arguments{'_arg1'}!~/\/$/) {
   # no slash on the end so add it
   $the_arguments{'_arg1'}="$the_arguments{'_arg1'}/";
}

# we split up the query to drive letter and path since this should be faster than a linear search for all matching filenames
my $drive_letter='';
my $path='';
if ($the_arguments{'_arg1'}=~/^(\w:)(.*)/) {
   $drive_letter=$1;
   $path=$2;
} else {
   $plugin_output.="Could not extract drive letter and path from $the_arguments{'_arg1'}\n";
   finish_program($ERRORS{'UNKNOWN'});
}

my $wildcard='';
my $operator='=';
# have to treat _arg4 like this since its default value is undef
if (defined($the_arguments{'_arg4'})) {
   if ($the_arguments{'_arg4'} eq 's') {
      # we want to get all sub dirs as well
      $wildcard='%';
      $operator='like';
   }
}

my @collected_data;

my ($data_errors,$last_wmi_data_index)=get_wmi_data(1,'',
   "Select name,filesize from CIM_DataFile where drive=\"$drive_letter\" AND path $operator \"${path}$wildcard\"",
   '','',\@collected_data,\$the_arguments{'_delay'},['FileSize'],1);

# have to initialise this incase the file is not found
$collected_data[$last_wmi_data_index][0]{'_FolderSize'}=0;

check_for_data_errors($data_errors);
no_data_check($collected_data[$last_wmi_data_index][0]{'_ItemCount'});

# Load the _FolderSize so that the user can specify warn/critical criteria
$collected_data[$last_wmi_data_index][0]{'_FolderSize'}=$collected_data[$last_wmi_data_index][0]{'_ColSum_FileSize'}||0; # this was automatically calculated for us
$collected_data[$last_wmi_data_index][0]{'_FileList'}='';

if ($collected_data[$last_wmi_data_index][0]{'_ItemCount'}>0) {
   $collected_data[$last_wmi_data_index][0]{'_FileList'}=" (List is on next line)\nThe file(s) found are " . list_collected_values_from_all_rows(\@collected_data,['Name'],"\n",'',0);
}

my $test_result=test_limits($opt_warn,$opt_critical,$collected_data[$last_wmi_data_index][0],\%warn_perf_specs_parsed,\%critical_perf_specs_parsed,\@warn_spec_result_list,\@critical_spec_result_list);
my ($this_display_info,$this_performance_data,$this_combined_data)=create_display_and_performance_data($collected_data[$last_wmi_data_index][0],$display_fields{$opt_mode},$performance_data_fields{$opt_mode},\%warn_perf_specs_parsed,\%critical_perf_specs_parsed);
$plugin_output.=$this_combined_data;

finish_program($test_result);
}
#-------------------------------------------------------------------------
sub checkgroup {
$use_pro_library && checkgroup_pro();
}
#-------------------------------------------------------------------------
sub checkgroupuser {
$use_pro_library && checkgroupuser_pro();
}
#-------------------------------------------------------------------------
sub checklogon {
$use_pro_library && checklogon_pro();
}
#-------------------------------------------------------------------------
sub checkwsusserver {

print "This mode has been removed. Read the --help to see how to perform the equivalent check";
finish_program($ERRORS{'CRITICAL'});

my $age = DateTime->now(time_zone => 'local')->subtract(hours => 24);
my $where_time_part="TimeGenerated > \"" . $age->year . sprintf("%02d",$age->month) . sprintf("%02d",$age->day) . sprintf("%02d",$age->hour) . sprintf("%02d",$age->minute) . "00.00000000\""; # for clarity

my @collected_data;
my ($data_errors,$last_wmi_data_index)=get_wmi_data(1,'',
   "Select SourceName,Message from Win32_NTLogEvent where Logfile=\"Application\" and EventType < 2 and SourceName = \"Windows Server Update Services\" and $where_time_part",
   '','',\@collected_data,\$the_arguments{'_delay'},undef,0);

check_for_data_errors($data_errors);

if ($collected_data[$last_wmi_data_index][0]{'_ItemCount'}==0) {
   # nothing returned, assume all ok
   print "OK - WSUS Database clean.\n";
   finish_program($ERRORS{'OK'});
} else {
   my $output;
   $output =~ s/\r(Application)\|/Application\|/g;
   $output =~ s/\r//g;
   $output =~ s/\n//g;
   $output =~ s/\|/-/g;
   $output =~ s/(Application)-/\n\nApplication-/g;
   $output = substr($output, 64);
   print "CRITICAL: WSUS Server has errors, check eventlog for download failures, database may need to be purged by running the Server Cleanup Wizard.\|;\n$output";
   finish_program($ERRORS{'CRITICAL'});
}

}
#-------------------------------------------------------------------------
sub checkprintjob {
$use_pro_library && checkprintjob_pro();
}
#-------------------------------------------------------------------------
sub checkprocess {

# setup the field we will use to search using the regex
my $query_field='Name';
if ($opt_submode=~/c/i) {
   $query_field='CommandLine';
} elsif ($opt_submode=~/e/i) {
   $query_field='ExecutablePath';
}

# setup the field we will use to display the process
my $listing_field='Name';
if ($the_arguments{'_arg2'}=~/c/i) {
   $listing_field='CommandLine';
} elsif ($the_arguments{'_arg2'}=~/e/i) {
   $listing_field='ExecutablePath';
}

# arg1 might have / in it
# replace any / with . for searching purposes only
my $process_include_regex=$the_arguments{'_arg1'};
# use # as the reg ex delimiter since the user might specify /
$process_include_regex=~s#\/#\\\\#g;

# arg3 might have / in it
# replace any / with . for searching purposes only
my $process_exclude_regex=$the_arguments{'_arg3'};
# use # as the reg ex delimiter since the user might specify /
$process_exclude_regex=~s#\/#\\\\#g;


my @collected_data;
my ($data_errors,$last_wmi_data_index)=get_wmi_data(1,'',
   "select Name,CommandLine,ExecutablePath from Win32_Process",
   '','',\@collected_data,\$the_arguments{'_delay'},undef,0);

check_for_data_errors($data_errors);

# process includes and excludes of WMI data for Pro - after all WMI queries and joins and after check_for_data_errors - before we start looking through the returned WMI data
$use_pro_library && process_cludes_like_a_pro(\@opt_include_data,\@opt_exclude_data,\@collected_data,1,$last_wmi_data_index);

# at this point we can assume that we have all the data we need stored in @collected_data
my $result_text='';
# now loop through the results, showing the ones requested
# so we want to loop through all the rows in the first query result $collected_data[0] and keep only the ones matching the regex
my @new_data=();

# sometimes the query seems to complete but returns no data at all so the pattern match in the for loop below gets an unitialised error
# we are still trying to find the exact circumstances of this problem so we are trying some protection for it
# we think the WMI query returns ok but is empty so we think _ItemCount is set to 0
#   This code is used to try and simulate the error condition
#   my %hash=(
#       _ChecksOK=>0,
#       _ItemCount=>0,
#   );
#   @{$collected_data[$last_wmi_data_index]}=\%hash;
#   print Dumper(\@collected_data);
# the no data check will exit the plugin if no data is returned and print a message about it
# if the user has used --nodatamode then it will still get the error if no data is returned
# but we never told them they could do that .....
no_data_check($collected_data[$last_wmi_data_index][0]{'_ItemCount'}); # this seems pointless since we should always return a list of processes - unless there is an error, in which case, it should get stopped above

my $num_excluded=0;

foreach my $row (@{$collected_data[$last_wmi_data_index]}) {
   # there are still some cases where the query seems to come back ok but have malformed data or something - lets try testing defined()
   if (defined($$row{$query_field})) {
      if ( $$row{$query_field}=~/$process_include_regex/i ) {
         # process any exclusions, if they have been defined
         my $process_this_row=1;
         if ($process_exclude_regex) {
            # exclusion regex defined, decide if we want this row
            if ($$row{$query_field}=~/$process_exclude_regex/i) {
               # regex matches so exclude this row
               $num_excluded++;
               $debug && print "---> Excluding \"$$row{$query_field}\"\n";
               $process_this_row=0;
            }
         }

         if ($process_this_row) {
            # this process should be included
            $debug && print "Including this process: " . Dumper($row) . "\n";
            push(@new_data,$row);
         }
      }
   }
}

# now reload the array with the data we want to keep
$collected_data[$last_wmi_data_index]=\@new_data;
# update the count
$collected_data[$last_wmi_data_index][0]{'_ItemCount'}=$#new_data+1;
$collected_data[$last_wmi_data_index][0]{'_NumExcluded'}=$num_excluded;
$debug && print "Including only the following processes " . Dumper(\@collected_data);

my $test_result=test_limits($opt_warn,$opt_critical,$collected_data[$last_wmi_data_index][0],\%warn_perf_specs_parsed,\%critical_perf_specs_parsed,\@warn_spec_result_list,\@critical_spec_result_list);

$collected_data[$last_wmi_data_index][0]{'ProcessList'}='';

if ($collected_data[$last_wmi_data_index][0]{'_ItemCount'}>0) {
   $collected_data[$last_wmi_data_index][0]{'ProcessList'}=" (List is on next line)\nThe process(es) found are " . list_collected_values_from_all_rows(\@collected_data,[$listing_field],",   ",'',1);;
}

my ($this_display_info,$this_performance_data,$this_combined_data)=create_display_and_performance_data($collected_data[$last_wmi_data_index][0],$display_fields{$opt_mode},$performance_data_fields{$opt_mode},\%warn_perf_specs_parsed,\%critical_perf_specs_parsed);

$plugin_output.=$this_combined_data;
finish_program($test_result);
}
#-------------------------------------------------------------------------
sub checkquota {
$use_pro_library && checkquota_pro();
}
#-------------------------------------------------------------------------
sub checktime {

my @collected_data;

# expect ouput like
#CLASS: Win32_UTCTime
#Day|DayOfWeek|Hour|Milliseconds|Minute|Month|Quarter|Second|WeekInMonth|Year
#8|3|11|0|39|5|2|41|2|2013

my $before_epoch=time();
my ($data_errors,$last_wmi_data_index)=get_wmi_data(1,'',
   "Select * from Win32_UTCTime",
   '','',\@collected_data,\$the_arguments{'_delay'},undef,0);

check_for_data_errors($data_errors);

my $after_epoch=time();

# convert the returned time to an epoch based time
my $windows_dt = DateTime->new(
      year       => $collected_data[$last_wmi_data_index][0]{'Year'},
      month      => $collected_data[$last_wmi_data_index][0]{'Month'},
      day        => $collected_data[$last_wmi_data_index][0]{'Day'},
      hour       => $collected_data[$last_wmi_data_index][0]{'Hour'},
      minute     => $collected_data[$last_wmi_data_index][0]{'Minute'},
      second     => $collected_data[$last_wmi_data_index][0]{'Second'},
  );

my $cwp_dt=DateTime->from_epoch( epoch => $after_epoch );

# it looks like the epoch time we collect locally is going to be closer to the Windows time more often
$collected_data[$last_wmi_data_index][0]{'_CWPSec'}=$after_epoch;
$collected_data[$last_wmi_data_index][0]{'_WindowsSec'}=$windows_dt->epoch();
$collected_data[$last_wmi_data_index][0]{'_DiffSec'}=$after_epoch-$windows_dt->epoch();

# build the display fields
$collected_data[$last_wmi_data_index][0]{'_CWPTime'}=create_datetime_displaytime($cwp_dt);
$collected_data[$last_wmi_data_index][0]{'_WindowsTime'}=create_datetime_displaytime($windows_dt);

$debug && print Dumper(\@collected_data);

my $test_result=test_limits($opt_warn,$opt_critical,$collected_data[$last_wmi_data_index][0],\%warn_perf_specs_parsed,\%critical_perf_specs_parsed,\@warn_spec_result_list,\@critical_spec_result_list);
my ($this_display_info,$this_performance_data,$this_combined_data)=create_display_and_performance_data($collected_data[$last_wmi_data_index][0],$display_fields{$opt_mode},$performance_data_fields{$opt_mode},\%warn_perf_specs_parsed,\%critical_perf_specs_parsed);
$plugin_output.=$this_combined_data;

finish_program($test_result);
  
}
#-------------------------------------------------------------------------
sub checkservice {
# ------------------------ checking all services
my $where_bit='';
my $auto_mode='';
if (lc($the_arguments{'_arg1'}) eq 'auto') {
   # for this query we need to look for all automatic services
   # check that all auto services are 
   # STARTED=True, STATE=Running and STATUS=OK
   # we do a query that actually always should return data so that we know that the query works
   # we could do a select just listing the bad ones, but it returns nothing if good. hard to tell if it really worked ok.
   $where_bit="where StartMode=\"auto\"";
   $auto_mode=1;
} else {
   # for this query we have been passed a regex and must look for that
   # so the WMI query should return all services and then we will apply the regex
   # this is the default
}

# wmic returns something like:
# CLASS: Win32_Service
# DisplayName|Name|Started|StartMode|State|Status
# Telnet|TlntSvr|False|Auto|Stopped|OK
# Security Center|wscsvc|True|Auto|Running|OK

my @collected_data;
my ($data_errors,$last_wmi_data_index)=get_wmi_data(1,'',
   "select name, displayname, Started, StartMode, State, Status FROM Win32_Service $where_bit",
   '','',\@collected_data,\$the_arguments{'_delay'},undef,0);

check_for_data_errors($data_errors);

# process includes and excludes of WMI data for Pro - after all WMI queries and joins and after check_for_data_errors - before we start looking through the returned WMI data
$use_pro_library && process_cludes_like_a_pro(\@opt_include_data,\@opt_exclude_data,\@collected_data,1,$last_wmi_data_index);

# at this point we can assume that we have all the data we need stored in @collected_data
my %result_text=(
   all   => '',
   ok    => 'Showing only OK: ',
   bad   => 'Showing only BAD: ',
   none  => 'Showing no results. ',
   );
# now loop through the results, showing the ones requested
my $num_ok=0;
my $num_bad=0;
my $num_excluded=0;
# so we want to loop through all the rows in the first query result $collected_data[$last_wmi_data_index]
foreach my $row (@{$collected_data[$last_wmi_data_index]}) {
   # in the middle of the WMI output there are lines like:
   # CLASS: Win32_Service
   # CLASS: Win32_TerminalService
   # which means DisplayName and Name might not be set so we need to test for this to stop
   # "Use of uninitialized value in pattern match" errors
   if ($$row{'DisplayName'} && $$row{'Name'}) {
      if (  $auto_mode || 
            ( !$auto_mode && ($$row{'DisplayName'}=~/$the_arguments{'_arg1'}/i || $$row{'Name'}=~/$the_arguments{'_arg1'}/i) ) 
         ) {

         my $process_this_row=1;
         # if argument 4 is defined then we need to include only services matching it
         if ($the_arguments{'_arg4'}) {
            # startmode inclusion regex defined, decide if we want this row
            if ($$row{'StartMode'}=~/$the_arguments{'_arg4'}/i) {
               # regex matches so include this row
               $debug && print "---> Including by Startmode \"$$row{'DisplayName'}\" ($$row{'Name'}), StartMode=$$row{'StartMode'}\n";
               $process_this_row=1;
            } else {
               # exclude this row
               $debug && print "---> Excluding by Startmode \"$$row{'DisplayName'}\" ($$row{'Name'}), StartMode=$$row{'StartMode'}\n";
               $process_this_row=0;
            }
         }

         # process any exclusions, if they have been defined
         if ($the_arguments{'_arg2'}) {
            # exclusion regex defined, decide if we want this row
            if ($$row{'DisplayName'}=~/$the_arguments{'_arg2'}/i || $$row{'Name'}=~/$the_arguments{'_arg2'}/i) {
               # regex matches so exclude this row
               $num_excluded++;
               $debug && print "---> Excluding \"$$row{'DisplayName'}\" ($$row{'Name'})\n";
               $process_this_row=0;
            }
         }
         
         if ($process_this_row) {
            $debug && print "Including the following service: " . Dumper($row) . "\n";
            my $status_display_info='';
            if (lc($$row{'Status'}) ne 'ok') {
               $status_display_info=" ($$row{'Status'})";
            }
            if ($$row{'Started'} eq 'True' && $$row{'State'} eq 'Running' && $$row{'Status'} eq 'OK') {
               $num_ok++;
               if (!$auto_mode) {
                  # if we have using the regex mode then list out the services we find
                  $result_text{'ok'}.=    "'$$row{'DisplayName'}' ($$row{'Name'}) is $$row{'State'}$status_display_info, ";
                  $result_text{'all'}.="'$$row{'DisplayName'}' ($$row{'Name'}) is $$row{'State'}$status_display_info, ";
               }
            } else {
               $num_bad++;
               $result_text{'bad'}.=   "'$$row{'DisplayName'}' ($$row{'Name'}) is $$row{'State'}$status_display_info, ";
               $result_text{'all'}.="'$$row{'DisplayName'}' ($$row{'Name'}) is $$row{'State'}$status_display_info, ";
            }
         }
      }
   }
}

$result_text{'all'}=~s/, $/./;
$result_text{'ok'}=~s/, $/./;
$result_text{'bad'}=~s/, $/./;

$debug && print "Showing ResultText: " . Dumper(\%result_text);

# load some values to check warn/crit against
$collected_data[$last_wmi_data_index][0]{'_NumGood'}=$num_ok;
$collected_data[$last_wmi_data_index][0]{'_NumBad'}=$num_bad;
$collected_data[$last_wmi_data_index][0]{'_NumExcluded'}=$num_excluded;
$collected_data[$last_wmi_data_index][0]{'_Total'}=$num_ok+$num_bad;

my $test_result=test_limits($opt_warn,$opt_critical,$collected_data[$last_wmi_data_index][0],\%warn_perf_specs_parsed,\%critical_perf_specs_parsed,\@warn_spec_result_list,\@critical_spec_result_list);

# we need to know the result (warn,crit etc) to help us decide what to display
interpret_mode_list(lc($the_arguments{'_arg3'}));
# using the value of $test_result as a key into %displaywhatwhen_mode_list
# the resulting value tells me what I should display
# the resulting value is a key into %result_text
$debug && print "Since status=$test_result, results shown are: $displaywhatwhen_mode_list{$test_result}\n";
$collected_data[$last_wmi_data_index][0]{'_ServiceList'}=$result_text{$displaywhatwhen_mode_list{$test_result}};

my ($this_display_info,$this_performance_data,$this_combined_data)=create_display_and_performance_data($collected_data[$last_wmi_data_index][0],$display_fields{$opt_mode},$performance_data_fields{$opt_mode},\%warn_perf_specs_parsed,\%critical_perf_specs_parsed);
$plugin_output.=$this_combined_data;

finish_program($test_result);

}
#-------------------------------------------------------------------------
sub checkshare {
$use_pro_library && checkshare_pro();
}
#-------------------------------------------------------------------------
sub checksmart {
   
# 4 arrays for 4 wmi queries
my @collected_data;
my @smart_data;
my @pnpdevice_mapping;
my @serial_mapping;

my $data_errors;
my $last_wmi_data_index;
my $num_ok=0;
my $num_bad=0;
my $results_text='';
my $result_code=$ERRORS{'UNKNOWN'};
my $performance_data='';

# see if the user has asked for fewer than default SMART attributes
if ($the_arguments{'_arg1'}) {
   # this should be a comma delimited list of SMART attributes matching the ones from %smartattributes
   # if they have specified the word "none" then we will not show any smart attributes
   if (lc($the_arguments{'_arg1'}) eq 'none') {
      # wipe out %smartattributes
      %smartattributes=();
   } else {
      my @requested_smart_list=split(/,/,$the_arguments{'_arg1'});
      my %new_smartattributes=();
      foreach my $code (@requested_smart_list) {
         if (exists($smartattributes{$code})) {
            $new_smartattributes{$code}=$smartattributes{$code};
         }
      }
      if (scalar keys %new_smartattributes==0) {
         # show user a list of valid attributes
         $plugin_output.="Valid Attribute Codes are: ";
         foreach my $code (sort keys %smartattributes) {
            $plugin_output.="$code ($smartattributes{$code})  ";
         }
         finish_program($ERRORS{'UNKNOWN'});
      }
      %smartattributes=%new_smartattributes;
   }
}

# first get the smart status
($data_errors,$last_wmi_data_index)=get_wmi_data(1,'root/wmi',
   "Select Active,InstanceName,PredictFailure from MSStorageDriver_FailurePredictStatus",
   '','',\@collected_data,\$the_arguments{'_delay'},undef,0);
check_for_data_errors($data_errors);

# now get the smart data and join it to the smart status
# only do it if user has asked for smartattributes
if (scalar keys %smartattributes) {
   my ($dummy_data_errors,$dummy_last_wmi_data_index)=wmi_data_join('',\@collected_data,$last_wmi_data_index,'InstanceName','',undef,'InstanceName','',undef,1,'root/wmi',
      "Select Active,InstanceName,VendorSpecific from MSStorageDriver_FailurePredictData",
      '','',\@smart_data,\$the_arguments{'_delay'},undef,0);
}

# now join the mapping between DeviceID and PNPDeviceID onto the smart status
# in this case we need the InstanceName seems to have an extra _0 on the end of it compared to PNPDeviceID
# we remove this _0 by using a regex on the base data
# we specify these joins as being able to use a state file since we expect them to be quite static
my ($dummy_data_errors,$dummy_last_wmi_data_index)=wmi_data_join('InstPNPDev',\@collected_data,$last_wmi_data_index,'InstanceName','^(.*?)_\d+$',undef,'PNPDeviceID','',undef,1,'',
   "Select DeviceID,Model,PNPDeviceID from Win32_DiskDrive",
   '','',\@pnpdevice_mapping,\$the_arguments{'_delay'},undef,0);

# finally join the mapping between DeviceID (tag) Serial Number onto the smart status
# we specify these joins as being able to use a state file since we expect them to be quite static
($dummy_data_errors,$dummy_last_wmi_data_index)=wmi_data_join('TagSN',\@collected_data,$last_wmi_data_index,'DeviceID','',undef,'Tag','',undef,1,'',
   "Select Tag,SerialNumber from Win32_PhysicalMedia",
   '','',\@serial_mapping,\$the_arguments{'_delay'},undef,0);

# process includes and excludes of WMI data for Pro - after all WMI queries and joins and after check_for_data_errors - before we start looking through the returned WMI data
$use_pro_library && process_cludes_like_a_pro(\@opt_include_data,\@opt_exclude_data,\@collected_data,1,$last_wmi_data_index);

# now that we have joined all our data we should be able to check our smart status, show various smart values and display them with the model and serial numbers

# now loop through the results, showing the ones requested
foreach my $row (@{$collected_data[$last_wmi_data_index]}) {

   # get the physical disk number which is the last number from DeviceID
   if ($$row{'DeviceID'}=~/(\d+)$/) {
      $$row{'_PhysicalDeviceID'}=$1;
   } else {
      $$row{'_PhysicalDeviceID'}='';
   }
   
   if ($$row{'SerialNumber'}=~/null/i) {
      # could not get the serial so just use the physical id
      $$row{'_DiskDisplayName'}="Disk#$$row{'_PhysicalDeviceID'}";
   } else {
      # removing leading spaces from the serial number and trailing spaces
      $$row{'SerialNumber'}=~s/^\s*//;
      $$row{'SerialNumber'}=~s/\s*$//;
      $$row{'_DiskDisplayName'}="$$row{'SerialNumber'}";
   }

   # see if the drive is good
   if ($$row{'PredictFailure'} eq 'True') {
      $num_bad++;
      $$row{'_DiskFailing'}='1'; # 1 for failing
   } else {
      $num_ok++;
      $$row{'_DiskFailing'}='0'; # 0 for ok
      #################### FOR TESTING FAILURE ###################
#      if ($$row{'_PhysicalDeviceID'}==0) { # make it look like disk 0 is failing
#         # make this disk look like a fail
#         $$row{'_DiskFailing'}='1';
#         $$row{'PredictFailure'}='True';
#         $num_ok--;
#         $num_bad++;
#      }
      #################### FOR TESTING FAILURE ###################
   }
   
   # add in the smart attribue data
   # parse the vendorspecific code if there is any data
   if (exists($$row{'VendorSpecific'})) {
      while ($$row{'VendorSpecific'}=~/(\d*),(\d*),(\d*),(\d*),(\d*),(\d*),(\d*),(\d*),(\d*),(\d*),(\d*),(\d*),/sg) {
         # see if this attribute codeis in our hash 
         if (exists($smartattributes{$3})) {
            # add it to this row after calculating it
            $$row{$smartattributes{$3}}=$8+256*$9;
            $debug && print "Calculating $3 - $smartattributes{$3} = $$row{$smartattributes{$3}}\n";
         }
      }
   }

   my $test_result=test_limits($opt_warn,$opt_critical,$row,\%warn_perf_specs_parsed,\%critical_perf_specs_parsed,\@warn_spec_result_list,\@critical_spec_result_list);
   
   my ($this_display_info,$this_performance_data,$this_combined_data)=create_display_and_performance_data($row,$display_fields{$opt_mode},$performance_data_fields{$opt_mode},\%warn_perf_specs_parsed,\%critical_perf_specs_parsed);
   
   # concatenate the per drive results together
   $results_text.="$this_display_info\n";
   $performance_data.=$this_performance_data;

}

# load some values to check warn/crit against
$collected_data[$last_wmi_data_index][0]{'_NumGood'}=$num_ok;
$collected_data[$last_wmi_data_index][0]{'_NumBad'}=$num_bad;
$collected_data[$last_wmi_data_index][0]{'_Total'}=$num_ok+$num_bad;

my $overall_test_result=work_out_overall_exit_code(\@collected_data,1,$last_wmi_data_index);

my ($overall_display_info,$overall_performance_data,$overall_combined_data)=create_display_and_performance_data($collected_data[$last_wmi_data_index][0],$pre_display_fields{$opt_mode},undef,\%warn_perf_specs_parsed,\%critical_perf_specs_parsed);

$overall_combined_data=combine_display_and_perfdata("$overall_display_info\n$results_text",$performance_data);
$plugin_output.=$overall_combined_data;

finish_program($overall_test_result);
}
#-------------------------------------------------------------------------
sub checkstartupcommand {
$use_pro_library && checkstartupcommand_pro();
}
#-------------------------------------------------------------------------
sub checkuptime {
my @collected_data;
# expect ouput like
#CLASS: Win32_PerfFormattedData_PerfOS_System
#SystemUpTime
#33166
my ($data_errors,$last_wmi_data_index)=get_wmi_data(1,'',
   "Select SystemUpTime,Frequency_Sys100NS,Timestamp_Object from Win32_PerfRawData_PerfOS_System",
   '','',\@collected_data,\$the_arguments{'_delay'},undef,0);

check_for_data_errors($data_errors);

calc_new_field('_UptimeSec','PERF_ELAPSED_TIME','SystemUpTime,%.2f',\@collected_data,$last_wmi_data_index,0);
$collected_data[$last_wmi_data_index][0]{'_UptimeMin'}=int($collected_data[$last_wmi_data_index][0]{'_UptimeSec'}/60);
$collected_data[$last_wmi_data_index][0]{'_UptimeHours'}=$collected_data[$last_wmi_data_index][0]{'_UptimeMin'}/60;
$collected_data[$last_wmi_data_index][0]{'_UptimeDays'}=$collected_data[$last_wmi_data_index][0]{'_UptimeHours'}/24;
$collected_data[$last_wmi_data_index][0]{'_DisplayTime'}=display_uptime($collected_data[$last_wmi_data_index][0]{'_UptimeSec'});

my $test_result=test_limits($opt_warn,$opt_critical,$collected_data[$last_wmi_data_index][0],\%warn_perf_specs_parsed,\%critical_perf_specs_parsed,\@warn_spec_result_list,\@critical_spec_result_list);

# since we test warnings against _UptimeSec but want to show performance data for _UptimeMin we have to load the performance data for _UptimeMin
# apply the /60 throughout the performance data - since _UptimeSec is in seconds but we want to use Minutes for perf data
# have to take special care if no warn/crit specified
# also, we want to apply these new warning/critical specs against the "_UptimeMin" field
$warn_perf_specs_parsed{'_UptimeMin'}='';
if ($warn_perf_specs_parsed{'_UptimeSec'} ne '') {
   $warn_perf_specs_parsed{'_UptimeMin'}=$warn_perf_specs_parsed{'_UptimeSec'}/60;
}
$critical_perf_specs_parsed{'_UptimeMin'}='';
if ($critical_perf_specs_parsed{'_UptimeSec'} ne '') {
   $critical_perf_specs_parsed{'_UptimeMin'}=$critical_perf_specs_parsed{'_UptimeSec'}/60;
}


my ($this_display_info,$this_performance_data,$this_combined_data)=create_display_and_performance_data($collected_data[$last_wmi_data_index][0],$display_fields{$opt_mode},$performance_data_fields{$opt_mode},\%warn_perf_specs_parsed,\%critical_perf_specs_parsed);
$plugin_output.=$this_combined_data;

finish_program($test_result);
}
#-------------------------------------------------------------------------
sub checkuseraccount {
$use_pro_library && checkuseraccount_pro();
}
#-------------------------------------------------------------------------
sub checkdrivesize {
my @collected_data;
my ($data_errors,$last_wmi_data_index)=get_wmi_data(1,'',
   "Select DeviceID,freespace,Size,VolumeName from Win32_LogicalDisk where DriveType=3",
   '','',\@collected_data,\$the_arguments{'_delay'},['FreeSpace','Size'],0);

#CLASS: Win32_LogicalDisk
#DeviceID|FreeSpace|Size|VolumeName
#C:|9679720448|21467947008|
#M:|2125115392|2138540032|Temp Disk 1
#N:|2125115392|2138540032|Temp Disk 2

check_for_data_errors($data_errors);

# process includes and excludes of WMI data for Pro - after all WMI queries and joins and after check_for_data_errors - before we start looking through the returned WMI data
$use_pro_library && process_cludes_like_a_pro(\@opt_include_data,\@opt_exclude_data,\@collected_data,1,$last_wmi_data_index);

my $results_text='';
my $result_code=$ERRORS{'UNKNOWN'};
my $performance_data='';
my $num_critical=0;
my $num_warning=0;
my $num_ok=0;
my $alldisk_identifier='Overall Disk';

$debug && print "WMI Index = $last_wmi_data_index\n";

if ($the_arguments{'_arg3'}) {
   # include the system totals
   # now we want to add a index before 0 so we copy everything from index 0 and unshift it to the front
   # we do it like this so that all the derived values normally stored in index 0 will remain there
   # then we overwrite the fields we want with new fake ones
   # note that the sum fields will be the orginal totals etc
   # now add this on to the existing data

   my %new_row=%{$collected_data[$last_wmi_data_index][0]};
   unshift(@{$collected_data[$last_wmi_data_index]},\%new_row);

   # now we have index 1 and index 0 the same data
   # add the new fake system total info
   # we make it look like WMI returned info about a disk call SystemTotalDisk
      $collected_data[$last_wmi_data_index][0]{'DeviceID'}=$alldisk_identifier;
      $collected_data[$last_wmi_data_index][0]{'FreeSpace'}=$collected_data[$last_wmi_data_index][0]{'_ColSum_FreeSpace'};
      $collected_data[$last_wmi_data_index][0]{'Size'}=$collected_data[$last_wmi_data_index][0]{'_ColSum_Size'};
      $collected_data[$last_wmi_data_index][0]{'VolumeName'}=$alldisk_identifier;

}

if (!defined($the_arguments{'_arg4'})) {
   # set it to the default of zero
   $the_arguments{'_arg4'}='00';
}

# work out the display modes
# ARG4 is a 2 character string formatted like XY
# where 
# X=0, display not ok drives first
# X=1, display drives in the order of the WMI query results
# X=2, only display not ok drives
# X=3, normal display (like X=1) when all ok, but if some not ok, then only show not
# Y=0, show results on a single line
# Y=1, show results as multi-line with the first line being a high level summary of status 
my $display_mode_x=substr($the_arguments{'_arg4'},0,1) || '0';
my $display_mode_y=substr($the_arguments{'_arg4'},1,1) || '0';

my $inter_item_line_feed='     ';
if ($display_mode_y eq '1') {
   $inter_item_line_feed="\n";
}

# now loop through the results, showing the ones requested
my $items_with_ok_status='';
my $items_with_not_ok_status='';
my $items_with_ok_status_summary='';
foreach my $row (@{$collected_data[$last_wmi_data_index]}) {
   # make sure $$row{'VolumeName'} is initialised (it won't be unless the drive has been named)
   $debug && print "ROW BEFORE: " . Dumper($row);
   $$row{'VolumeName'}=$$row{'VolumeName'} || '';
   # if $the_arguments{'_arg1'} is left out it will be blank and will match all drives
   if ($$row{'DeviceID'}=~/$the_arguments{'_arg1'}/i || $$row{'VolumeName'}=~/$the_arguments{'_arg1'}/i || ($$row{'DeviceID'} eq $alldisk_identifier && $the_arguments{'_arg3'}) ) {
      # include this drive in the results
      if ($$row{'Size'} ne '') {
         # got valid data
         # add our calculated data to the hash
         $$row{'_DriveSizeGB'}=sprintf("%.2f", $$row{'Size'}/$actual_bytefactor/$actual_bytefactor/$actual_bytefactor);
         $$row{'_UsedSpace'}=$$row{'Size'}-$$row{'FreeSpace'};
         if ($$row{'Size'}>0) {
            $$row{'_Used%'}=sprintf("%.1f",$$row{'_UsedSpace'}/$$row{'Size'}*100);
         } else {
            $$row{'_Used%'}=0;
         }
         $$row{'_UsedGB'}=sprintf("%.2f", $$row{'_UsedSpace'}/$actual_bytefactor/$actual_bytefactor/$actual_bytefactor);
         if ($$row{'Size'}>0) {
            $$row{'_Free%'}=sprintf("%.1f",$$row{'FreeSpace'}/$$row{'Size'}*100);
         } else {
            $$row{'_Free%'}=0;
         }
         $$row{'_FreeGB'}=sprintf("%.2f", $$row{'FreeSpace'}/$actual_bytefactor/$actual_bytefactor/$actual_bytefactor);
         
         my $test_result=test_limits($opt_warn,$opt_critical,$row,\%warn_perf_specs_parsed,\%critical_perf_specs_parsed,\@warn_spec_result_list,\@critical_spec_result_list);
         
         # check for Critical/Warning
         if ($test_result==$ERRORS{'CRITICAL'}) {
            $num_critical++;
         } elsif ($test_result==$ERRORS{'WARNING'}) {
            $num_warning++;
         } elsif ($test_result==$ERRORS{'OK'}) {
            $num_ok++;
         }

         # by default, in the performance data we use the drive letter to identify the drive
         # if the user has specified $other_opt_arguments=1 then we use the volume name (if it has one)
         my $drive_identifier=$$row{'DeviceID'};
         if ($the_arguments{'_arg2'} && exists($$row{'VolumeName'})) {
            if ($$row{'VolumeName'}) {
               $drive_identifier=$$row{'VolumeName'};
            }
         }
         # stick the drive identifier into the values so it can be accessed
         $$row{'DiskDisplayName'}=$drive_identifier;
         
         my ($this_display_info,$this_performance_data,$this_combined_data)=create_display_and_performance_data($row,$display_fields{$opt_mode},$performance_data_fields{$opt_mode},\%warn_perf_specs_parsed,\%critical_perf_specs_parsed);

         # setup various variables with the display results
         # we decide which combinations we use later on
         if ($test_result==$ERRORS{'OK'}) {
            # this drive is OK, so collect it and then show all the OK drives at the end
            $items_with_ok_status.="$this_display_info$inter_item_line_feed";
            $items_with_ok_status_summary.="$$row{'DiskDisplayName'},";
         } else {
            # this drive is not OK, show show it now
            $items_with_not_ok_status.="$this_display_info$inter_item_line_feed";
         }
         
         # alway set up the normal order results
         $results_text.="$this_display_info$inter_item_line_feed";

         # concatenate the per drive performance results together always in normal order
         $performance_data.=$this_performance_data;

      } else {
         # this drive does not get included in the results size there is a problem with its data
      }
   }
   $debug && print "ROW AFTER: " . Dumper($row);   
}

# decide which drives to show
if ($display_mode_x eq '0') {
   # X=0, normal full display, not ok drives first
   $results_text="$items_with_not_ok_status$items_with_ok_status";
} elsif ($display_mode_x eq '1') {
   # X=1, display drives in the order of the WMI query results
   # $results_text is left untouched
} elsif ($display_mode_x eq '2') {
   # X=2, only display not ok drives
   # remove last comma from summary list
   $items_with_ok_status_summary=~s/, *$//;
   $results_text="$items_with_not_ok_status. Not showing $num_ok items with an OK status ($items_with_ok_status_summary)";
} elsif ($display_mode_x eq '3') {
   # X=3, normal display (like X=1) when all ok, but if some not ok, then only show not
   if ($items_with_not_ok_status) {
      # remove last comma from summary list
      $items_with_ok_status_summary=~s/, *$//;
      # display is like X=2, since there are some not ok drives
      $results_text="${items_with_not_ok_status}Not showing $num_ok items with an OK status ($items_with_ok_status_summary)";
   } else {
      # leave $results_text untouched since there are no not_ok drives
   }
}

if ($display_mode_y eq '1') {
   # we have a multiline display, so make the first line a summary status
   $results_text="Drive Status Summary: OK=$num_ok, WARNING=$num_warning, CRITICAL=$num_critical. Details on the next line\n$results_text";
}

if ($results_text) {
   # show the results
   # remove the last ", "
   $results_text=~s/, +$//;
   # correctly combine the results and perfdata
   my $combined_string=combine_display_and_perfdata($results_text,$performance_data);
   $plugin_output.=$combined_string;
   if ($num_critical>0) {
      finish_program($ERRORS{'CRITICAL'});
   } elsif ($num_warning>0) {
      finish_program($ERRORS{'WARNING'});
   } else {
      finish_program($ERRORS{'OK'});
   }
} else {
   $plugin_output.="UNKNOWN - Could not find a drive matching '$the_arguments{'_arg1'}' or the WMI data returned is invalid. Available Drives are " . list_collected_values_from_all_rows(\@collected_data,['DeviceID'],', ','',0);
   finish_program($ERRORS{'UNKNOWN'});
}

}
#-------------------------------------------------------------------------
sub checkvolsize {
my @collected_data;
my ($data_errors,$last_wmi_data_index)=get_wmi_data(1,'',
   "Select Capacity,DeviceID,DriveLetter,DriveType,FileSystem,FreeSpace,Label,Name from Win32_Volume where DriveType=3",
   '','',\@collected_data,\$the_arguments{'_delay'},['FreeSpace','Capacity'],0);

#CLASS: Win32_Volume
#Capacity|DeviceID|DriveLetter|DriveType|FileSystem|FreeSpace|Label|Name|SystemVolume
#104853504|\\?\Volume{e25a04cc-c408-11dc-b164-806e6f6e6963}\|(null)|3|NTFS|75362304|System Reserved|\\?\Volume{e25a04cc-c408-11dc-b164-806e6f6e6963}\|True
#107267223552|\\?\Volume{e25a04cd-c408-11dc-b164-806e6f6e6963}\|C:|3|NTFS|93233168384|(null)|C:\|False

check_for_data_errors($data_errors);

# process includes and excludes of WMI data for Pro - after all WMI queries and joins and after check_for_data_errors - before we start looking through the returned WMI data
$use_pro_library && process_cludes_like_a_pro(\@opt_include_data,\@opt_exclude_data,\@collected_data,1,$last_wmi_data_index);

my $results_text='';
my $result_code=$ERRORS{'UNKNOWN'};
my $performance_data='';
my $num_critical=0;
my $num_warning=0;
my $num_ok=0;
my $alldisk_identifier='Overall Volumes';

if ($the_arguments{'_arg3'}) {
   # include the system totals
   # now we want to add a index before 0 so we copy everything from index 0 and unshift it to the front
   # we do it like this so that all the derived values normally stored in index 0 will remain there
   # then we overwrite the fields we want with new fake ones
   # note that the sum fields will be the orginal totals etc
   # now add this on to the existing data

   my %new_row=%{$collected_data[$last_wmi_data_index][0]};
   unshift(@{$collected_data[$last_wmi_data_index]},\%new_row);

   # now we have index 1 and index 0 the same data
   # add the new fake system total info
   # we make it look like WMI returned info about a volume called $alldisk_identifier
      $collected_data[$last_wmi_data_index][0]{'Name'}=$alldisk_identifier;
      $collected_data[$last_wmi_data_index][0]{'Label'}=$alldisk_identifier;
      $collected_data[$last_wmi_data_index][0]{'DeviceID'}=$alldisk_identifier;
      $collected_data[$last_wmi_data_index][0]{'FreeSpace'}=$collected_data[$last_wmi_data_index][0]{'_ColSum_FreeSpace'};
      $collected_data[$last_wmi_data_index][0]{'Capacity'}=$collected_data[$last_wmi_data_index][0]{'_ColSum_Capacity'};
}

if (!defined($the_arguments{'_arg4'})) {
   # set it to the default of zero
   $the_arguments{'_arg4'}='00';
}

# work out the display modes
# ARG4 is a 2 character string formatted like XY
# where 
# X=0, display not ok drives first
# X=1, display drives in the order of the WMI query results
# X=2, only display not ok drives
# Y=0, show results on a single line
# Y=1, show results as multi-line with the first line being a high level summary of status 
my $display_mode_x=substr($the_arguments{'_arg4'},0,1) || '0';
my $display_mode_y=substr($the_arguments{'_arg4'},1,1) || '0';

my $inter_item_line_feed='     ';
if ($display_mode_y eq '1') {
   $inter_item_line_feed="\n";
}

# now loop through the results, showing the ones requested
# we search the following fields: DeviceID, Label and Name
my $items_with_ok_status='';
my $items_with_not_ok_status='';
my $items_with_ok_status_summary='';
foreach my $row (@{$collected_data[$last_wmi_data_index]}) {
   # make sure $$row{'Label'} is initialised (it won't be unless the drive has been named)
   $$row{'Label'}=$$row{'Label'} || '';
   # if $the_arguments{'_arg1'} is left out it will be blank and will match all drives
   if ($$row{'DeviceID'}=~/$the_arguments{'_arg1'}/i || $$row{'Label'}=~/$the_arguments{'_arg1'}/i || $$row{'Name'}=~/$the_arguments{'_arg1'}/i || ($$row{'DeviceID'} eq $alldisk_identifier && $the_arguments{'_arg3'}) ) {
      # include this drive in the results
      if ($$row{'Capacity'}>0) {
         # got valid data
         # add our calculated data to the hash
         $$row{'_DriveSizeGB'}=sprintf("%.2f", $$row{'Capacity'}/$actual_bytefactor/$actual_bytefactor/$actual_bytefactor);
         $$row{'_UsedSpace'}=$$row{'Capacity'}-$$row{'FreeSpace'};
         $$row{'_Used%'}=sprintf("%.1f",$$row{'_UsedSpace'}/$$row{'Capacity'}*100);
         $$row{'_UsedGB'}=sprintf("%.2f", $$row{'_UsedSpace'}/$actual_bytefactor/$actual_bytefactor/$actual_bytefactor);
         $$row{'_Free%'}=sprintf("%.1f",$$row{'FreeSpace'}/$$row{'Capacity'}*100);
         $$row{'_FreeGB'}=sprintf("%.2f", $$row{'FreeSpace'}/$actual_bytefactor/$actual_bytefactor/$actual_bytefactor);
         
         my $test_result=test_limits($opt_warn,$opt_critical,$row,\%warn_perf_specs_parsed,\%critical_perf_specs_parsed,\@warn_spec_result_list,\@critical_spec_result_list);
         
         # check for Critical/Warning
         if ($test_result==$ERRORS{'CRITICAL'}) {
            $num_critical++;
         } elsif ($test_result==$ERRORS{'WARNING'}) {
            $num_warning++;
         } elsif ($test_result==$ERRORS{'OK'}) {
            $num_ok++;
         }

         # by default, in the performance data we use the Name to identify the drive
         # if the user has specified $other_opt_arguments=1 then we use the Label (if it has one)
         my $drive_identifier=$$row{'Name'} || 'NO_NAME';
         if ($the_arguments{'_arg2'} && exists($$row{'Label'})) {
            # a blank label looks like (null) - so assume that is also a label that is not set
            if ($$row{'Label'} && $$row{'Label'}!~/\(null\)/) {
               $drive_identifier=$$row{'Label'};
            }
         }
         # stick the drive identifier into the values so it can be accessed
         $$row{'VolumeDisplayName'}=$drive_identifier;
         
         my ($this_display_info,$this_performance_data,$this_combined_data)=create_display_and_performance_data($row,$display_fields{$opt_mode},$performance_data_fields{$opt_mode},\%warn_perf_specs_parsed,\%critical_perf_specs_parsed);

         # setup various variables with the display results
         # we decide which combinations we use later on
         if ($test_result==$ERRORS{'OK'}) {
            # this drive is OK, so collect it and then show all the OK drives at the end
            $items_with_ok_status.="$this_display_info$inter_item_line_feed";
            $items_with_ok_status_summary.="$$row{'VolumeDisplayName'},";
         } else {
            # this drive is not OK, show show it now
            $items_with_not_ok_status.="$this_display_info$inter_item_line_feed";
         }
         
         # alway set up the normal order results
         $results_text.="$this_display_info$inter_item_line_feed";

         # concatenate the per drive performance results together always in normal order
         $performance_data.=$this_performance_data;

      } else {
         # this drive does not get included in the results size there is a problem with its data
      }
   }
}

# decide which drives to show
if ($display_mode_x eq '0') {
   # X=0, normal full display, not ok drives first
   $results_text="$items_with_not_ok_status$items_with_ok_status";
} elsif ($display_mode_x eq '1') {
   # X=1, display drives in the order of the WMI query results
   # $results_text is left untouched
} elsif ($display_mode_x eq '2') {
   # X=2, only display not ok drives
   # remove last comma from summary list
   $items_with_ok_status_summary=~s/, *$//;
   $results_text="$items_with_not_ok_status. Not showing $num_ok items with an OK status ($items_with_ok_status_summary)";
} elsif ($display_mode_x eq '3') {
   # X=3, normal display (like X=1) when all ok, but if some not ok, then only show not
   if ($items_with_not_ok_status) {
      # remove last comma from summary list
      $items_with_ok_status_summary=~s/, *$//;
      # display is like X=2, since there are some not ok drives
      $results_text="${items_with_not_ok_status}Not showing $num_ok items with an OK status ($items_with_ok_status_summary)";
   } else {
      # leave $results_text untouched since there are no not_ok drives
   }
}

if ($display_mode_y eq '1') {
   # we have a multiline display, so make the first line a summary status
   $results_text="Drive Status Summary: OK=$num_ok, WARNING=$num_warning, CRITICAL=$num_critical. Details on the next line\n$results_text";
}

if ($results_text) {
   # show the results
   # remove the last ", "
   $results_text=~s/, +$//;
   # correctly combine the results and perfdata
   my $combined_string=combine_display_and_perfdata($results_text,$performance_data);
   $plugin_output.=$combined_string;
   if ($num_critical>0) {
      finish_program($ERRORS{'CRITICAL'});
   } elsif ($num_warning>0) {
      finish_program($ERRORS{'WARNING'});
   } else {
      finish_program($ERRORS{'OK'});
   }
} else {
   $plugin_output.="UNKNOWN - Could not find a volume matching '$the_arguments{'_arg1'}'. Available Volumes are " . list_collected_values_from_all_rows(\@collected_data,['Name'],', ','',0);
   finish_program($ERRORS{'UNKNOWN'});
}

}
#-------------------------------------------------------------------------
sub checkeventlog {
my %severity_level_descriptions=(
   1  => "Error",
   2  => "Warning",
   3  => "Information",
   4  => "Security Audit Success",
   5  => "Security Audit Failure",
);   

my $wmi_ini;

my $event_mode='';
# set default values if not specified
if (!defined($the_arguments{'_arg5'})) {
   # set to default mode
   # options:
   # any - include/exclude event log records that match any of the inclusion criteria
   # includeall - include event log records that match all of the inclusion criteria
   $event_mode=$event_modes{'ANY'};
} else {
   $event_mode=$event_modes{uc($the_arguments{'_arg5'})};
}

# -------------- $the_arguments{'_arg4'} is undef if not used, if this is the case then set it to our default ini section
if (!defined($the_arguments{'_arg4'})) {
   $the_arguments{'_arg4'}='eventdefault';
}


# -------------- name of log
if (!$the_arguments{'_arg1'}) {
   $the_arguments{'_arg1'}='System';
}

# arg1 can be a comma delimited list of logfile names eg system,application or just system
# it can also include % in the logfile name 
# build up the WMI query to include one or more logfile specifications
my @logfile_list=split(/,/,$the_arguments{'_arg1'});
my $logfile_wherebit='';
foreach my $logfile (@logfile_list) {
   # if the $logfile includes a % then we use a like clause otherwise we just use =
   my $operator='=';
   if ($logfile=~/%/) {
      $operator=" LIKE ";
   }
   $logfile_wherebit.="Logfile$operator\"$logfile\" OR ";
}
# remove the last " OR " as it will not be needed
$logfile_wherebit=~s/ OR $//;

# -------------- severity level
my $severity_level=$the_arguments{'_arg2'}; # doing this ensures we do not change the original value specified by substitutions
# arg2 can also contain static variables that need substitution (PRO Users only)
# you need to have loaded the ini files to get the substitution info
if ($use_pro_library) {
   # performance hit opening ini files if not using Pro version
   $wmi_ini=load_event_static_variables($the_arguments{'_arg4'},$wmi_ini);
   $use_pro_library && substitute_static_variables(0,\$severity_level,'');
}

# arg2 can be just a single number or a comma delimited list of numbers
my @severity_levels=split(/,/,$severity_level);
my $severity_wherebit='';
my $severity_display='';
# special cases for zero specified, 1 specified and more than 1 specified
if ($#severity_levels==-1) {
   # nothing specified, set the default value, errors (1)
   $severity_wherebit='EventType<=1 and EventType>0';
   $severity_display=$severity_level_descriptions{1};
} elsif ($#severity_levels==0) {
   # a single level specified
   # we take this level and display this level and all levels below it
   $severity_wherebit="EventType<=$severity_levels[0] and EventType>0";
   # in the display list all the levels from the one specified to level 1
   for (my $i=1;$i<=$severity_levels[0];$i++) {
      $severity_display.="$severity_level_descriptions{$i},";
   }
} else {
   # more than one specified, we only want to display the event levels listed
   foreach my $slevel (@severity_levels) {
      if (looks_like_number($slevel)) {
         $severity_wherebit.=" EventType=$slevel or";
         $severity_display.="$severity_level_descriptions{$slevel},";
      }
   }
   # remove the last " or" from the wherebit
   $severity_wherebit=~s/ or$//;
   
   # put brackets around the where part since it uses "OR"
   $severity_wherebit="($severity_wherebit)";
}

# remove the last , from the severity display
$severity_display=~s/,$//;


# -------------- number of past hours to check
if (!$the_arguments{'_arg3'}) {
   $the_arguments{'_arg3'}=1;
}

# the date and time are stored in GMT in the event log so we need to query it based on that
my $age = DateTime->now(time_zone => 'gmt')->subtract(hours => $the_arguments{'_arg3'});
my $where_time_part="TimeGenerated > \"" . $age->year . sprintf("%02d",$age->month) . sprintf("%02d",$age->day) . sprintf("%02d",$age->hour) . sprintf("%02d",$age->minute) . "00.00000000\""; # for clarity

my @collected_data;
# we have to use a custom regex to find these fields since the individual fields may contain \n themselves which stuffs up the standard regex
# records come back like this
#Logfile|Message|RecordNumber|SourceName|TimeGenerated|Type
#System|Printer 5D PDF Creator (from MATTHEW) was deleted.|101949|Print|20110521153921.000000+600|warning
my ($data_errors,$last_wmi_data_index)=get_wmi_data(1,'',
   "Select EventCode,EventIdentifier,Type,LogFile,SourceName,Message,TimeGenerated from Win32_NTLogEvent where ( $logfile_wherebit ) and $severity_wherebit and $where_time_part",
   '','(.*?)\|(.*?)\|(.*?)\|(.*?)\|(.*?)\|(.*?)\|(.*?)\|(.*?)\n',\@collected_data,\$the_arguments{'_delay'},undef,0);

check_for_data_errors($data_errors);

my @newdata=process_event_clusions($event_mode,$the_arguments{'_arg4'},\@{$collected_data[$last_wmi_data_index]},$wmi_ini);
# @newdata will totally replace the wmi data from the query, so we need to do it and then update _ItemCount
$collected_data[$last_wmi_data_index]=\@newdata;

$collected_data[$last_wmi_data_index][0]{'_SeverityType'}=$severity_display;
$collected_data[$last_wmi_data_index][0]{'_EventList'}='';

if ($collected_data[$last_wmi_data_index][0]{'_ItemCount'}>0) {
   $collected_data[$last_wmi_data_index][0]{'_EventList'}=" (List is on next line. Fields shown are - Logfile:TimeGenerated:EventId:EventCode:SeverityLevel:Type:SourceName:Message)\n" . list_collected_values_from_all_rows(\@collected_data,['Logfile','TimeGenerated','EventIdentifier','EventCode','Type','SourceName','Message'],"\n",':',0);;
}

my $test_result=test_limits($opt_warn,$opt_critical,$collected_data[$last_wmi_data_index][0],\%warn_perf_specs_parsed,\%critical_perf_specs_parsed,\@warn_spec_result_list,\@critical_spec_result_list);

my ($this_display_info,$this_performance_data,$this_combined_data)=create_display_and_performance_data($collected_data[$last_wmi_data_index][0],$display_fields{$opt_mode},$performance_data_fields{$opt_mode},\%warn_perf_specs_parsed,\%critical_perf_specs_parsed);
$plugin_output.=$this_combined_data;

finish_program($test_result);
}
#-------------------------------------------------------------------------
sub wmi_data_join {
# this is a wrapper for get_wmi_data and hence the parameters after the join related parameters are the same as that
# join WMI data
# WMIC seems not to be able to do this although it looks like WQL is actually capable of it
# anyway we do it here
# its a bit ugly since it means multiple wmi queries 
# we pass in an existing array, do a WMIC query and then take the array from that as the extra array
# we then join the extra array to the base array

# pass in
# non-blank to use a join state file, O not to use it and just do the wmi query - additionally this value is use to help uniquely identify the join state file
# the base array containing all the WMI data (comes directly from get_wmi_data)
# the WMI query number in the base array that we will be joining data to
# the field in base array that we will be looking at for a match
# regex to apply to the value in the base array field - allows matching when the fields are not identical - we extract $1$2$3$4$5 from the regex and use that
# if this is specified the regex it is used to replace whatever is found by the regex - use for replacing # by _ etc. Set to undef if not to be used
# the field in joining array that we will be looking at for a match
# regex to apply to the value in the extra array field - allows matching when the fields are not identical - we extract $1$2$3$4$5 from the regex and use that
# if this is specified the regex it is used to replace whatever is found by the regex - use for replacing # by _ etc. Set to undef if not to be used
# -- the rest of the parameters are exactly the same as get_wmi_data

# we take the base array and join the additional array to it using the fields defined to match the data rows
# we do this for each data index in the array (remember its a 2 level array, first is wmi query number and second is wmi query row number)
# the base array is modified with the extra data from the additional array

# additionally we make the values all lower case for comparison
my ($use_join_state_file,$base_array,$last_wmi_data_index,$base_field,$base_regex,$base_replacement,$extra_field,$extra_regex,$extra_replacement,$num_samples,$wmi_namespace,$wmi_query,$column_name_regex,$value_regex,$results,$specified_delay,$provide_sums,$slash_conversion)=@_;

$debug && print "Performing Join on MWI data using $base_field ($base_regex) to match to $extra_field ($extra_regex) in data from $wmi_query\n";
my $data_errors;
my $join_last_wmi_data_index;

if ($use_pro_library) {
   ($data_errors,$join_last_wmi_data_index)=cacheable_get_wmi_data($use_join_state_file,$opt_join_state_expiry,$test_ignorejoinstatefiles,$num_samples,$wmi_namespace,$wmi_query,$column_name_regex,$value_regex,$results,\$specified_delay,$provide_sums,$slash_conversion);
} else {
   ($data_errors,$join_last_wmi_data_index)=get_wmi_data($num_samples,$wmi_namespace,$wmi_query,$column_name_regex,$value_regex,$results,\$specified_delay,$provide_sums,$slash_conversion);
}


# now do the join
# the data lives in $results
# loop around each wmi query in the base
# --------------- FOR NOW WE ONLY OPERATE IN ONE WMI QUERY USING the parameter $last_wmi_data_index (from the base array)
# --------------- MAY NEED TO CHANGE IT IF WE FIND A CASE THAT COULD USE IT
for (my $query_number=$last_wmi_data_index;$query_number<=$last_wmi_data_index;$query_number++) {
   $debug && print "Processing Query #$query_number:\n";
   # lets index the $results by $extra_field and store the original wmi row number
   # this will let us look up values quickly by the values contained in $extra_field
   my %extra_index=();
   $debug && print "Will be looking for Extra Results in " . Dumper($$results[$query_number]);
   
   # --------------- For now we only look in the $join_last_wmi_data_index query index for the extra results since we are only processing one row
   
   for (my $row_num=0;$row_num<=$#{$$results[$join_last_wmi_data_index]};$row_num++) {
      my $extra_value=lc($$results[$join_last_wmi_data_index][$row_num]{$extra_field} || '');
      # apply the regex to the extra field, if any
      if ($extra_regex) {
         if (defined($extra_replacement)) {
            $extra_value=~s/$extra_regex/$extra_replacement/ig;
            $debug && print "Applying Regex $extra_regex on $extra_value and replacing with $extra_replacement gives $extra_value\n";
         } else {
            $debug && print "Applying Regex $extra_regex on $extra_value gives ";
            if ($extra_value=~/$extra_regex/) {
               # concatenate $1 through $5 together to allow more complex matches. Use || '' since most of the time they will be uninitialized
               $extra_value=$1 || '' . $2 || '' . $3 || '' . $4 || '' . $5 || '';
               $debug && print "$extra_value\n";
            } else {
               $debug && print "NO MATCH\n";
            }
         }
      }
      $extra_index{$extra_value}=$row_num;
   }
   $debug && print "Extra Lookup Index for Query Number $query_number: " . Dumper(\%extra_index);
   
   # now loop around each row of WMI data
   for (my $row_num=0;$row_num<=$#{$$base_array[$query_number]};$row_num++) {
      $debug && print "Processing Base Row #$row_num: " . Dumper($$base_array[$query_number][$row_num]) . "\n";
      # this base array has a field $base_field with a value 
      # we have to find the same value in the $results looking in the $extra_field
      # we use our lookup hash to do this easily
      # see if you can find the value from $base_field in $base_array in the lookup index
      
      my $base_value=lc($$base_array[$query_number][$row_num]{$base_field} || '');
      # apply the regex to the base field, if any
      if ($base_regex) {
         if (defined($base_replacement)) {
            $base_value=~s/$base_regex/$base_replacement/ig;
            $debug && print "Applying Regex $base_regex on $base_value and replacing with $base_replacement gives $base_value\n";
         } else {
            $debug && print "Applying Regex $base_regex on $base_value gives ";
            if ($base_value=~/$base_regex/) {
               # concatenate $1 through $5 together to allow more complex matches. Use || '' since most of the time they will be uninitialized
               $base_value=$1 || '' . $2 || '' . $3 || '' . $4 || '' . $5 || '';
               $debug && print "$base_value\n";
            } else {
               $debug && print "NO MATCH\n";
            }
         }
      }
      $debug && print "Looking for $base_value (of type $base_field) in Extra Data\n";
      my $extra_row=$extra_index{$base_value};
      if (defined($extra_row)) {
         $debug && print "Found Matching Data in Extra Row: $extra_row\n";
         # add the data from the extra hash to the base hash
         # --------------- For now we only look in the $join_last_wmi_data_index query index for the extra results since we are only processing one row
         # we want to merge without overwriting existing values (since this would overwrite important values like _ChecksOK etc)
         # first hash  $$base_array[$query_number][$row_num]
         # second hash $$results[$join_last_wmi_data_index][$extra_row]
         # loop through the second hash and add the key/value to the first one if the key does not exist already
         foreach my $key (keys %{$$results[$join_last_wmi_data_index][$extra_row]}) {
            if (!exists($$base_array[$query_number][$row_num]{$key})) {
               # does not exist so add it
               $$base_array[$query_number][$row_num]{$key}=$$results[$join_last_wmi_data_index][$extra_row]{$key};
            }
         }
         # we used to do this but it overwrites existing keys
         # @{$$base_array[$query_number][$row_num]}{keys %{$$results[$join_last_wmi_data_index][$extra_row]}} = values %{$$results[$join_last_wmi_data_index][$extra_row]};
         $debug && print "Giving: " . Dumper($$base_array[$query_number][$row_num]) . "\n";;
      } else {
         $debug && print "Could not match the base value $base_value to an extra value\n";
      }

   }
}

return $data_errors,$join_last_wmi_data_index;
}
#-------------------------------------------------------------------------
sub load_event_static_variables {
# pass in 
# comma delimited list of section names to read inclusions and exclusions from 
# reference to the wmi_ini object
my ($sections,$wmi_ini)=@_;

# build up a list of inclusions and exclusions from the specified sections
my @section_lists=split(/,/,$sections);

if ($#section_lists>=0) {
   # open the ini files
   $wmi_ini=open_ini_file($wmi_ini);

   foreach my $section (@section_lists) {
      $debug && print "Including Event Section $section\n";
      my @tmp_array=$wmi_ini->val($section,'static');
      $use_pro_library && load_static_variables_from_array(\@tmp_array);
   }
   $debug && print "Added Event Static Ini Variables: " . Dumper(\%ini_static_variables);

}
return $wmi_ini;
}
#-------------------------------------------------------------------------
sub process_event_clusions {
# process event log check inclusions and exclusions from the ini file
# return a new collected data array
# pass in 
# event inclusion mode
# comma delimited list of section names to read inclusions and exclusions from 
# reference to the collected data array - only a single query is passed in eg $collected_data[0]
# reference to the wmi_ini object
# 
# we return a new array
my ($event_mode,$sections,$wmidata,$wmi_ini)=@_;
my $type=reftype $wmi_ini || '';
my @new_data=();

my @im_list=();
my @is_list=();
my @ii_list=();
my @ic_list=();
my @em_list=();
my @es_list=();
my @ei_list=();
my @ec_list=();

# build up a list of inclusions and exclusions from the specified sections
my @section_lists=split(/,/,$sections);

# only do something if there are some sections defined and some eventlog data
if ($#section_lists>=0 && $$wmidata[0]{'_ItemCount'}>0) {
   # open the ini files
   $wmi_ini=open_ini_file($wmi_ini);

   foreach my $section (@section_lists) {
      $debug && print "Including Event Section $section\n";
      push(@im_list,$wmi_ini->val($section,'im'));
      push(@is_list,$wmi_ini->val($section,'is'));
      push(@ii_list,$wmi_ini->val($section,'ii'));
      push(@ic_list,$wmi_ini->val($section,'ic'));
      push(@em_list,$wmi_ini->val($section,'em'));
      push(@es_list,$wmi_ini->val($section,'es'));
      push(@ei_list,$wmi_ini->val($section,'ei'));
      push(@ec_list,$wmi_ini->val($section,'ec'));

   }

   $debug && print "Event Mode=$event_mode\nIn/Exclusion List=" . Dumper(\@im_list,\@is_list,\@ii_list,\@ic_list,\@em_list,\@es_list,\@ei_list,\@ec_list);
   
   # step through each record found
   foreach my $row (@{$wmidata}) {
      $debug && print "WMI Data Row:" . Dumper($row);
      # process all the inclusions first
      my $include_record=0;
      $use_pro_library && prepare_event_counts();
      
      # see if there are any inclusions defined, if not the record is included
      if ($#im_list>=0 || $#is_list>=0 || $#ii_list>=0 || $#ic_list>=0) {
         foreach my $is (@is_list) {
            if (defined($is)) {
               $debug && print "Inclusion Checking SourceName for $is\n";
               $use_pro_library && mark_event_inclusion($event_mode,'CRITERIA');
               if ($$row{'SourceName'}=~/$is/i) {
                  if ($event_mode eq $event_modes{'ANY'}) {
                     $debug && print "Including\n";
                     $include_record=1;
                     last;
                  } elsif ($use_pro_library) {
                     mark_event_inclusion($event_mode,'EVENT');
                  }
               }
            }
         }
         
         # look for inclusions based on Message, but only if it is not included already
         if (!$include_record) {
            # now check for includes against Message
            foreach my $im (@im_list) {
               if (defined($im)) {
                  $debug && print "Inclusion Checking Message for $im\n";
                  $use_pro_library && mark_event_inclusion($event_mode,'CRITERIA');
                  if ($$row{'Message'}=~/$im/i) {
                     if ($event_mode eq $event_modes{'ANY'}) {
                        $debug && print "Including\n";
                        $include_record=1;
                        last;
                     } elsif ($use_pro_library) {
                        mark_event_inclusion($event_mode,'EVENT');
                     }
                  }
               }
            }
         }

         if (!$include_record) {
            # now check for includes against EventIdentifier
            foreach my $ii (@ii_list) {
               if (defined($ii)) {
                  $debug && print "Inclusion Checking EventIdentifier for $ii\n";
                  $use_pro_library && mark_event_inclusion($event_mode,'CRITERIA');
                  if ($$row{'EventIdentifier'}=~/$ii/i) {
                     if ($event_mode eq $event_modes{'ANY'}) {
                        $debug && print "Including\n";
                        $include_record=1;
                        last;
                     } elsif ($use_pro_library) {
                         mark_event_inclusion($event_mode,'EVENT');
                     }
                  }
               }
            }
         }

         if (!$include_record) {
            # now check for includes against EventCode
            foreach my $ic (@ic_list) {
               if (defined($ic)) {
                  $debug && print "Inclusion Checking EventCode for $ic\n";
                  $use_pro_library && mark_event_inclusion($event_mode,'CRITERIA');
                  if ($$row{'EventCode'}=~/$ic/i) {
                     if ($event_mode eq $event_modes{'ANY'}) {
                        $debug && print "Including\n";
                        $include_record=1;
                        last;
                     } elsif ($use_pro_library) {
                         mark_event_inclusion($event_mode,'EVENT');
                     }
                  }
               }
            }
         }
         
         if ($use_pro_library) {
            $include_record=calculate_event_inclusion($event_mode,$include_record);
         }

      } else {
         # no include lists defined so automatically included
         $debug && print "No include lists so automatically including\n";
         $include_record=1;
      }
      
      # now check for exclusions, if any and only if this record is included
      if ( $include_record &&    ($#em_list>=0 || $#es_list>=0 || $#ei_list>=0 || $#ec_list>=0)   ) {
         foreach my $es (@es_list) {
            if (defined($es)) {
               $debug && print "Exclusion Checking SourceName for $es\n";
               if ($$row{'SourceName'}=~/$es/i) {
                  $debug && print "Excluding\n";
                  $include_record=0;
                  last;
               }
            }
         }

         # look for exclusions based on Message, but only if it is included already
         if ($include_record) {
            # now check for includes against Message
            foreach my $em (@em_list) {
               if (defined($em)) {
                  $debug && print "Exclusion Checking Message for $em\n";
                  if ($$row{'Message'}=~/$em/i) {
                     $debug && print "Excluding\n";
                     $include_record=0;
                     last;
                  }
               }
            }
         }

         # look for exclusions based on EventIdentifier, but only if it is included already
         if ($include_record) {
            # now check for includes against EventIdentifier
            foreach my $ei (@ei_list) {
               if (defined($ei)) {
                  $debug && print "Exclusion Checking EventIdentifier for $ei\n";
                  if ($$row{'EventIdentifier'}=~/$ei/i) {
                     $debug && print "Excluding\n";
                     $include_record=0;
                     last;
                  }
               }
            }
         }

         # look for exclusions based on EventCode, but only if it is included already
         if ($include_record) {
            # now check for includes against EventCode
            foreach my $ec (@ec_list) {
               if (defined($ec)) {
                  $debug && print "Exclusion Checking EventCode for $ec\n";
                  if ($$row{'EventCode'}=~/$ec/i) {
                     $debug && print "Excluding\n";
                     $include_record=0;
                     last;
                  }
               }
            }
         }

      } else {
         # nothing to do - no exclusions defined or record not included anyway
      }
      
      $debug && print "IN/EX=$include_record\n\n";
      if ($include_record) {
         # add this record to the new data
         push(@new_data,$row);
      }
   }

   # have to update the _ItemCount of the array, since this array will be used over the top of the input array
   $new_data[0]{'_ItemCount'}=$#new_data+1;

} else {
   $debug && print "No In/Exclusions defined\n";
   # the new data is the same as the input data
   @new_data=@{$wmidata};
}

return @new_data;
}
#-------------------------------------------------------------------------
sub apply_multiplier {
# multiply a value up using a mulitplier string value
# pass in
# a value
# a multiplier eg k, m, g etc - might be empty
my ($value,$multiplier)=@_;
if ($multiplier) {
   $debug && print "Value of $value ";
   if (defined($time_multipliers{$multiplier})) {
      # this is a time based multiplier
      # return the value in seconds 
      $value=$value * $time_multipliers{lc($multiplier)};
      $debug && print "multiplied up to $value using $multiplier * " . $time_multipliers{lc($multiplier)} . "\n";
   } else {
      # return the value in bytes
      $value=$value * $actual_bytefactor ** $multipliers{lc($multiplier)};
      $debug && print "multiplied up to $value using $multiplier ($actual_bytefactor ^ " . $multipliers{lc($multiplier)} . ")\n";
   }
}
return $value;
}
#-------------------------------------------------------------------------
sub test_single_boundary {
# test a value against a single boundary. The boundary should have already been parsed
# pass in
# less_than_boundary - set to < if test should be less than boundary
# equal - set to = if test should include an = boundary
# boundary value
# boundary multiplier character eg k, m, g etc
# the test value
# 
# return 1 if boundary exceeded or zero if not
# also return the actual mulitplied up $boundary_value
my ($less_than_boundary,$boundary_equal,$original_boundary_value,$boundary_multiplier,$test_value)=@_;

my $test_result=0;

my $boundary_value=apply_multiplier($original_boundary_value,$boundary_multiplier);

# these boundary tests have to use > >= etc and no gt ge etc since we want a real number test
# sometimes we get non numbers coming in here so we have to test for that
if(looks_like_number($test_value)) {
   
   if ($less_than_boundary && $boundary_equal) {
      # TEST <=
      $debug && print "TEST1 $test_value <= $boundary_value\n";
      if ($test_value <= $boundary_value) {
         $test_result=1;
      }
   } elsif ($less_than_boundary) {
      # TEST <
      $debug && print "TEST2 $test_value < $boundary_value\n";
      if ($test_value < $boundary_value) {
         $test_result=1;
      }
   } elsif ($boundary_equal) {
      # TEST >=
      $debug && print "TEST3 $test_value >= $boundary_value\n";
      if ($test_value >= $boundary_value) {
         $test_result=1;
      }
   } else {
      # TEST > 
      $debug && print "TEST4 $test_value > $boundary_value\n";
      if ($test_value > $boundary_value) {
         $test_result=1;
      }
   }
   $debug && print "Test of $less_than_boundary$boundary_equal$original_boundary_value$boundary_multiplier ($boundary_value) vs $test_value yields $test_result\n";
} else {
   $debug && print "Boundary Test not performed since Test Value '$test_value' is not numeric\n"; 
}
return $test_result,$boundary_value;
}
#-------------------------------------------------------------------------
sub parse_limits {
my ($spec,$test_value)=@_;
# pass in a single warn/crit specification
# a hash ref that contains all the possible values we might test against

$debug && print "Testing SPEC: $spec\n";
my $test_result=0;

# we need a warning/critical value for performance data graphs
# for single values it is easy, its just the boundary value specified
# for ranges we use the max of the range - maybe this is not always right
my $perf_data_spec='';

# variable to hold display info on how and what was triggered
my $trigger_display='';

my $field_name='';

if ($spec ne '') {
   my $at_specified='';
   my $min='';
   my $min_multiplier='';
   my $max='';
   my $max_multiplier='';

   my $format_type=0;

   # read the --help/usage page to see how to build a specification

   # if using the pro library then there are additional warn/crit specs available
   # check for them here first
   my $pro_sorted_it_out=0;
   if ($use_pro_library) {
      ($pro_sorted_it_out,$test_result,$perf_data_spec,$trigger_display,$field_name)=parse_limits_like_a_pro($spec,$test_value);
   }

   if (!$pro_sorted_it_out) {

      # this first spec format might look like this
      # FIELD=@1G:2G <-- we are specifically looking for a range here using a colon to separate to values
      if ($spec=~/(.*?)=*(\@*)([0-9+\-\.\~]*)($multiplier_regex*):([0-9+\-\.\~]*)($multiplier_regex*)/i) {
         $field_name=$1 || $valid_test_fields{$opt_mode}[0]; # apply the default field name if none specified
         $at_specified=$2;
         $min=$3;
         $min_multiplier=$4;
         $max=$5;
         $max_multiplier=$6;
         $format_type=1;
         $debug && print "SPEC=$field_name,$2,$3,$4,$5,$6\n";
   
      # this second spec might look like this
      # FIELD=@1M <--- we are specifically looking for a single value
      } elsif ($spec=~/(.*?)=*(\@*)([0-9+\-\.\~]+)($multiplier_regex*)/i) {
         $field_name=$1 || $valid_test_fields{$opt_mode}[0]; # apply the default field name if none specified
         $at_specified=$2;
         $min=0;
         $min_multiplier='';
         $max=$3;
         $max_multiplier=$4;
         $format_type=2;
         $debug && print "SPEC=$field_name,$2,$3,$4\n";
      } else {
         $debug && print "SPEC format for $spec, not recognised\n";
      }
   
      # check to see if we got a valid specification
      if ($format_type) {
         $debug && print "Range Spec - FIELD=$field_name, AT=$at_specified MIN=$min MINMULTIPLIER=$min_multiplier MAX=$max MAXMULTIPLIER=$max_multiplier\n";
         # there should always be a max value and may not be a min value
         my $lower_bound_value='';
         my $upper_bound_value='';
         my $lower_bound_check='';
         my $upper_bound_check='';
   
         # there is a possibility that the boundary is specified as ~
         # this means negative infinity
   
         # we have a range comparison and we check both bounds using < and >
         if ($min eq '~') {
            # since min is negative infinity then no point in doing this lower bound test as it will be always false
            $lower_bound_check=0;
            $lower_bound_value='~';
         } else {
            # the value to test against is the field from the hash
            $debug && print "Testing MIN: '$min' for Field $field_name which has value: $$test_value{$field_name}\n";
            ($lower_bound_check,$lower_bound_value)=test_single_boundary('<','',$min,$min_multiplier,$$test_value{$field_name});
         }
         
         if ($max eq '') {
            # since max is inifinity no point in checking since result will always be false
            $upper_bound_check=0;
            $upper_bound_value='';
         } else {
            # the value to test against is the field from the hash
            $debug && print "Testing MAX: '$max' for Field $field_name which has value: $$test_value{$field_name}\n";
            ($upper_bound_check,$upper_bound_value)=test_single_boundary('','',$max,$max_multiplier,$$test_value{$field_name});
         }
   
         # generate alert if either lower or upper triggered
         if ($lower_bound_check) {
            $test_result=1;
            $trigger_display="$field_name<$min$min_multiplier";
         }
         if ($upper_bound_check) {
            $test_result=1;
            $trigger_display="$field_name>$max$max_multiplier";
         }
   
         if ($at_specified) {
            # this just reverses the results
            if ($test_result==1) {
               $test_result=0;
               $trigger_display='';
            } else {
               $test_result=1;
               $trigger_display="$field_name in the range $min$min_multiplier:$max$max_multiplier";
            }
            $debug && print "@ specified so reverse the result\n";
         }
   
         # rewrite the specification taking into account any multipliers
         # this is done so that we can parse consistent and recognisable values in the performance data
         # performance data does not recognise our multiplier system so we have to pre-multiply it 
         if ($format_type==1) {
            if ($opt_z) {
               #  provide full spec performance warn/crit data
               $perf_data_spec="$at_specified$lower_bound_value:$upper_bound_value";
            } else {
               # provide partial spec performance warn/crit data
               # if only one number has been specified in the range spec then use that
               # otherwise use the upper bound value
               $perf_data_spec="$upper_bound_value";
               if ($upper_bound_value=~/[0-9+\-\.]+/ && $lower_bound_value=~/[0-9+\-\.]+/) {
                  # stick with only upper bound data
               } elsif ($lower_bound_value=~/[0-9+\-\.]+/) {
                  # no upper bound specified so use the lower bound
                  $perf_data_spec="$lower_bound_value";
               }
            }
         } else {
            # for this format type the min was forced to zero, but it was not actually specified - so we only show an upper bound 
            if ($opt_z) {
               #  provide full spec performance warn/crit data
               $perf_data_spec="$at_specified$upper_bound_value";
            } else {
               # provide partial spec performance warn/crit data
               $perf_data_spec="$upper_bound_value";
            }
         }
   
      } else {
         # seems to be some invalid spec format
         $test_result=100;
      }
   }
}

$debug && print "Test Result = $test_result, Perf Spec=$perf_data_spec, Trigger Display=$trigger_display, Field Tested=$field_name\n";
# return the test result, the performance data spec (expanded with any multipliers), a display string of what was triggered and the field name that was used to test against
return $test_result,$perf_data_spec,$trigger_display,$field_name;
}
#-------------------------------------------------------------------------
sub list_collected_values_from_all_rows {
# this is specifically designed for when you have an array that looks like
# ie multiple rows per query results
#$VAR1 = [
#          [
#            {
#              'Name' => 1,
#              'Thing' => 10,
#            }
#            {
#              'Name' => 2,
#              'Thing' => 20,
#            }
#          ],
#          [
#            {
#              'Name' => 3,
#              'Thing' => 30,
#            }
#            {
#              'Name' => 4,
#              'Thing' => 40,
#            }
#          ],
#        ];
# This sub will return something like "1,2,3,4" or if specifying multiple fields
# 1,10
# 2,20
# 3,30
# 4,40
# luckily we have an array like this hanging around - it is the array format returned by
# get_wmi_data
my ($values_array,$field_list,$line_delimiter,$field_delimiter,$list_unique)=@_;
# pass in
# the array of values as returned by get_wmi_data
# an array of the hash keys you want to look up and list - these get separated by the FIELD DELIMITER
# the LINE delimiter you want to use to list out after listing the defined fields (eg at the end of the line)
# the FIELD delimiter you want to use between fields
# whether you want the list returned with unique values removed - list unique looks at whole rows
my %seen=();
my @list=();
foreach my $result (@{$values_array}) {
   # $result is an array reference to each result
   foreach my $row (@{$result}) {
      # $row is a hash reference to each row for this result
      # now loop through the list of fields wanted
      my @row_field_list=();
      foreach my $field (@{$field_list}) {
         if (exists($$row{$field})) { # it might not exist for example if you found no processes in your search
            # remove any CR or LF from the field as they stuff up the list - replace them with space
            $$row{$field}=~s/\n|\r/ /g;
            
            # perform reverse static variable substitutions on the fields
            $use_pro_library && substitute_static_variables(1,\$$row{$field},$field);
            
            push(@row_field_list,$$row{$field});
         }
      }
      
      my $row_string=join($field_delimiter,@row_field_list);
      # remove empty fields from the end - remove anything ending in the field delimiter
      # use \Q and \E to quote the field delimiter since it can have regex special chars which screw up the regex
      $row_string=~s/\Q$field_delimiter\E$//;

      if ($list_unique) {
         # record the ones we have seen before and count how many of them
         $seen{$row_string}++;
         if ($seen{$row_string}==1) {
            # only add it to the array the first time
            push(@list,$row_string);
         }
      } else {
         # add to the list, preserving order
         push(@list,$row_string); 
      }
   }
}

if ($list_unique) {
   # modify each @list element to include the qty of those found
   # not sure how this will work with multiple fields
   @list=map(list_item_with_qty($_,\%seen),@list);
}
my $string=join($line_delimiter,@list);
return $string;
}
#-------------------------------------------------------------------------
sub list_item_with_qty {
my ($item,$seen_hashref)=@_;
my $qty='';
if ($$seen_hashref{$item}>1) {
   $qty="$$seen_hashref{$item}x";
}
return "$qty $item";
}
#-------------------------------------------------------------------------
sub test_multiple_limits {
# this can be used to test both warning and critical specs
# it takes a list of test values and warn/crit specs and gives you the results of them
# pass in
# a hash reference where we return the parsed specifications (multiplier multiplied up) for performance data
# a hash reference containing all the values we have that we might test against
# an array ref where we return some text telling us about what was triggered
# a hash reference where we return the parsed specifications (multiplier multiplied up) for performance data
my ($perf_specs_parsed,$test_value,$spec_result_list,$spec_list)=@_;
my $count=0;

# initialise the performance spec hash to ensure that we do not see any "Use of uninitialized value" errors if it gets used
# based the initialisation on the possible warn/crit specs defined in %valid_test_fields
foreach my $key (@{$valid_test_fields{$opt_mode}}) {
   $$perf_specs_parsed{$key}='';
}

@{$spec_result_list}=(); # ensure that this array starts empty
foreach my $spec (@{$spec_list}) {
   my ($result,$perf,$display,$test_field)=parse_limits($spec,$test_value);
   # store the performance data in a hash against the test field
   # since this is for performance data we really only want to keep one of the warn/critical specs per test field
   # since this is in a loop we will effectively just keep the last one that was defined
   $$perf_specs_parsed{$test_field}=$perf;
   # store all the information about what was triggered
   push(@{$spec_result_list},$display);
   if ($result>1) {
      print "Warning/Critical specification ($spec) not defined correctly\n";
   } elsif ($result==1) {
      $count++;
   }
}

return $count;
}
#-------------------------------------------------------------------------
sub test_limits {
my ($warn_spec_list,$critical_spec_list,$test_value,$warn_perf_specs_parsed,$critical_perf_specs_parsed,$warn_spec_result_list,$critical_spec_result_list)=@_;
# pass in
# an array containing the list of warn specifications
# an array containing the list of critical specifications
# a hash reference containing all the values we have that we might test against
# a hash reference where we return the parsed specifications (multiplier multiplied up) for performance data for warnings
# a hash reference where we return the parsed specifications (multiplier multiplied up) for performance data for criticals
# an array ref where we return some text telling us about what was triggered for warnings
# an array ref where we return some text telling us about what was triggered for criticals

# eg $test_value = {
#          '_Free%' => '99.4',
#          'VolumeName' => 'Temp Disk 2',
#          '_UsedSpace' => 13383680,
#          '_FreeGB' => '1.98',
# and $warn_spec_list = [
#          '1:',
#          ':2',
#          '3'

# most of this stuff we pass in just gets passed off to test_multiple_limits
# we call test_multiple_limits twice, once for warnings and once for criticals

# translate any static variables
$use_pro_library && substitute_static_variables(0,$warn_spec_list,'');
$use_pro_library && substitute_static_variables(0,$critical_spec_list,'');

$debug && print "Testing TEST VALUES " . Dumper($test_value);
$debug && print "WARNING SPECS: " . Dumper($warn_spec_list);
$debug && print "CRITICAL SPECS: " . Dumper($critical_spec_list);

# assume it is ok unless we find otherwise
my $test_result=$ERRORS{'OK'};

$debug && print "------------ Critical Check ------------\n";
my $critical_count=test_multiple_limits($critical_perf_specs_parsed,$test_value,$critical_spec_result_list,$critical_spec_list);

$debug && print "------------ Warning Check ------------\n";
my $warn_count=test_multiple_limits($warn_perf_specs_parsed,$test_value,$warn_spec_result_list,$warn_spec_list);

$debug && print "------------ End Check ------------\n";

$use_pro_library && substitute_static_variables(1,$warn_spec_result_list,'');
$use_pro_library && substitute_static_variables(1,$critical_spec_result_list,'');

# determine the result type, and load up some other values that can be used for display etc
$$test_value{'_StatusType'}='';
if (defined($$test_value{'_KeepStateSamplePeriod'})) {
   # this will only ever get added to Row 0 of any query since that is the only place we set the SamplePeriod value
   $$test_value{'_StatusType'}=" (Sample Period $$test_value{'_KeepStateSamplePeriod'} sec)";
}

if ($critical_count>0) {
   $test_result=$ERRORS{'CRITICAL'};
   $$test_value{'_TestResult'}=$ERRORS{'CRITICAL'};
   $$test_value{'_StatusType'}="CRITICAL$$test_value{'_StatusType'}";
   $$test_value{'_Triggers'}='[Triggered by ' . join(',',grep(/.+/,@{$critical_spec_result_list})) . ']';
   $$test_value{'_DisplayMsg'}="$$test_value{'_StatusType'} - $$test_value{'_Triggers'}";
} elsif ($warn_count>0) {
   $test_result=$ERRORS{'WARNING'};
   $$test_value{'_TestResult'}=$ERRORS{'WARNING'};
   $$test_value{'_StatusType'}="WARNING$$test_value{'_StatusType'}";
   $$test_value{'_Triggers'}='[Triggered by ' . join(',',grep(/.+/,@{$warn_spec_result_list})) . ']';
   $$test_value{'_DisplayMsg'}="$$test_value{'_StatusType'} - $$test_value{'_Triggers'}";
} else {
   $test_result=$ERRORS{'OK'};
   $$test_value{'_TestResult'}=$ERRORS{'OK'};
   $$test_value{'_StatusType'}="OK$$test_value{'_StatusType'}";
   $$test_value{'_Triggers'}='';
   $$test_value{'_DisplayMsg'}="$$test_value{'_StatusType'}";
}
# only show this debug if there was any warn or crit specs
if ($#$critical_spec_list>=0 || $#$warn_spec_list>=0) {
   $debug && print "Test Results:\nWarn Perf Specs=" . Dumper($warn_perf_specs_parsed) . "Warn Results=" . Dumper($warn_spec_result_list) . "Critical Perf Spec=" . Dumper($critical_perf_specs_parsed) . "Critical Results=" . Dumper($critical_spec_result_list);
}
$debug && print "Data Passed back from check: " . Dumper($test_value);
return $test_result;
}
#-------------------------------------------------------------------------
sub work_out_overall_exit_code {
my ($wmidata,$process_each_row,$query_index)=@_;
# only look at query #0
# but look at each row  - look for the _TestResult value
my $max_status='OK';
my $max_result=$ERRORS{$max_status};
my @triggers=();
if ($process_each_row eq '0') {
   # only take what is already in ROW 0
   # we only need to set the max result variable so that this sub exits properly
   $max_result=$$wmidata[$query_index][0]{'_TestResult'};
} else {
   foreach my $row (@{$$wmidata[$query_index]}) {
      $debug && print "Row Result $$row{'_TestResult'}\n";
      if ($$row{'_TestResult'}>$max_result) {
         $max_result=$$row{'_TestResult'};
      }
      # store any triggers for this row
      push(@triggers,$$row{'_Triggers'});
   }
   if ($max_result==$ERRORS{'OK'}) {
      $max_status='OK';
   } elsif ($max_result==$ERRORS{'WARNING'}) {
      $max_status='WARNING';
   } elsif ($max_result==$ERRORS{'CRITICAL'}) {
      $max_status='CRITICAL';
   } else {
   }

   # get only the unique triggers and show them
   my %seen=();
   my @unique_triggers=grep{ ! $seen{$_} ++ } @triggers;
   my $unique_trigger_list=join('',@unique_triggers);

   my $display_msg="$max_status";
   if (defined($$wmidata[$query_index][0]{'_KeepStateSamplePeriod'})) {
      $display_msg="$display_msg (Sample Period $$wmidata[$query_index][0]{'_KeepStateSamplePeriod'} sec)";
   }
   if ($unique_trigger_list) {
      # if there are some triggers then show them on the end of the display msg
      $display_msg="$display_msg - $unique_trigger_list";
   }
   
   # overwrite the following fields in collected WMI data in query 0 row 0 only
   # this assumes that everything else that wanted to use the orignal data has already done so
   $$wmidata[$query_index][0]{'_TestResult'}=$max_result;
   $$wmidata[$query_index][0]{'_StatusType'}=$max_status;
   $$wmidata[$query_index][0]{'_Triggers'}=$unique_trigger_list;
   $$wmidata[$query_index][0]{'_DisplayMsg'}=$display_msg;

   $debug && print "Overall Result: $max_result ($max_status) with Triggers: $unique_trigger_list\n";

}

return $max_result;
}
##-------------------------------------------------------------------------
#sub initialise_perf_specs {
## initialise a performance spec hash to ensure that we do not see any "Use of uninitialized value" errors if it gets used
## pass in 
## the hash to initialise
## the hash to copy from (but we make the values all '');
#my ($spec_hashref,$test_value)=@_;
#foreach my $key (keys %{$test_value}) {
#   $$spec_hashref{$key}='';
#}
#
#}

#-------------------------------------------------------------------------
sub get_files_from_dir {
# return an array  which contains all the files in $dir matching $pattern
# pass in
# $dir should be a full pathname
# $pattern a regex to match file names against
my ($dir,$pattern)=@_;
my @list;

opendir(DIR,"$dir");
foreach my $file (readdir DIR) {
	# only take files
   if ( -f "$dir/$file" && $file=~/$pattern/i) {
      push(@list,$file);
   }
}
closedir(DIR);

return @list;
}
#-------------------------------------------------------------------------
sub max {
# passed in a list of numbers
# determaxe the maximum one 
my($max_so_far) = shift @_;  # the first one is the smallest yet seen
foreach (@_) {               # look at the remaining arguments
  if ($_ > $max_so_far) {    # could this one be smaller
    $max_so_far = $_;
  }
}
return $max_so_far;
}
#-------------------------------------------------------------------------
sub create_datetime_displaytime {
# take a DateTime object and make it a display string
# pass in
# DateTime object
my ($dt)=@_;
my $string=$dt->ymd() . " " . $dt->hms();
return $string;
}
#-------------------------------------------------------------------------
sub convert_WMI_timestamp_to_seconds {
# pass in a WMI Timestamp like 20100528105127.000000+600
my ($wmi_timestamp)=@_;
my $sec='';
my $age_sec=''; 
my $current_dt='';
my $current_sec='';
$debug && print "Converting WMI Timestamp $wmi_timestamp to seconds = ";
my $tz='';
if ($wmi_timestamp=~/^(\d{4})(\d{2})(\d{2})(\d{2})(\d{2})(\d{2}).(\d*)([+\-])+(\d*)$/) {
   # now convert that fileage to seconds
   $tz=$8 . sprintf("%02d%02d",$9/60,$9%60);
   my $dt = DateTime->new(
      year       => $1,
      month      => $2,
      day        => $3,
      hour       => $4,
      minute     => $5,
      second     => $6,
      nanosecond => $7,
      # use the timezone of the queried system - convert the WMI timezone (number of minutes) to HHMM for use with DateTime
      time_zone  => $tz,
     );
   
   $sec=$dt->epoch();
   # force the current time into the same timezone as the queried system
   $current_dt=DateTime->now( time_zone => $dt->time_zone() );
   $current_sec=$current_dt->epoch();
   $age_sec=$current_sec-$sec;
}
$debug && print "$sec. Now=$current_dt ($current_sec sec). Age=$age_sec sec. TZ converted from $8$9 (sec) to $tz (HHMM)\n";
return $sec,$age_sec;
}
#-------------------------------------------------------------------------
sub show_ini_section {
my ($ini,$ini_section)=@_;
# pass in
# ini object (already open)
# ini section name
my $output="-------------------------------------------------------------------\n";
foreach my $setting (sort $ini->Parameters($ini_section)) {
   my $value=$ini->val($ini_section,$setting);
   $output.=sprintf("%15s => %s\n",$setting,$value);
}
$output.="-------------------------------------------------------------------\n";
return $output;
}
#-------------------------------------------------------------------------
sub interpret_mode_list {
my ($display_mode)=@_;
# $display_mode is a string formatted with a list of items
# each item is in the format
# DISPLAYWHAT=DISPLAYWHEN
# where 
# DISPLAYWHAT=ok,warn,critical,unknown
# DISPLAYWHEN=all,ok,bad
#
if (scalar(%displaywhatwhen_mode_list)>0) {
   # mode list is already setup so do nothing
} else {
   # setup the default display modes
   %displaywhatwhen_mode_list=(
      0 => 'all',
      1 => 'all',
      2 => 'all',
      3 => 'all',
   );
   foreach my $dmode (split(",",$display_mode)) {
      if ($dmode=~/^(.*?)=(.*?)$/) {
         # check for a valid DISPLAYWHAT value
         if (exists($string_constant{$1})) {
            # check for a valid DISPLAYWHEN value
            if ($2 eq 'all' || $2 eq 'ok' || $2 eq 'bad' || $2 eq 'none') {
               # all values look ok
               $displaywhatwhen_mode_list{$string_constant{$1}}=$2;
            } else {
               $debug && print "Invalid DISPLAYWHEN value of $2 provided and ignored\n";
            }
         } else {
            $debug && print "Invalid DISPLAYWHAT value of $1 provided and ignored\n";
         }
      } else {
         $debug && print "Incorrectly formatted DISPLAYWHAT=DISPLAYWHEN ignored\n";
      }
   } 
$debug && print "Got Display-What-When Mode List as " . Dumper(\%displaywhatwhen_mode_list);
}
}
#-------------------------------------------------------------------------
sub finish_program {
# generic sub to handle program exit
# pass in 
# exit code
my ($exit_code)=@_;

$final_exit_code=$exit_code;

# pro may modify the exit code
$use_pro_library && finish_program_like_a_pro();

if ($opt_use_cached_wmic_response || $use_cached_wmic_responses) {
   print "WARNING - Using Cached WMIC Data. Your plugin results will be inaccurate.\n";
}

# print the plugin output, if any
$plugin_output && print $plugin_output;

$test_generate && print "EOT\nexitcode_$test_number=$final_exit_code\n";
$test_run && print "exitcode_$test_number=$final_exit_code\n";
exit $final_exit_code;
}
#-------------------------------------------------------------------------


