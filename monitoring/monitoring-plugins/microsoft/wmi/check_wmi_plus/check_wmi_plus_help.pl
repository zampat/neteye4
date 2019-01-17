# check_wmi_plus_help.pl - Help Text for check_wmi_plus
#
# Copyright (C) 2011 Matthew Jurgens EDC International New Zealand
# You can email me using: mjurgens (the at goes here) edcint.co.nz
#
# This is included into the main script as required

#-------------------------------------------------------------------------
sub short_usage {
my ($no_exit)=@_;
print <<EOT;
Typical Usage: -H HOSTNAME -u DOMAIN/USER -p PASSWORD -m MODE [-s SUBMODE] [-b BYTEFACTOR] [-w WARN] [-c CRIT] [-a ARG1 ] [-o ARG2] [-3 ARG3] [-4 ARG4] [-5 ARG5] [-A AUTHFILE] [-t TIMEOUT] [-y DELAY] [--namespace WMINAMESPACE] [--extrawmicarg EXTRAWMICARG] [--nodatamode] [--nodataexit NODATAEXIT] [--nodatastring NODATASTRING] [-d] [-z] [--inifile=INIFILE] [--inidir=INIDIR] [--inihelp] [--nokeepstate] [--keepexpiry EXPIRY] [--keepid KID] [--joinexpiry EXPIRY] [--helperexpiry EXPIRY] [-v OSVERSION] [--help] [--itexthelp] [--forcewmiccommand] [-icollectusage] [--ishowusage] [--logswitch] [--logkeep] [--logsuffix SUFFIX] [--logshow] [--variablesdisabled] [--forceiniopen] [--forcetruncateoutput LEN] [--fieldshow] [--filterinirowsbystatus FILTERSTATUS] [--Convertslash]
EOT
if (!$no_exit) {
   print "Help as a Manpage: --help\nHelp as Text: --itexthelp\n";
   finish_program($ERRORS{'UNKNOWN'});
}
}
#-------------------------------------------------------------------------
sub usage {

if ($opt_help) {  
   if (-x $make_manpage_script) {
      # we have the script to make the manpage and have not been asked to show text only help
      exec ("$make_manpage_script \"$0 --itexthelp\" \"$manpage_dir\"") or print STDERR "couldn't exec $make_manpage_script: $!";
   } else {
      print "Warning: Can not access/execute Manpage script ($make_manpage_script).\nShowing help in text-only format.\n\n";
   }
}

my $multiplier_list=join(', ',keys %multipliers);
my $time_multiplier_list=join(', ',keys %time_multipliers);

# there is probably a better way to do this
# I want to list out all the keys in the hash %mode_list where the value = 0
my $modelist='';
for my $mode (sort keys %mode_list) {
   if (!$mode_list{$mode}) {
      $modelist.="$mode, "
   }
}
$modelist=~s/, $/./;

# list out the valid fields for each mode for warn/crit specifications
my %field_lists;
foreach my $mode (keys %valid_test_fields) {
   $field_lists{$mode}=join(', ',@{$valid_test_fields{$mode}});
   $field_lists{$mode}=~s/, $/./; # remove the last comma space
   # I can't work out one nice regex to do this next bit, so its 2
   # One for when there is only 1 field defined and
   # One for when there is more than 1 field defined
   # The array @{$valid_test_fields{$mode}} contains the list
   if ($#{$valid_test_fields{$mode}}>0) {
      # use the multi field regex
      $field_lists{$mode}=~s/([\w%]+)(,)*/Valid Warning\/Critical Fields are: $1 (Default)$2/; # stick (default) after the first one in the list
   } else {
      # single field only
      $field_lists{$mode}="The only valid Warning\/Critical Field is $field_lists{$mode}, so you don't even need to specify it!";
   }
    
  
}

my $ini_info='';
if ($wmi_ini_file||$wmi_ini_dir) {
   $ini_info="\nINI FILE SPECIFIED\n There is an ini file/dir configured. The ini files contain more checks. --inihelp on its own shows a one line summary of all MODES/SUBMODES contained within the ini files. --inihelp specified with a MODE/SUBMODE shows the help just for that mode. All of the inihelp is also shown at the end of this help text.\n\n";
}

print <<EOT;
NAME
 check_wmi_plus.pl - Client-less checking of Windows machines
BRIEF
 Typical Usage:  
 
 check_wmi_plus.pl -H HOSTNAME -u DOMAIN/USER -p PASSWORD [-A AUTHFILE] -m MODE [-s SUBMODE] [-a ARG1 ] [-w WARN] [-c CRIT]

 Complete Usage:  
 
 check_wmi_plus.pl -H HOSTNAME -u DOMAIN/USER -p PASSWORD -m MODE [-s SUBMODE] [-b BYTEFACTOR] [-w WARN] [-c CRIT] [-a ARG1 ] [-o ARG2] [-3 ARG3] [-4 ARG4] [-5 ARG5] [-A AUTHFILE] [-t TIMEOUT] [-y DELAY] [--namespace WMINAMESPACE] [--extrawmicarg EXTRAWMICARG] [--nodatamode] [--nodataexit NODATAEXIT] [--nodatastring NODATASTRING] [-d] [-z] [--inifile=INIFILE] [--inidir=INIDIR] [--inihelp] [--nokeepstate] [--keepexpiry EXPIRY] [--keepid KID] [--joinexpiry EXPIRY] [--helperexpiry EXPIRY] [-v OSVERSION] [--help] [--itexthelp] [--forcewmiccommand] [-icollectusage] [--ishowusage] [--logswitch] [--logkeep] [--logsuffix SUFFIX] [--logshow] [--variablesdisabled] [--forceiniopen] [--forcetruncateoutput LEN] [--Mapexit MAPSPEC] [--fieldshow] [--filterinirowsbystatus FILTERSTATUS] [--Convertslash]
 
 Help as a Manpage:  
 
 check_wmi_plus.pl --help
 
 Help as Text:  
 
 check_wmi_plus.pl --itexthelp (its very long!)
 
DESCRIPTION
 check_wmi_plus.pl is a client-less Nagios plugin for checking Windows systems.
 No more need to install any software on any of your Windows machines. Check directly from your Nagios server.
 Check WMI Plus uses the Windows Management Interface (WMI) to check for common services (cpu, disk, sevices, eventlog...) on Windows machines. It requires the open source wmi client for Linux (wmic).

 Besides the built in checks, Check WMI Plus functionality can be easily extended through the use of ini files. Check WMI Plus comes with several ini files, but you are free to add your own checks to your own ini file. 

 For more information see the website www.edcint.co.nz/checkwmiplus

REQUIRED OPTIONS
 -H HOSTNAME  specify the name or IP Address of the host that you want to check
 
You must specifiy a username/password/domain in one of two ways. The use of -u DOMAIN/USER -p PASSWORD always overrides the values contained in -A AUTHFILE
 -u DOMAIN/USER  specify the DOMAIN (optional) and USER that has permission to execute WMI queries on HOSTNAME
 
 -p PASSWORD  the PASSWORD for USER
 
 -A AUTHFILE  the full path to an authentication file. The file is passed directly to $wmic_command. Check WMI PLus does not read the file and hence you must get the file format as required by $wmic_command. You can override the settings in this file by using -u DOMAIN/USER -p PASSWORD.

       Authentication File format is
         username=USERNAME  
         password=PASSWORD  
         domain=DOMAIN  

       Set your own values for USERNAME, PASSWORD and DOMAIN. DOMAIN may be nothing.

 -m MODE  the check mode. The list of valid MODEs and a description is shown below

COMMONLY USED OPTIONS
 -s SUBMODE  the submode. Some MODEs have one or more submodes. These are also described below.
 
 -a ARG1  argument number 1. Its meaning depends on the MODE/SUBMODE combination.
 
 -o ARG2  argument number 2. Its meaning depends on the MODE/SUBMODE combination.
 
 -3 ARG3  argument number 3. Its meaning depends on the MODE/SUBMODE combination.
 
 -4 ARG4  argument number 4. Its meaning depends on the MODE/SUBMODE combination.
 
 -5 ARG5  argument number 5. Its meaning depends on the MODE/SUBMODE combination.

 -w WARN  specify warning criteria. You can specify none, one or more criteria. If any one of the criteria is triggered then the plugin will exit with a warning status (unless a critical status is also triggered). See below for how to specify warning criteria.

 -c CRIT  specify critical criteria. You can specify none, one or more criteria. If any one of the criteria is triggered then the plugin will exit with a critical status. See below for how to specify warning criteria.

LESS COMMONLY USED OPTIONS
 -b BYTEFACTOR  BYTEFACTOR is either 1000 or 1024 and is used for conversion units eg bytes to GB. Default is 1024.

 -t TIMEOUT  specify the number of seconds before the plugin will timeout. Some WMI queries take longer than others and network links with high latency may also require you to increase this from the default value of $TIMEOUT
 
 --includedata DATASPEC  specify data values that are to be included. See the section below on INCLUDING AND EXCLUDING WMI DATA

 --excludedata DATASPEC  specify data values that are to be excluded. See the section below on INCLUDING AND EXCLUDING WMI DATA

 --nodatamode  Controls how the plugin responds when no data is returned by the WMI query. Normally, when no data is returned from the WMI query, the plugin returns an Unknown error. If you specify this option, then no data is not an error condition anymore and you can use WARN/CRIT checking on the _ItemCount field. This is only useful for some checks eg checkfilesize where you might get no data back from the WMI query when the file is not found, but getting no data back is not an error.

 --nodataexit NODATAEXIT  specify the plugin status result if the WMI Query returns no data. Ignored if --nodatamode is set. Valid values are 0 for OK, 1 for Warning, 2 for Critical (Default) or 3 for Unknown. Only used for some checks. All checks from the ini file can use this.
 
 --nodatastring NODATASTRING  specify the string that tha plugin will display if the WMI Query returns no data. Ignored if --nodatamode is set. Only used for some checks where the use of NODATAEXIT is valid. All checks from the ini file can use this.
 
 -y DELAY  Specify the delay between 2 consecutive WMI queries that are run in a single call to the plugin. Defaults are set for certain checks. Only valid if --nokeepstate used.

 --namespace WMINAMESPACE  Specify the WMI Namespace. eg root/MicrosoftDfs. The default is root/cimv2. Use '/' (forward slash) instead of '\\\\' (backslash).

 --extrawmicarg EXTRAWMICARG  Specify additional arguments to be passed to the wmic command. The arguments are passed directly and must be complete and understood by wmic. In order to assist with escaping of quotes, all # are translated to ". To pass --option="client ntlmv2 auth"=Yes to wmic specifiy --extrawmicarg "--option=#client ntlmv2 auth#=Yes". This option can be specified multiple times to pass multiple arguments to wmic. If you are using the conf file setting for extra wmic arguments then any options specified here are added to the ones specified in the conf file.

 --inihelp  Show the help from the INIFILE for the specified MODE/SUBMODE. If specified without MODE/SUBMODE, this shows a quick short summary of all valid MODE/SUBMODEs in the ini files.
 
 --inifile=INIFILE  INIFILE is the full path of an ini file to use. The use of --inidir is preferred over this option.
 
 --inidir=INIDIR  INIDIR is the full path of an ini directory to use. The plugin reads files ending in .ini in INIDIR in the default directory order. The INIFILE is read first, if defined, then each .ini file found in INIDIR. Ini files read later merge with earlier ini files. For any settings that exist in one or more files, the last one read is set.
 
 --nokeepstate  disables the default mode of keeping state between plugin runs.
 
 --keepexpiry EXPIRY  EXPIRY is the number of seconds after which the plugin assumes that the previously collected data has expired. The default is $opt_keep_state_expiry sec. You should run your plugin more frequently than this value or set EXPIRY higher.
 
 --keepid KID  KID is a unique identifier. This is normally not needed. In order to keep state between plugin runs, the data is written to a file. In order to stop collisions between different plugin runs, and hence incorrect calculations,  the filename is unique based on the checkmode, hostname, arguments passed etc. If for some reason these are not sufficient and you are experiencing collisions, you can add a unique KID to each plugin check to ensure uniqueness.
 
 --joinexpiry EXPIRY  EXPIRY is the number of seconds after which the plugin assumes that the previously collected join data has expired. The default is $opt_join_state_expiry sec. Join data that is defined as being reasonably static by whomever created the check will only get refreshed every EXPIRY seconds.
 
 --helperexpiry EXPIRY  EXPIRY is the number of seconds after which the plugin assumes that the previously collected helper query data has expired. The default is $opt_helper_state_expiry sec. Helper query data that is defined as being reasonably static by whomever created the check will only get refreshed every EXPIRY seconds.
 
 -z  Provide full specification warning and critical values for performance data. Not all performance data processing software can handle this eg PNP4Nagios. If this is used with -d then usernames and passwords will be shown rather than being masked (useful if you want to cut and paste the exact wmic command for testing).
 
 -d  Enable debug. Use this to see a lot more of what is going on including the exact WMI Query and results. User/passwords should be masked in the resulting output unless -z is specified.
 
 --forcewmiccommand  Force the use of the wmic binary instead of using the WMI Client library. The WMI Client library is used automatically (since it is faster) if it is available on the host running check_wmi_plus. You can tell if you are using the library or the binary wmic by examining the output of -d.

 --ishowusage  Pro Version only. Show usage stats in plugin output.

 --icollectusage  Pro Version only. Collect usage stats.

 --logswitch  Pro Version only. Switch usage DB file.

 --logkeep  Pro Version only. do not remove the Usage DB file you are switching to.

 --logsuffix SUFFIX  Pro Version only. Switch to the Usage DB file using SUFFIX.

 --logshow  Pro Version only. Show current Usage DB file.
 
 --variablesdisabled  Disable the use of static variables (from the ini files).
 
 --forceiniopen  Force reading of the ini files. You may want to do this if you are doing a non-ini file check and you are using global variables defined in an ini file. Only use this if you really need it since it makes each invocation of the plugin a lot slower (unless you are doing an ini file check already).
 
 --forcetruncateoutput LEN  Restrict the length of the plugin output to LEN bytes. The default value is $the_arguments{'_truncate_output'}.
 
 --Mapexit MAPSPEC  Pro Version only. Change the exit code plugin would normally use based on MAPSPEC. MAPSPEC format is one of X:Y or X:Y:REGEX, where X is the original exit code and Y is the new exit code. If REGEX is specified then the exit code mapping is only done if the plugin output matches the case insensitive regular expression REGEX. Multiple --Mapexit parameters can be specified. Order is important as the first one that matches will be used.
 
 --fieldshow  Show the list of fields available/used for a specific check. Run the check normally and add this option. The list of fields will be shown above the plugin output. This is useful when configuring checks. It shows all the fields available for the specific check. For example, use it to show which fields you can use for --includedata etc 

 --filterinirowsbystatus FILTERSTATUS  Filter ini-based checks by their status. This is useful for checks that return many rows and where you may only want to show results that are not ok (for example). This only applies to the per row results and not to the overall state. FILTERSTATUS is a regular expression of Nagios return codes that you wish to display. Nagios return codes are 0-3, where 0=OK, 1=WARNING, 2=CRITICAL, 3=UNKNOWN. In order to display return codes 1 or 2 only a regular expression like 1|2 would be used. To display only OK states (return code 0) a regular expression of 0 would suffice.

KEEPING STATE
This only applies to checks that need to perform 2 WMI queries to get a complete result eg checkcpu, checkio, checknetwork etc. Keeping State is used by default.

Checks like this take 2 samples of WMI values (with a DELAY in between) and then calculate a result by differencing the values. By default, the plugin will "keepstate", which means that 1 WMI sample will be collected each time the plugin runs and it will calculate the difference using the values from the previous plugin run. For something like checkcpu, this means that the plugin gives you an average CPU utilisation between runs of the plugin. Even if you are 0% utilisation each time the plugin runs but 100% in between, checkcpu will still report a very high utilisation percentage. This makes for a very accurate plugin result. Another benefit of keeping state is that it results in fewer WMI queries and the plugin runs faster. If you disable keeping state, then, for these types of checks, the plugin reverts to taking 2 WMI samples with a DELAY each time it runs and works out the result then and there. This means that, for example, any CPU activity that happens between plugin runs is never detected.

There are some specific state keeping options: 
--nokeepstate, 
--keepexpiry KEXPIRY, 
--keepid KID, 

The files used to keep state are stored in $tmp_dir. The DELAY setting is not applicable when keeping state is used. If you are "keeping state" then one of the first things shown in the plugin output is the sample period.

$ini_info

INCLUDING AND EXCLUDING WMI DATA
The --includedata and --excludedata options modify the data returned from the WMI query to include/exclude only data that matches DATASPEC. DATASPEC is in the same format as warning/critical specifications (See Section WARNING AND CRITICAL SPECIFICATION).

At the moment this is largely enabled for checks from ini files and it typically does not apply to the built-in modes. All includes/excludes defined on the command line and the ini file are combined and then processed.
PRO users can use this for the following inbuilt modes: checkdrivesize, checkgroup, checklogon, checknetwork, checkpage, checkprintjob, checkprocess, checkservice, checkshare, checksmart, checkstartupcommand, checkuseraccount, checkvolsize.
PRO users can use regular expressions as as warning/critical specifications hence increasing the power of this option.

Any fields that are returned by the WMI query can be used, not just the ones that are displayed. Use the --fieldshow option to show the valid fields for a specific check. You might need to use the debug mode (-d) to see all the valid fields available.

The include/exclude arguments can be specified multiple times on the command line. 

If --includedata is not used, all data is included.
If any of the inclusions are met the data is included. If any of the exclusions are met then the data is excluded. Inclusions are processed before Exclusions. 

This can be useful to reduce the length of the output for certain checks or to focus on more important data eg on processes using more than 5% of the CPU rather than the potentially hundreds that are using less than 5%.

Examples using -m checkproc -s cpu:

--inc IDProcess=\@2000:3000 to include all process IDs that are inside the range of 2000 to 3000.

--exc _AvgCPU=\@0:5 to exclude all processes where the average CPU utilisation is inside the range of 0 to 5.

Examples using -m checkdrivesize (PRO only):

--excludedata DeviceID=~'F:|e:' to exclude drives matching F: or E:

WARNING AND CRITICAL SPECIFICATION

If warning or critical specifications are not provided then no checking is done and the check simply returns the value and any related performance data. If they are specified then they should be formatted as shown below.

Warning and Critical criteria can be specified as a RANGE or as a regular expression (Pro version only).

 RANGES
A RANGE is defined as a start and end point (inclusive) on a numeric scale (possibly negative or positive infinity). The theory is that the plugin will do some sort of check which returns back a numerical value, or metric, which is then compared to the warning and critical thresholds. 

Multiple warning or critical specifications can be specified. This allows for quite complex range checking and/or checking against multiple FIELDS (see below) at one time. The warning/critical is triggered if ANY of the warning/critical specifications are triggered.

If a ini file check returns multiple rows eg checkio logical, criteria are applied to ALL rows and any ONE row meeting the criteria will cause a trigger. If the check has been defined properly it will show which row/instance triggered the criteria as well as the overall result.

This is the generalised format for ranges:
FIELD=[@]start:end

The convention used for field names in this plugin is as follows:
   - FIELDs that start with _ eg _Used% are calculated or derived values
   - FIELDs that are all lower case are command line arguments eg _arg1
   - Other FIELDs eg PacketsSentPersec are what is returned from the WMI Query

 NOTES
   1. FIELD describes which value the specification is compared against. It is optional (the default is dependent on the MODE).
   2. start <= end
   3. start and ":" is not required if start=0
   4. if range is of format "start:" and end is not specified, assume end is infinity
   5. to specify negative infinity, use "~"
   6. alert is raised if metric is outside start and end range (inclusive of endpoints)
   7. if range starts with "@", then alert if inside this range (inclusive of endpoints)
   8. The start and end values can use multipliers from the following list: 
      $multiplier_list or the time-based multipliers $time_multiplier_list.
      The time-based multipliers are normally used where the data is in seconds.
      eg 1G for 1 x 10^9 or 2.5k for 2500
      eg 1wk for 1 week, 3.5day for 3.5 days etc

 EXAMPLE RANGES
 This table lists example WARN/CRIT criteria and when they will trigger an alert.
 10                      < 0 or > 10, (outside the range of {0 .. 10})
 10:                     < 10, (outside {10 .. infinity})
 ~:10                    > 10, (outside the range of {-infinity .. 10})
 10:20                   < 10 or > 20, (outside the range of {10 .. 20})
 \@10:20                 >=10 and <=20, (inside the range of {10 .. 20})
 10G                     < 0 or > 10G, (outside the range of {0 .. 10G})

 EXAMPLES WITH FIELDS
 for MODE=checkdrivesize:
 _UsedGB=10              Check if the _UsedGB field is < 0 or > 10,  (outside the range of {0 .. 10}) 
 _Used=10G               Check if the _Used field is   < 0 or > 10G, (outside the range of {0 .. 10G}) 
 10                      Check if the _Used% field is  < 0 or > 10,  (outside the range of {0 .. 10}), no field specified since _Used% is the default
 _Used%=10               Check if the _Used% field is  < 0 or > 10,  (outside the range of {0 .. 10}) 

 EXAMPLES WITH MULITPLE SPECIFICATIONS
 for MODE=checkdrivesize:
 -w _UsedGB=10 -w 15 -w _Free%=5: -c _UsedGB=20 -c _Used%=25  
 This will generate a warning if 
    - the Used GB on the drive is more than 10 or 
    - the used % of the drive is more than 15% or
    - the free % of the drive is less than 5%
 
 This will generate a critical if 
    - the Used GB on the drive is more than 20 or 
    - the used % of the drive is more than 25%

 REGULAR EXPRESSIONS
This is the generalised format for a regular expression (Pro version only):

FIELD=~REGEX  (for testing if the value of the FIELD matches the REGEX)
or
FIELD=!~REGEX  (for testing if the value of the FIELD does not match the REGEX)

Note that as for the definition of RANGES (see section above for more details)
   - the same naming conventions for FIELD names apply.
   - specification of the FIELD is optional (in which case the format is ~REGEX or !~REGEX) and the default FIELD is dependent on the MODE.

BUILTIN MODES
 The following modes are coded directly into the plugin itself and do not require any ini files to function.
 
 Each mode describes the optional arguments and parameters valid for use with that MODE.
 
 checkcpu  
   Some CPU checks just take whatever WMI or SNMP gives them from the precalculated values. We don't.
   We use WMI Raw counters to calculate values over a given timeperiod. This is much more accurate than taking Formatted WMI values.
   $default_help_text_delay
   WARN/CRIT  can be used as described below.
   $field_lists{'checkcpu'}.

checkcpuq  
   The WMI implementation of CPU Queue length is a point value.
   We try and improve this slightly by performing several checks and averaging the values.
   ARG1  (optional) specifies how many point checks are performed. Default 3.
   DELAY  (optional) specifies the number of seconds between point checks. Default 1. It can be 0 but in reality there will always be some delay between checks as it takes time to perform the actual WMI query 
   WARN/CRIT  can be used as described below.
      $field_lists{'checkcpuq'}.
   
   Note: Microsoft says "A sustained processor queue of greater than two threads generally indicates
   processor congestion.". However, we recommended testing your warning/critical levels to determine the
   optimal value for you.
   
checkdrivesize  
   By default, drives in a non-OK state will be shown first.
   Also see checkvolsize
   ARG1  drive letter or volume name of the disk to check. If omitted a list of valid drives will be shown. If set to . all drives will be included.
      To include multiple drives separate them with a |. This uses a regular expression so take care to
      specify exactly what you want. eg "C" or "C:" or "C|E" or "." or "Data"
   ARG2  Set this to 1 to use volumes names (if they are defined) in plugin output and performance data ie -o 1
   ARG3  Set this to 1 to include information about the sum of all disk space on the entire system.
      If you set this you can also check warn/crit against the overall disk space.
      To show only the overall disk, set ARG3 to 1 and set ARG1 to 1 (actually to any non-existant disk)
      Eg -o 1 -3 1
   ARG4  This is a 2 character string which controls how the drive information is displayed. 
   
       Format is XY where
         X=0, display not-ok drives first
         X=1, display drives in the order the the WMI query returns them in
         X=2, only display not-ok drives
         X=3, If all drives are OK, same display as X=1. If there are any not OK drives, same display as X=2
         Y=0, show results on a single line
         Y=1, show results as multi-line with the first line being a high level summary of status 

   WARN/CRIT  can be used as described below.
      $field_lists{'checkdrivesize'}.
      
   PRO Users can use --includedata and --excludedata for this mode. Note that, if using ARG3, and these options, the system totals may be misleading.

checkeventlog  
   ARG1  Name of the log eg "System" or "Application" or any other Event log as shown in the Windows "Event Viewer". You may also use a comma delimited list to specify multiple event logs. You can also specify event log names using the wildcard character % eg system,app%,%shell%. Default is system
   ARG2  A comma delimited list of severity numbers. If not specfied this defaults to 1. If only one level is specified, all severity levels less than and equal to it are included. If more than one is specified then only those levels are included. To include only a single level, put a comma before the severity number eg ,3.
   
       The severity levels available are:  
       5 = Security Audit Failure.
       4 = Security Audit Success
       3 = Information
       2 = Warning
       1 = Error
   
   ARG3  Number of past hours to check for events. Default is 1
   ARG4  Comma delimited list of ini file sections to get extra settings from. Default value is eventdefault.
      ie use the eventdefault section settings from the ini file. The ini file contains regular expression based inclusion
      and exclusion rules to accurately define the events you want to or don't want to see. Event inclusions and exlusions rules are ANDed together. See the events.ini file for details.
   ARG5  The Include/Exclude mode. Defaults to 'any', which includes event log records that match any of the match criteria. PRO users can additionally specify 'includeall' which will only include event log records that match all the match criteria.
   WARN/CRIT   can be used as described below.
      $field_lists{'checkeventlog'}.

   Examples:  
      to report all errors (1) that got logged in the past 24 hours in the System event log use:
      
      -a System -3 24
      
      to report all errors (1) that got logged in the past 24 hours in any event log use:
      
      -a % -3 24

      to report all warnings (2) and errors (1) that got logged in the past 4 hours in the Application event log use:
      
      -a application -o 2 -3 4 OR -a application -o 1,2 -3 4
      
      to report all information (3) and errors (1) that got logged in the past 4 hours in the Application event log use:
      
      -a application -o 1,3 -3 4
      
      to report only Security Audit Failure (5) events that got logged in the past 4 hours in any event log use:
      
      -a % -o ,5 -3 4

      to report your custom mix of event log messages from the system event log use (the names passed to this argument are ini sections defined in an ini file eg event.ini):
      
      -4 eventinc_1,eventinc_2,eventinc_3,eventexclude_1

checkfileage  
   ARG1  full path to the file. Use '/' (forward slash) instead of '\\\\' (backslash).
   ARG2  set this to one of the time multipliers ($time_multiplier_list)
      This becomes the display unit and the unit used in the performance data. Default is hr.
      -z can not be used for this mode.
   WARN/CRIT  can be used as described below.
      $field_lists{'checkfileage'}
      
      The warning/critical values should be specified in seconds. However you can use the time multipliers
      ($time_multiplier_list) to make it easier to use
      
      eg instead of putting -w 3600 you can use -w 1hr
      
      eg instead of putting -w 5400 you can use -w 1.5hr
      
      Typically you would specify something like -w 24: -c 48:

checkfilesize  
   ARG1  full path to the file. Use '/' (forward slash) instead of '\\\\' (backslash).
      eg "C:/pagefile.sys" or "C:/windows/winhlp32.exe"
   NODATAEXIT  can be set for this check.
   WARN/CRIT  can be used as described below.
   If you specify --nodatamode then you can use WARN/CRIT checking on the _ItemCount. _ItemCount should only ever be 0 or 1.
      This allows you to control how the plugin responds to non-existant files.
      $field_lists{'checkfilesize'}.

checkfoldersize  
   WARNING - This check can be slow and may timeout, especially if including subdirectories. 
      It can overload the Windows machine you are checking. Use with caution.
   ARG1  full path to the folder. Use '/' (forward slash) instead of '\\\\' (backslash). eg "C:/Windows"
   ARG4  Set this to s to include files from subdirectories eg -4 s
   NODATAEXIT  can be set for this check.
   WARN/CRIT  can be used as described below.
   If you specify --nodatamode then you can use WARN/CRIT checking on the _ItemCount. _ItemCount should only ever be 0 or 1.
      This allows you to control how the plugin responds to non-existant files.
      $field_lists{'checkfoldersize'}.
      -
checkgroup
   WARN/CRIT  can be used as described below.
      $field_lists{'checkgroup'}
   Note:  Use --nodatamode and/or NODATAEXIT settings to control what happens if no matching groups are found.

   PRO Users can use --includedata and --excludedata for this mode. Eg --incl LocalAccount=~true.
   The groups are defined as changed if the fields shown in the plugin output change between runs.
   Check for changes by using -w _ItemChange=~true.

checkgroupuser
   WARN/CRIT  can be used as described below.
      $field_lists{'checkgroupuser'}
   Note:  Use --nodatamode and/or NODATAEXIT settings to control what happens if no matching group users are found.

   PRO Users can use --includedata and --excludedata for this mode. Eg --incl _GroupName=~admin.
   The group users are defined as changed if the fields shown in the plugin output change between runs.
   Check for changes by using -w _ItemChange=~true.

checklogon (PRO only)
   WARN/CRIT  can be used as described below.
      $field_lists{'checklogon'}
   Note:  Use --nodatamode and/or NODATAEXIT settings to control what happens if no matching logons are found.

   PRO Users can use --includedata and --excludedata for this mode. Eg --incl _LogonTypeDescription=~interactive.
   Check for changes by using -w _ItemChange=~true.
   _LogonTypeDescriptions are available from https://msdn.microsoft.com/en-us/library/windows/desktop/aa394189%28v=vs.85%29.aspx. Commonly used values are Interactive, System and Network
   Note:  This check uses 2 WMI queries per run to collect all the required information. It is possible that logged on users change between these 2 queries eg the user logging in to perform the WMI query and so you may end up with some incomplete information. If you want to exclude these records, include only data with has a LogonId by adding --incl LogonId=~.

checkmem  
   This mode checks the amount of physical RAM in the system.
   WARN/CRIT  can be used as described below.
      $field_lists{'checkmem'}.

checknetwork  
   These network checks use WMI Raw counters to calculate values over a given timeperiod. 
   This is much more accurate than taking Formatted WMI values.
   ARG1  Specify the network interface the stats are collected for.  If set to . all interfaces will be included.
      To include multiple interfaces separate them with a | or specify a common identifier eg part of an IP Address or MAC Address. This uses a regular expression so take care to
      specify exactly what you want. eg "LAN0" or "192.168.0.1" or "192.168.0" or "LAN0|LAN2" or "." or "08:00:27:85:CE:6D" or "08:00:27"
      To specify a network interface you can use either the Connection Name (as seen in Control Panel), IP Address (IPv4 or IPV6) or MAC Address. You can also use the name of the network adaptors as seen from WMI which is similar to what is seen in the output of the ipconfig/all command on Windows. However, it is not exactly the same and can be tricky since this uses a regular expression. Run without -a to show the interface
      names, IP Addresses, MAC Addresses. Typically you need to use '' around the adapter name when specifying.
   ARG2  Set this to the string 'legacy' to query the older WMI class (Win32_PerfRawData_Tcpip_NetworkInterface) for obtaining network statistics. You may need to do this for Windows Server versions prior to Windows Server 2012.
   $default_help_text_delay
   WARN/CRIT  can be used as described below.
      $field_lists{'checknetwork'}
   BYTEFACTOR  defaults to 1000 for this mode. You can override this if you wish.

   Note:  
      This check does up to 3 WMI queries so it may be slow. You might need to use the -t option. Since 2 of the WMI queries are relatively static, their results are cached and you can set the refresh period for this data using --joinexpiry.
      
   PRO Users can use --includedata and --excludedata for this mode.
   
checkpage  
   This mode checks the amount of page file usage.
   The total page file size varies between the Initial size and the Maximum Size you set in Windows.
   ARG1  Set this to "auto" to automatically set warning/critical levels. The warning level is set to the same as the
      inital size of the page file. The critical level is set to 80% of the maximum page file size.
      If set, it is used instead of any command line specification of warning/critical settings.
      Note: The separate WMI query to obtain the additional information required to use this setting only works if you have set a custom size for your page files. If they are set to "System Managed", this will not work. You can tell if an automatic warning/critical level has been set by examining the performance data for the "Used" value. In this example - "'E:/pagefile.sys Used'=41943040Bytes;104857600;167772160;" you can tell that the levels have been automatically set because there are 3 numeric values in the performance data - the last 2 are the warning and critical levels.
   ARG2  drive letter page to check. If omitted all page files will be included.
      To include multiple drives separate them with a |. This uses a regular expression so take care to
      specify exactly what you want. eg "C:" or "C:|E:". Make sure you use a : after each drive letter to match properly.
   ARG3  Set this to 1 to include information about the sum of all pages file on the entire system.
      If you set this you can also check warn/crit against the overall disk space.
      To show only the overall page file info, set ARG3 to 1 and set ARG2 to 1 (actually to any non-existant disk)
      Eg -o 1 -3 1
   ARG4  Set this to 1 to add the RAM values to the Page file values. This option automatically disables the use of ARG1 and ARG2 and automatically sets ARG3 to show only the system totals. The display is simplified to show only Used, Free and Total amounts.
      Eg -4 1

   WARN/CRIT  can be used as described below.
   $field_lists{'checkpage'}.

   Note:  
      This check does up to 2 WMI queries (if -a auto or ARG4 is used) so it may be slow. You might need to use the -t option. Since 1 of the WMI queries (for -a auto) is relatively static, its results are cached and you can set the refresh period for this data using --joinexpiry.

   PRO Users can use --includedata and --excludedata for this mode.

checkprintjob (PRO only)
   WARN/CRIT  can be used as described below.
      $field_lists{'checkprintjob'}
   Note:  Use --nodatamode and/or NODATAEXIT settings to control what happens if no matching jobs are found.

   PRO Users can use --includedata and --excludedata for this mode. Eg --incl _PrintJob=~laser.
   The print queue is defined as changed if the fields shown in the plugin output change between runs.
   Check for changes by using -w _ItemChange=~true.

checkprocess  
   SUBMODE  Set this to Name, ExecutablePath, or Commandline to determine if ARG1 and ARG3 matches against just the
      process name (Default), the full path of the executable file, or the complete command line used to run the process.
   ARG1  A regular expression to match against the process name, executable path or complete command line.
      The matching processes are included in the resulting list. Use . alone to include all processes. Typically the process
           - Executable Path is like DRIVE:PATH/PROCESSNAME eg C:/WINDOWS/system32/svchost.exe,
           - Command Line is like DRIVE:PATH/PROCESSNAME PARAMETERS eg C:/WINDOWS/system32/svchost.exe -k LocalService
         Use '/' (forward slash) instead of '\\\\' (backslash). eg "C:/Windows" or "C:/windows/system32"
         Note: Any '/' in your regular expression will get converted to '\\\\'.
   ARG2  Set this to 'Name' (Default), Executablepath or 'Commandline' to display the process names, executablepath or the 
      whole command line.
   ARG3  A regular expression to match against the process name, executable path or complete command line.
      The matching processes are excluded from the resulting list. This exclusion list is applied after the inclusion list.
      
   For SUBMODE and ARG2 you only need to specify the minimum required to make it unique. Any of the following will work
   -s e, -s exe, -s c, -s com, -o e, -o exe, -o c, -o com
   WARN/CRIT  can be used as described below.
      $field_lists{'checkprocess'}
   
   PRO Users can use --includedata and --excludedata for this mode.

checkquota (PRO only)
   WARN/CRIT  can be used as described below.
      $field_lists{'checkquota'}
   Note:  Use --nodatamode and/or NODATAEXIT settings to control what happens if no matching quotas are found.

   PRO Users can use --includedata and --excludedata for this mode. Eg --incl _User=~bob --incl _StatusDescription=~exceeded
   The quotas are defined as changed if the fields shown in the plugin output change between runs.
   Check for changes by using -w _ItemChange=~true.
   Note:  This check can take a long time to collect the data. You may need to increase the timeout.

checkservice  
   ARG1  A regular expression that matches against the short or long service name that can be seen in the properties of the
      service in Windows. The matching services are included in the resulting list. Use . alone to include all services.
      Use Auto to check that all automatically started services are OK.
   ARG2  A regular expression that matches against the short or long service name that can be seen in the properties of the
      service in Windows. The matching services are excluded in the resulting list.
      This exclusion list is optional and applied after the inclusion list.
   ARG3  Optionally used to specify what type of services to display under which conditions. If not specified, all services are shown in all conditions. This is a comma delimited list of specifications in the following format: WHEN=WHAT, where WHEN is one of ok,warning,critical,unknown and WHAT is one of all,ok,bad,none. Examples: "ok=none,warning=bad,critical=bad" or "warning=all,critical=none". So to show only the "bad" services when a warning is given use "warning=bad".
   ARG4  Used to specify which type of services to display based on the StartMode. Only services with a StartMode matching this regular expression will be included. Examples: To include only manually started services use "-4 manual". To include all automatic and manual services use "-4 auto|man"
      This list is optional and applied before the exclusion list.
   WARN/CRIT  can be used as described below.
      $field_lists{'checkservice'}

   Note:  
      A "Good" service is one that is Started, its State is Running and its Status is OK. Anything else is considered "Bad". If you don't want certain services included in this count then you will need to exclude them with -o ARG2

   PRO Users can use --includedata and --excludedata for this mode.

checkshare (PRO only)
   WARN/CRIT  can be used as described below.
      $field_lists{'checkshare'}
   Note:  Use --nodatamode and/or NODATAEXIT settings to control what happens if no matching users are found.

   PRO Users can use --includedata and --excludedata for this mode. Eg --incl Name=~C.
   Check for changes by using -w _ItemChange=~true.

checksmart  
   Check the SMART status of all hard drives on the system. Will only work for physical drives (ie not on disks in a virtual machine!). Probably will not work for disk array drives as they are not normally presented to the system as disks. Reports if any drives are failing the SMART checks which signals
      imminent hard drive failure. It also grab various SMART attributes such as temperature. It also grab the disk serial
      number which may work on OS versions above Win XP and Win Server 2003.
   ARG1  (optional) By default checksmart shows all of a small set of SMART attributes as peformance data. If you want to reduce this list you can by specifying a comma delimited list of attribute codes. Specify ARG1 as 'none' to obtain no SMART attributes. This will actually remove one of the WMI queries. Specify ARG1 as 'list' to list all the valid attribute codes. If you wish to warn/critical against the temperature value you must at least specify that code (194).

   WARN/CRIT  can be used as described below.
      $field_lists{'checksmart'}

   Note:  
      This check does up to 4 WMI queries so it may be slow. You might need to use the -t option. Since 2 of the WMI queries are relatively static, their results are cached and you can set the refresh period for this data using --joinexpiry.

   Examples:  
      Warn if more than zero drives fail the SMART check or if any of the disk temperatures are above 40 degrees Celcius.
      
      -m checksmart -w 0 -w Temperature=40
      
      List only the SMART temperature
      
      -m checksmart -a 194
      
      List Temperature and Power on Hours
      
      -m checksmart -a 194,9

   PRO Users can use --includedata and --excludedata for this mode.

checkstartupcommand (PRO only)
   WARN/CRIT  can be used as described below.
      $field_lists{'checkstartupcommand'}
   Note:  Use --nodatamode and/or NODATAEXIT settings to control what happens if no matching commands are found.

   PRO Users can use --includedata and --excludedata for this mode. Eg --incl _Name=~onedrive.
   The startup commands are defined as changed if the fields shown in the plugin output change between runs.
   Check for changes by using -w _ItemChange=~true.

checktime  
   This mode compares the time on the Windows machine to the time on the server running Check WMI Plus. It uses UTC time. use the warning/critical criteria to trigger if the time difference exceeds a threshold that you define.
   WARN/CRIT  can be used as described below.
      $field_lists{'checktime'}
      
      The warning/critical values should be specified in seconds and you will find a range most useful.
      
      Typically you would specify something like -w -10:10 -c -30:30 (to warn if the time difference exceeds 10 seconds and go critical if the time difference exceeds 30 seconds)

checkuptime  
   WARN/CRIT  can be used as described below.
      $field_lists{'checkuptime'}
      
      The warning/critical values should be specified in seconds. However you can use the time multipliers ($time_multiplier_list) to make it easier to use.
      
      eg instead of putting -w 1800 you can use -w 30min
      
      eg instead of putting -w 5400 you can use -w 1.5hr
      
      Typically you would specify something like -w 20min: -c 10min: (to if less than 20 min and critical if less than 10 min)

checkuseraccount
   WARN/CRIT  can be used as described below.
      $field_lists{'checkuseraccount'}
   Note:  Use --nodatamode and/or NODATAEXIT settings to control what happens if no matching users are found.

   PRO Users can use --includedata and --excludedata for this mode. Eg --excl Disabled=~true.
   The user accounts are defined as changed if the fields shown in the plugin output change between runs.
   Check for changes by using -w _ItemChange=~true.

checkvolsize  
   This can be used to monitor volumes mounted as junction points (ie no drive letters) as well as normal logical volumes.
   By default, drives in a non-OK state will be shown first.
   Also see checkdrivesize
   ARG1  drive letter or volume name or volume label of the volume to check. If omitted a list of valid drives will be shown. If set to . all drives will be included.
      To include multiple volumes separate them with a |. This uses a regular expression so take care to
      specify exactly what you want. eg "C" or "C:" or "C|E" or "." or "Data"
   ARG2  Set this to 1 to use labels (if they are defined) in plugin output and performance data ie -o 1
   ARG3  Set this to 1 to include information about the sum of all volume space on the entire system.
      If you set this you can also check warn/crit against the overall volume space.
      To show only the overall volume, set ARG3 to 1 and set ARG1 to 1 (actually to any non-existant volume)
   ARG4  This is a 2 character string which controls how the drive information is displayed. 
   
       Format is XY where
         X=0, display not-ok drives first
         X=1, display drives in the order the the WMI query returns them in
         X=2, only display not-ok drives
         X=3, If all drives are OK, same display as X=1. If there are any not OK drives, same display as X=2
         Y=0, show results on a single line
         Y=1, show results as multi-line with the first line being a high level summary of status 

   WARN/CRIT  can be used as described below.
      $field_lists{'checkvolsize'}.

   PRO Users can use --includedata and --excludedata for this mode. Note that, if using ARG3, and these options, the system totals may be misleading.

checkwsusserver  
   If there are any WSUS related errors in the event log in the last 24 hours a CRITICAL state is returned.
   This mode has been removed. You can perform the same check that this used to perform by using MODE=checkeventlog 
   using the wsusevents ini section. The command line parameters are:
   -m checkeventlog -a application -o 2 -3 24 -4 wsusevents -c 0

EOT

# add the inihelp to the end of this help
show_ini_help_overview(1);

finish_program($ERRORS{'UNKNOWN'});
}

1;