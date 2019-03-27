#!/usr/bin/perl
#########################################################################
# Description:  Checks Nutanix via SNMP.					
#
# Date : April 12 2016
# Version 1.0
# Author:       Fabrice Le Dorze
# Licence : GPL - http://www.fsf.org/licenses/gpl.txt
#########################################################################
#
use strict;
use Getopt::Long;
use Data::Dumper;

my $PROGNAME=`basename $0`;
chomp $PROGNAME;

#-----------------------------------------------------
# Usage function
#-----------------------------------------------------
sub Print_Usage() {
	print <<USAGE;

Usage: $PROGNAME -H <host> [-C <community>|-a <authProtocol> -u secName -A authPassword -x privProtocol -X privPassword] -t <type> [-s <subtype>[,<subtype2>]] [-T <timeout>] [-r <pattern> [-e]] [ -w <<subtype>=<warning>[,<subtype2>=<warning2>]...][-c <subtype>=<critical>[,<subtype2>=<critical2>]...] [-S]
USAGE
}

#-----------------------------------------------------
# Parameters
#-----------------------------------------------------
our %SUBTYPES=(
    Containers => {
        table => "containerinformationTable",
        key => "citContainerName",
	citUsedCapacity => "Capacity Usage percentage",
        citIOPerSecond => "IOs/second",
	citAvgLatencyUsecs => "Average Latency in microsecond",
	citIOBandwidth => "IO bandwidth in Kbps",
    },
   Disks => {
        key => "dstDiskId",
        table => "diskStatusTable",
	dstNumFreeBytes => "Capacity free percentage",
        dstNumberIops => "IOs/second",
	dstAverageLatency => "Latency in microsecond",
	dstIOBandwidth => "IO bandwidth in Kbps",
	dstNumFreeInodes => "Inode free percentage",
	dstState => "State",
    },
    Pools => {
        key => "spitStoragePoolName",
        table => "storagePoolInformationTable",
	spitUsedCapacity => "Capacity Usage percentage",
        spitIOPerSecond => "IOs/second",
	spitAvgLatencyUsecs => "Latency in microsecond",
	spitIOBandwidth => "IO bandwidth in Kbps",
    },
    Hypervisors => {
        table => "hypervisorinformationTable",
        key => "hypervisorName",
	hypervisorCpuUsagePercent => "CPU Usage percentage",
	hypervisorMemoryUsagePercent => "Memory Usage percentage",
	hypervisorReadIOPerSecond => "Read IOs/second",
	hypervisorWriteIOPerSecond => "Write IOs/second",
	hypervisorIOBandwidth => "IO bandwidth in Kbps",
	hypervisorRxBytes => "Total number of received bytes",
	hypervisorTxBytes => "Total number of transmitted bytes",
        hypervisorRxDropCount => "Total number of dropped received bytes",
        hypervisorTxDropCount => "Total number of dropped transmitted bytes"
    },
    VirtualMachines => {
        table => "vmInformationTable",
        key => "vmName",
	vmPowerState => "Power State",
	vmCpuUsagePercent => "CPU Usage percentage",
	vmMemoryUsagePercent => "Memory Usage percentage",
        vmReadIOPerSecond => "Read IOs/second",
        vmWriteIOPerSecond => "Write IOs/second",
        vmAverageLatency => "IO bandwidth in Kbps",
	vmRxBytes => "Total number of received bytes",
	vmTxBytes => "Total number of transmitted bytes",
	vmRxDropCount => "Total number of dropped received bytes",
	vmTxDropCount	=> "Total number of dropped transmitted bytes"
    },
    Controllers => {
        table => "controllerStatusTable",
        key => "cstControllerVMId",
	cstControllerVMStatus => "Status",
	cstDataServiceStatus => "Status of core data services",
	cstMetadataServiceStatus => "Status of metadata services",
    },
    Cluster => {
	clusterStatus => "Status",
        key => "clusterName",
	clusterUsedStorageCapacity => "Capacity Usage percentage",
	clusterIops => "Wide average IOs/second",
	clusterLatency => "Wide Latency in microseconds",
	clusterIOBandwidth => "Wide IO bandwidth in KBps"
    },
 );

our %UNITIES=(
    'Capacity|FreeBytes|FreeInodes|vmCpuUsagePercent|vmMemoryUsagePercent' => '%',
    'Bandwidth' => 'Kpbs',
    'IOPerSecond|Iops' => 'iops',
    'Latency' => 'microseconds',
    'xBytes' => 'B',
    'DropCount' => 'B'
);

our @ORDERED_SUBTYPES=('Capacity','FreeInodes','FreeBytes','Latency','Bandwidth','IO','CpuUsagePercent','MemoryUsagePercent','ReadIOPerSecond','WriteIOPerSecond','RxBytes','TxBytes','RxDropCount','RxDropCount');
our %DEFAULT_THRESHOLDS=
(
warning => {
    Capacity => 90,
    FreeInodes => 20,
    FreeBytes => 20,
    Latency => 200000,
    Bandwidth => 1000,
    IO => 2,
    CpuUsagePercent => 90,
    MemoryUsagePercent => 90,
    ReadIOPerSecond => 1000,
    WriteIOPerSecond => 1000,
    RxBytes => 100000,
    TxBytes => 100000,
    RxDropCount => 10,
    TxDropCount => 10
},
critical => {
    Capacity => 95,
    FreeInodes => 10,
    FreeBytes => 10,
    Latency => 400000,
    Bandwidth => 2000,
    IO => 10,
    CpuUsagePercent => 95,
    MemoryUsagePercent => 95,
    ReadIOPerSecond => 2000,
    WriteIOPerSecond => 2000,
    RxBytes => 200000,
    TxBytes => 200000,
    RxDropCount => 20,
    TxDropCount => 20,
}
);

my $STATE_OK=0;
my $STATE_WARNING=1;
my $STATE_CRITICAL=2;
my $STATE_UNKNOWN=3;

#-----------------------------------------------------
# Help function
#-----------------------------------------------------
sub Print_Help
{
         print <<HELP;
This plugin checks Nutanix via SNMP
HELP
&Print_Usage;
         print <<HELP;

	-H : host
	-C : SNMP V2c Community
        -a authProtocol -u secName -A authPassword -x privProtocol -X privPassword : SNMP V3 parameters
HELP
	print "\t-t : type. Can be : ".join(", ",keys %SUBTYPES).".\n";
	print "\t-s : subtypes of types above:\n";
        for my $t (keys %SUBTYPES)
         {
              print "\t=>".$t."\n";
              my %hash=%{$SUBTYPES{$t}};
              for my $key (keys %hash)
              {
                  print "\t\t".$key." : ".$hash{$key}."\n";
              }
         }
         print <<HELP;
	-T : timeout. Default is 15s.
        -n : pattern to filter elements to check
        -w : warning threshold(s). Format example :
            -w citUsedCapacity=80,citIOBandwidth=10
        -c : critical threshold(s). Format example :
            -w citUsedCapacity=80,citIOBandwidth=10
        -r <pattern> : regex pattern to filter items
        -e : use pattern above to exclude items
        -S : short output. Don't print details.

HELP

exit 1;
}

#-----------------------------------------------------
# Get user-given variables
#-----------------------------------------------------
my ($host, $authprotocol, $secname, $authpassword, $privprotocol, $privpassword, $type, $subtypes, $pattern, $exclude, $warning, $critical, $help, $debug, $short,  $timeout);
Getopt::Long::Configure ("bundling");
GetOptions (
'H=s' => \$host,
'a=s' => \$authprotocol,
'A=s' => \$authpassword,
'x=s' => \$privprotocol,
'X=s' => \$privpassword,
'u=s' => \$secname,
'T=s' => \$timeout,
't=s' => \$type,
's=s' => \$subtypes,
'd' => \$debug,
'S' => \$short,
'w=s' => \$warning,
'c=s' => \$critical,
'e' => \$exclude,
'r=s' => \$pattern,
'h' => \$help
);

$timeout="15" unless ($timeout);

&Print_Help if ($help);
&Print_Help unless ($host && $type);
&Print_Help unless ($authprotocol && $secname && $authpassword && $privprotocol && $privpassword);

my @subtype_array=grep {!/key|table/} keys %{$SUBTYPES{$type}};

if ($subtypes)
{
    @subtype_array=();
    for my $sub (split(/,/,$subtypes))
    {
        push @subtype_array, $sub if (${$SUBTYPES{$type}}{$sub});
    }
}

# Thresholds versus subtypes
my %thresholds;
$thresholds{'warning'}=$warning if ($warning);
$thresholds{'critical'}=$critical if ($critical);
my %warnings, my %criticals;
for my $subtype (@subtype_array)
{
    for my $th ('warning','critical')
    {
       if (($a)=($thresholds{$th} =~ /^(?:.*,)?$subtype=([^,]+)(?:,.*)?$/i) and $a =~/\d+/)
       {
           $thresholds{$subtype}{$th}=$a;
       }
       else
       {
           for my $j (@ORDERED_SUBTYPES)
           {
                $thresholds{$subtype}{$th}=$DEFAULT_THRESHOLDS{$th}{$j} and last if ($subtype =~ /$j/i);
           }
       }
    }
}
 
#-----------------------------------------------------
# SNMP request
#-----------------------------------------------------
my $command, my $output;
if ($SUBTYPES{$type}{'table'})
{
    $command="snmptable -v 3  -l authPriv -a $authprotocol -A $authpassword -u $secname -x $privprotocol -X $privpassword  -Cf ';' -m +NUTANIX-MIB $host $SUBTYPES{$type}{'table'} | grep '.*;.*'";
    $output=`$command`;
}
else
{
    # snmptable does not work or  thre is not table name. We build ourself a 'snmptable-like' output
    my @keys=("clusterName","clusterTotalStorageCapacity",grep {!/key/} keys %{$SUBTYPES{'Cluster'}});
    $output=join(";",@keys)."\n";
    my @values; 
    for my $key (@keys)
    {
         $command="snmpwalk -v 3 -l authPriv -a $authprotocol -A $authpassword -u $secname -x $privprotocol -X $privpassword -Oqv -m +NUTANIX-MIB $host $key";
         push @values, `$command`;
    }
    map{s/\n//} @values;
    $output.=join(";",@values)."\n";
} 

print $output if($debug);
print "No result." and exit $STATE_UNKNOWN if ($?!=0);

my @result_array=split(/\n/,$output);

# Array of object names 
my $l=shift @result_array;
chomp $l;
my @columns=split(/;/,$l);

# Index of type key found in column array
my ($key_index)=grep { $columns[$_] eq $SUBTYPES{$type}{'key'} } 0..$#columns;

# Build a hash of hash 'subtype => (key => value)'
my %results;
for my $line (@result_array)
{
    my @values=split(/;/,$line);
    my $i=0;
    while($i<=$#values)
    {
        $results{$columns[$i]}{$values[$key_index]}=$values[$i] unless ($columns[$i] eq $SUBTYPES{$type}{'key'});
        $i++;
    }
}

print Dumper %results if ($debug);

#-----------------------------------------------------
# Loop on selected subtypes
#-----------------------------------------------------
my $critstate=0;
my $warnstate=0;
my $i=0;
my @details;
my @failed;
my @perfs;
my @indexes;

for my $subtype (@subtype_array)
{
    for my $item (keys %{$results{$subtype}})
    {
        # Compare item with pattern
        if ($pattern)
        {
            if ($exclude)
            {
                next if ($item =~ /$pattern/);   
            }
            else
            {
                next unless ($item =~ /$pattern/);   
            }
        }        

        my $warning=$thresholds{$subtype}{'warning'};
        my $critical=$thresholds{$subtype}{'critical'};
        my $unity="";
        for my $p (keys %UNITIES)
        {
           $unity=$UNITIES{$p} and last if ($subtype =~ /$p/i);
        }
        my $limits=";0;100" if ($unity eq "%");

        # Boolean subtypes
        if ($subtype =~ /State|Status/)
        {
            my $state;
            my $result="'".$subtype." ".$item;
            if ($results{$subtype}{$item} !~ /on|Up|started/i)
            {
                $critstate=1;
                push @failed, $result."' is ".$results{$subtype}{$item};
                push @details, $result."' is ".$results{$subtype}{$item};
                $state=0;
            }
            else
            {
                push @details, $result."' is ".$results{$subtype}{$item};
                $state=1;
            }
	    push  @perfs, $result."'=".$state;
        }
        # Numerical subtypes 
        else 
        {
            my $value, my $comparator_nok=">", my $comparator_ok="<";

            #  For Capacity subtypes, the value is the calculated percentage of usage  
            if ($subtype =~ /Capacity/)
            {
                my ($prefix,$suffix)=($subtype=~/(.*)Used(.*Capacity)/);
                my $total=$prefix."Total".$suffix;
                $value=$results{$subtype}{$item}/$results{$total}{$item}*100;
            }
            #  For Free Bytes/Inodes subtypes, the value is the calculated percentage of free
            elsif ($subtype =~ /FreeBytes|FreeInodes/)
            {
                my ($prefix,$suffix)=($subtype=~/(.*)Free(.*)/);
                my $total=$prefix."Total".$suffix;
                next if ($results{$total}{$item} == 0);
                $value=$results{$subtype}{$item}/$results{$total}{$item}*100;
                $comparator_nok="<";
                $comparator_ok=">";
            }
            #  By default, the subtype value is the one returned by SNMP
            else
            {
                $value=$results{$subtype}{$item};
            }
             
            $value=sprintf("%.1f",$value);
            my $result="'".$subtype." ".$item."'=".$value.$unity;
            if (($value>$critical && $subtype !~ /FreeBytes|FreeInodes/) || ($value<$critical && $subtype =~ /FreeBytes|FreeInodes/))
            {
                $critstate=1;
                push @failed, $result."(".$comparator_nok.$critical.$unity.")";
                push @details, $result."(".$comparator_nok.$critical.$unity.")";
            }
            elsif (($value>$warning && $subtype !~ /FreeBytes|FreeInodes/) || ($value<$warning && $subtype =~ /FreeBytes|FreeInodes/))
            {
                $warnstate=1;
                push @failed, $result."(".$comparator_nok.$warning.$unity.")";
                push @details, $result."(".$comparator_nok.$warning.$unity.")";
            }
            else
            {
                push @details, $result."(".$comparator_ok."=".$warning.$unity.")";
            }
	    push  @perfs, $result.";".$warning.";".$critical.$limits;
        }
    } 
}
#
print "No result." and exit $STATE_UNKNOWN if ($#details<0);

###
# Output
###
my $code;
my $status;
if ($critstate==1)
{
    $code=$STATE_CRITICAL;
    $status=$type." CRITICAL";
}
elsif ($warnstate==1)
{
    $code=$STATE_WARNING;
    $status=$type." WARNING";
}
else
{
    $code=$STATE_OK;
    $status="All ".$type." OK";
}
if ($short)
{
   $status.= ", see details\n".join("\n",@failed) unless ($code==$STATE_OK);
}
else
{
    $status.=($code==$STATE_OK ? ", see details " : " : ".join(", ",@failed));
    $status.="\n".join("\n",@details);
}

print $status."|".join(" ",@perfs);
print "\n";
exit $code;
