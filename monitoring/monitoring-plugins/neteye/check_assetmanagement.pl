#!/usr/bin/perl
# Check the OCS asset management for old assets and duplicate host items
#
# Use this plugin for your OCS assetmanagement server to check for items not beeing updated any more.
# Search also for duplicate items having the same name.
#
# Usage: check_assetmanagement.pl -C <age|duplicates> [-w <item age warning in days>] [-c <item age critical in days>] [-x \"<host1,host2,host3,..>\" ]
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
# Changes and Modifications
# =========================
# Feb 26, 2010: Patrick Zambelli <net.support@wuerth-phoenix.com>
# Version 1.0
# 1.1: Check for GLPI duplicates, Exit Ok when no data available in OCS
# 1.2: (20130207) Fix: GLPI duplicates are not shown correctly on "duplicates" check method
# 1.3: (20130225) Fix: If no GLPI duplicates found a warning was given
# 1.4: (20130718) Fix: Ocs outdated items: Perfdata output is written after the Aged-host details
# 2.0: (20140220) : GLPI Software Installations check on available Licenses
# 2.1: (20150403) : Duplicate Host check: introduce case insensitive regex 
# 2.2: (20180927) : assets_in_monitoring check if Assets in GLPI are under active monitoring (Monarch) 
# 2.2: (20181015) : Verify last run of a automatic action 
# 2.3: (20190131) : Filter for Entity ID for Duplicates in GLPI 
# 2.4: (20210427) : Check if duplicate or invalid operating systems are present

use DBI;
use POSIX;
use Getopt::Long;

################Vars#############
my %ERRORS=('OK'=>0,'WARNING'=>1,'CRITICAL'=>2,'UNKNOWN'=>3,'DEPENDENT'=>4);
my %dbOCSVars=('host'=>"mariadb.neteyelocal",'db'=>"ocsweb",'user'=>"ocsweb",'pass'=>"vz3X6wX2NV26IcYvALOwVNT66Eb0IQWX");
my %dbGLPIVars=('host'=>"mariadb.neteyelocal",'db'=>"glpi",'user'=>"icinga_monitoring",'pass'=>"GjCKVXRj0LyhhQuV");

$Version = "2.0";
$DEBUG=0;
my $var_return = 3;
my $str_resultOutput = "";
my $str_detailOutput = "";
    
    			      
##################MAIN############ 

check_options();

if ($DEBUG==1) { 
  print "Warning level: $o_warn Critical level: $o_crit \n"; 
}

if ($DEBUG==1){
  $i=0;
  while ($a_exclHosts[$i]){
    print "Exluding host: ".$a_exclHosts[$i]."\n";
    $i++;
  }
}

my ($d,$m,$y) = (localtime)[3..5];
my $systemDate = sprintf "%d%02d%02d", $y+1900,$m+1,$d;
$systemUnixTime = mktime(0,0,0,$d,$m,$y,0,0);

if ($o_command eq "age"){

  check_for_old_assets();
  
} elsif ($o_command eq "duplicates"){

  $var_return = $ERRORS{"OK"};
  check_for_hostname_duplicates();
  check_glpi_duplicate_hostNames();

} elsif ($o_command eq "ocs_duplicates"){

  $var_return = $ERRORS{"OK"};
  check_for_hostname_duplicates();

} elsif ($o_command eq "glpi_duplicates"){

  $var_return = $ERRORS{"OK"};
  check_glpi_duplicate_hostNames();

} elsif ($o_command eq "glpi_software"){

  $var_return = $ERRORS{"OK"};
  check_glpi_software_installations();

} elsif ($o_command eq "ocs_newsoft"){

  $var_return = $ERRORS{"OK"};
  check_ocs_new_software();

} elsif ($o_command eq "assets_in_monitoring"){

  $var_return = $ERRORS{"UNKNOWN"};
  print "Command not supported in NetEye 4. \n";

} elsif ($o_command eq "automatic_action_last_run"){
  $var_return = $ERRORS{"UNKNOWN"};
  check_automatic_action_last_run();
  
} elsif ($o_command eq "os_count"){
  $var_return = $ERRORS{"OK"};
  check_os_count();
  
} else {
  print "Undefined command name. Check usage of -C \n";
  print_usage();
}

if (length($str_detailOutput) > 1){

   print ($str_resultOutput."\n".$str_detailOutput);
} else {
   print ($str_resultOutput."\n");
}
exit($var_return);

############################################
sub check_ocs_new_software
############################################
{

   $var_return = $ERRORS{"OK"};
   
   $query = "SELECT COUNT(DISTINCT name) FROM softwares where name not in (select EXTRACTED from dico_ignored) and name not in (select EXTRACTED from dico_soft) and name <> ''";
    
   $dbh = DBI->connect("DBI:mysql:".$dbOCSVars{"db"}.":".$dbOCSVars{"host"},$dbOCSVars{"user"}, $dbOCSVars{"pass"});
   $sqlQuery  = $dbh->prepare($query)
      or die "Can't prepare $query: $dbh->errstr\n";
   
   $rv = $sqlQuery->execute
      or die "can't execute the query: $sqlQuery->errstr";
   
   $new_soft = $sqlQuery->fetchrow();
   
   if ($new_soft > 1 ){
      $str_resultOutput = "OCS: ".$new_soft." new software installed, please check. | ocs-new-software=".$new_soft.";;";
      $var_return = $ERRORS{"WARNING"};
   } else {
      $str_resultOutput = "OCS: All software managed | ocs-new-software=".$new_soft.";;";
   }
   $dbh->disconnect;
}

############################################
sub check_os_count
############################################
{

   $var_return = $ERRORS{"OK"};
   
   $query = "SELECT C.name FROM `glpi_items_operatingsystems` RO JOIN glpi_computers C ON C.id = RO.items_id WHERE RO.itemtype = 'Computer' AND RO.operatingsystems_id NOT IN (SELECT glpi_operatingsystems.id FROM glpi_operatingsystems) ORDER BY `RO`.`date_mod` DESC";
    
   $dbh = DBI->connect("DBI:mysql:".$dbGLPIVars{"db"}.":".$dbGLPIVars{"host"},$dbGLPIVars{"user"}, $dbGLPIVars{"pass"});
   $sqlQuery  = $dbh->prepare($query)
      or die "Can't prepare $query: $dbh->errstr\n";
   
   $rv = $sqlQuery->execute()
      or die "can't execute the query: $sqlQuery->errstr";
   
   #Loop trough all rows
   while(@row = $sqlQuery->fetchrow_array()){
     $str_detailOutput .= "Matching computer name: ".$row[0].".\n";
   }

   $sqlQuery->finish();

   $dbh->disconnect();

   
   if ( length($str_detailOutput) < 1){
      $str_resultOutput .= "OK: GLPI: No computer with duplicate or invalid operating system. | os_count=".$rows.";;";
   }else{
      $var_return = $ERRORS{"WARNING"};
      $str_resultOutput .= "WARNING: GLPI: ".($str_detailOutput =~ tr/\n//)." computers with duplicate or invalid operating system. | os_count=".($str_detailOutput =~ tr/\n//).";;";
   }
}

############################################
sub check_for_old_assets
############################################
{

$var_return = $ERRORS{"OK"};

$query = "SELECT ID, NAME, LASTDATE FROM `hardware` WHERE deviceid != '_SYSTEMGROUP_' and deviceid != '_DOWNLOADGROUP_' ORDER BY name";
 
$dbh = DBI->connect("DBI:mysql:".$dbOCSVars{"db"}.":".$dbOCSVars{"host"},$dbOCSVars{"user"}, $dbOCSVars{"pass"});
$sqlQuery  = $dbh->prepare($query)
or die "Can't prepare $query: $dbh->errstr\n";
 
$rv = $sqlQuery->execute
or die "can't execute the query: $sqlQuery->errstr";

$int_nonOk_itmes_counter = 0;

#Loop trough all rows
while (@row= $sqlQuery->fetchrow_array()) {

  #Date of ocs asset and pass regex
  @timestamp = split(/ /, $row[2]);
  $timestamp[0] =~ m!^(19|20)\d\d[- /.](0[1-9]|1[012])[- /.](0[1-9]|[12][0-9]|3[01])$!;

  if ($timestamp[0] == ""){
   print ("EXCEPTION at Asset '".$row[1]."' (ID: ".$row[0]."). No  last-update date set.\n");
   next;
  } 

  if (check_if_host_to_exclude($row[1], @a_exclHosts) == 1){ 
   next;
  }

  #The date: [YYYY][mm][dd]
  @date = split(/-/, $timestamp[0]);
  $ocsdate=$date[0].$date[1].$date[2];

  $ocsUnixTime = mktime(0,0,0,$date[2],$date[1]-1,$date[0]-1900,0,0);

  #Calculate the age
  my $diff = ($systemUnixTime - $ocsUnixTime)/3600/24;

  if ($DEBUG==1){
   print "Asset '".$row[1]."' (ID: ".$row[0].") has update ".$diff." days ago. (OCS: ".$ocsdate.")\n";
  }

  #Critical
  if ($diff > $o_crit){

     $str_detailOutput .= "Critical Asset '".$row[1]."': ".$diff." days old\n";
    if ($var_return != 2) { $var_return = $ERRORS{"CRITICAL"}; }
    $int_nonOk_itmes_counter++;
  
  #Warning
  } elsif ($diff > $o_warn){

    if ($var_return == 3 || $var_return == 0) { $var_return = $ERRORS{"WARNING"}; }
    $str_detailOutput .= "Warning Asset '".$row[1]."': ".$diff." days old\n";
    $int_nonOk_itmes_counter++;
  
  #OK
  } else {
  
    if ($var_return == 3 ) { $var_return = $ERRORS{"OK"}; }
  }
}
$dbh->disconnect;

#$str_detailOutput .= "| outdated-ocs-items=".$int_nonOk_itmes_counter.";".$o_warn.";".$o_crit.";0";
$str_resultOutput = "Number of outdated OCS assets found: ".$int_nonOk_itmes_counter." | outdated-ocs-items=".$int_nonOk_itmes_counter.";;";
 
$rc = $sqlQuery->finish;

}


############################################
sub check_for_hostname_duplicates
############################################
{


$query = "SELECT DISTINCT (name) FROM `hardware` WHERE deviceid != '_SYSTEMGROUP_' and deviceid != '_DOWNLOADGROUP_'";
 
$dbh = DBI->connect("DBI:mysql:".$dbOCSVars{"db"}.":".$dbOCSVars{"host"},$dbOCSVars{"user"}, $dbOCSVars{"pass"});
$sqlQuery  = $dbh->prepare($query)
or die "Can't prepare $query: $dbh->errstr\n";
 
$rv = $sqlQuery->execute
or die "can't execute the query: $sqlQuery->errstr";

#Loop trough all rows
while (@row= $sqlQuery->fetchrow_array()) {

  if (check_if_host_to_exclude($row[0], @a_exclHosts) == 1){ 
   next;
  }
  
  $query_count_hosts = "SELECT count(*) FROM `hardware` WHERE name = '".$row[0]."' and deviceid != '_SYSTEMGROUP_' and deviceid != '_DOWNLOADGROUP_'";
  $sqlQuery_count_hosts  = $dbh->prepare($query_count_hosts)
    or die "Can't prepare $query: $dbh->errstr\n";
 
  $rv_count = $sqlQuery_count_hosts->execute
    or die "can't execute the query: $sqlQuery->errstr";
  
  if (@row_count_hosts= $sqlQuery_count_hosts->fetchrow_array()) {
  
      if ($row_count_hosts[0] > 1 ){
        
        $str_detailOutput .= "OCS: The hostname ".$row[0]." has: ".$row_count_hosts[0]." duplicates.\n";
        $var_return = $ERRORS{"WARNING"};
      }
  }
  $rv_count = $sqlQuery_count_hosts->finish;
  
}
$rc = $sqlQuery->finish;
$dbh->disconnect;

if ( length($str_detailOutput) < 1){
  $str_resultOutput .= "OCS: No duplicates found.";
}else{
  $str_resultOutput .= "OCS: Duplicates had been found!";
}
}


############################################
sub check_glpi_duplicate_hostNames
############################################
{

if (defined ($o_ignoretrash) ) {
	$query = "select ID, name, serial, date_mod from glpi_computers WHERE is_deleted='0' and ( name in (SELECT name FROM `glpi_computers` WHERE is_deleted='0' GROUP BY name having ( count(name) > 1 ) ) ) ORDER BY name";

} elsif (defined ($o_glpiEntityID)){
	$query = "select ID, name, serial, date_mod from glpi_computers WHERE entities_id = '$o_glpiEntityID' and ( name in (SELECT name FROM `glpi_computers` WHERE entities_id = '$o_glpiEntityID' GROUP BY name having ( count(name) > 1 ) ) ) ORDER BY name";

} elsif (defined ($o_glpiEntityID) and defined(o_ignoretrash)){
	$query = "select ID, name, serial, date_mod from glpi_computers WHERE is_deleted='0' and entities_id = '$o_glpiEntityID' and ( name in (SELECT name FROM `glpi_computers` WHERE is_deleted='0' and entities_id = '$o_glpiEntityID' GROUP BY name having ( count(name) > 1 ) ) ) ORDER BY name";

} else {
	$query = "select ID, name, serial, date_mod from glpi_computers WHERE name in (SELECT name FROM `glpi_computers` GROUP BY name having ( count(name) > 1 ) ) ORDER BY name";
}
 
$dbh = DBI->connect("DBI:mysql:".$dbGLPIVars{"db"}.":".$dbGLPIVars{"host"},$dbGLPIVars{"user"}, $dbGLPIVars{"pass"});
$sqlQuery  = $dbh->prepare($query)
or die "Can't prepare $query: $dbh->errstr\n";
 
$rv = $sqlQuery->execute
or die "can't execute the query: $sqlQuery->errstr";

$int_duplicate_itmes_counter = 0;
$str_curr_duplicate_hostName = "";

#Loop trough all rows
while (@row= $sqlQuery->fetchrow_array()) {


  if (check_if_host_to_exclude($row[1], @a_exclHosts) == 1){
  	next;
  }


  # if we are fetching an ID of the next host name duplicate print now out the data and reset the previous host name
  if ((length($str_curr_duplicate_hostName) > 1) && ( $str_curr_duplicate_hostName ne $row[1] )){

	#output the previous data
	$str_detailOutput .= "GLPI: Name ".$str_curr_duplicate_hostName." Items: (".$tmpOutput.")<br/>";
	$tmpOutput = "";
	# Reset the last host name
	$str_curr_duplicate_hostName = "";


  }

  $tmpOutput .= "ID:".$row[0]." ";
  $str_curr_duplicate_hostName = $row[1];
  $int_duplicate_itmes_counter ++;
#print ("last host: ". $str_curr_duplicate_hostName. " IDS: ". $tmpOutput ); 
}

# After the loop empyt the last element into the output
if (length($str_curr_duplicate_hostName) > 1){
   $str_detailOutput .= "GLPI: Name ".$str_curr_duplicate_hostName." Items: (".$tmpOutput.")<br/>";
}


$rc = $sqlQuery->finish;
$dbh->disconnect;

  if ( length($str_detailOutput) < 1){

	$str_resultOutput .= "GLPI: No duplicates found.";
  } else {


if (defined ($o_ignoretrash) ) {
     $str_resultOutput .= " GLPI: Total duplicate items (no trash): ".$int_duplicate_itmes_counter;
} else {
     $str_resultOutput .= " GLPI: Total duplicate items: ".$int_duplicate_itmes_counter;
}
     $var_return = $ERRORS{"WARNING"}; 
     if (length($str_detailOutput) > 2000){

	$str_detailOutput .= substr $str_detailOutput,0,2000;
	$str_detailOutput .= "<br/>Other itmes...";
     }
  }
}

############################################
## Check for GLPI computers not beeing in monitoring (monarch)
#############################################
sub check_for_glpi_not_in_monitoring
{

$dbh = DBI->connect("DBI:mysql:".$dbOCSVars{"db"}.":".$dbOCSVars{"host"},$dbOCSVars{"user"}, $dbOCSVars{"pass"});

if ((defined $o_glpiStatus) && (defined $o_glpiTechGroup)){

   $query = 'SELECT glpicomp.name, glpicomp.id, glpicompstat.name, glpitechgroups.name
   FROM glpi.glpi_computers AS glpicomp
   LEFT JOIN glpi.glpi_states AS glpicompstat ON glpicomp.states_id = glpicompstat.id
   LEFT JOIN glpi.glpi_groups AS glpitechgroups ON glpitechgroups.id = glpicomp.groups_id_tech
   WHERE glpicomp.is_template = 0
   AND glpicomp.is_deleted = 0
   AND (glpicompstat.id = ? OR glpicompstat.states_id LIKE ?)
   AND (glpicomp.groups_id_tech = ?)
   AND glpicomp.name NOT
   IN (
      SELECT monhost.name
      FROM monarch.hosts AS monhost
      WHERE monhost.deleted =0
   )
   ORDER BY glpicomp.name;';

   $sqlQuery  = $dbh->prepare($query) or die "Can't prepare $query: $dbh->errstr\n";
   $sqlQuery->bind_param(1, $o_glpiStatus);
   $sqlQuery->bind_param(2, $o_glpiStatus);
   $sqlQuery->bind_param(3, $o_glpiTechGroup);

} elsif (defined $o_glpiTechGroup){

   $query = 'SELECT glpicomp.name, glpicomp.id, glpicompstat.name, glpitechgroups.name
   FROM glpi.glpi_computers AS glpicomp
   LEFT JOIN glpi.glpi_states AS glpicompstat ON glpicomp.states_id = glpicompstat.id
   LEFT JOIN glpi.glpi_groups AS glpitechgroups ON glpitechgroups.id = glpicomp.groups_id_tech
   WHERE glpicomp.is_template = 0
   AND glpicomp.is_deleted = 0
   AND (glpicomp.groups_id_tech = ?)
   AND glpicomp.name NOT
   IN (
      SELECT monhost.name
      FROM monarch.hosts AS monhost
      WHERE monhost.deleted =0
   )
   ORDER BY glpicomp.name;';

   $sqlQuery  = $dbh->prepare($query) or die "Can't prepare $query: $dbh->errstr\n";
   $sqlQuery->bind_param(1, $o_glpiTechGroup);

} elsif (defined $o_glpiStatus){

   $query = 'SELECT glpicomp.name, glpicomp.id, glpicompstat.name, glpitechgroups.name
   FROM glpi.glpi_computers AS glpicomp
   LEFT JOIN glpi.glpi_states AS glpicompstat ON glpicomp.states_id = glpicompstat.id
   LEFT JOIN glpi.glpi_groups AS glpitechgroups ON glpitechgroups.id = glpicomp.groups_id_tech
   WHERE glpicomp.is_template = 0
   AND glpicomp.is_deleted = 0
   AND (glpicompstat.id = ? OR glpicompstat.states_id LIKE ?)
   AND glpicomp.name NOT
   IN (
      SELECT monhost.name
      FROM monarch.hosts AS monhost
      WHERE monhost.deleted =0
   )
   ORDER BY glpicomp.name;';

   $sqlQuery  = $dbh->prepare($query) or die "Can't prepare $query: $dbh->errstr\n";
   $sqlQuery->bind_param(1, $o_glpiStatus);
   $sqlQuery->bind_param(2, $o_glpiStatus);

} else {
   $query = 'SELECT glpicomp.name, glpicomp.id, glpicompstat.name, glpitechgroups.name
   FROM glpi.glpi_computers AS glpicomp
   LEFT JOIN glpi.glpi_states AS glpicompstat ON glpicomp.states_id = glpicompstat.id
   LEFT JOIN glpi.glpi_groups AS glpitechgroups ON glpitechgroups.id = glpicomp.groups_id_tech
   WHERE glpicomp.is_template = 0
   AND glpicomp.is_deleted = 0
   AND glpicomp.name NOT
   IN (
      SELECT monhost.name
      FROM monarch.hosts AS monhost
      WHERE monhost.deleted =0
   )
   ORDER BY glpicomp.name;';

   $sqlQuery  = $dbh->prepare($query) or die "Can't prepare $query: $dbh->errstr\n";
}

$rv = $sqlQuery->execute
or die "can't execute the query: $sqlQuery->errstr";

$int_nonOk_itmes_counter = 0;

#Loop trough all rows
while (@row= $sqlQuery->fetchrow_array()) {

   if (check_if_host_to_exclude($row[0], @a_exclHosts) == 1){
        next;
   }

   $int_nonOk_itmes_counter++;
   $str_detailOutput .= "'".$row[0]."' (ID:".$row[1].") Status:'".$row[2]."' Tech.Group: '".$row[3]."'<br/>";
}

if ($int_nonOk_itmes_counter > 0){
  $var_return = $ERRORS{"WARNING"}; 
   $str_resultOutput .= "WARNING: There are $int_nonOk_itmes_counter hosts in AssetManagement not under active monitoring | hosts_not_in_monitoring=".$int_nonOk_itmes_counter.";;\n";
} else {

  $var_return = $ERRORS{"OK"}; 
   $str_resultOutput .= "OK: All hosts in AssetManagement are under active monitoring";
}

}


############################################
## Check for GLPI Automatic Action last run date / time
#############################################
sub check_automatic_action_last_run 
{

$dbh = DBI->connect("DBI:mysql:".$dbGLPIVars{"db"}.":".$dbGLPIVars{"host"},$dbGLPIVars{"user"}, $dbGLPIVars{"pass"});

# Get The latest cronlog message where a successful data synchronization had been done
#$query = 'SELECT name, frequency, lastrun, UNIX_TIMESTAMP(lastrun) AS lastrun_utc FROM glpi_crontasks WHERE name LIKE ?;';
$query = 'SELECT C.name, MAX(L.date) as lastrun, UNIX_TIMESTAMP(MAX(L.date)) as lastrun_utc
	FROM `glpi_crontasklogs` L
	JOIN glpi_crontasks C ON C.id = L.crontasks_id
	WHERE C.name LIKE ? AND L.content = "Action completed, fully processed";';

$sqlQuery  = $dbh->prepare($query) or die "Can't prepare $query: $dbh->errstr\n";
$sqlQuery->bind_param(1, $o_glpiCronName);

$rv = $sqlQuery->execute
or die "can't execute the query: $sqlQuery->errstr";

my $dateNow = time;
$str_resultOutput = "UNKNOWN: Now automatic Job matching.";

#Loop trough all rows
if (@row= $sqlQuery->fetchrow_array()) {

   $str_resultOutput .= "Job '".$row[0]."' last execution time:'".$row[2]."'<br/>";
   my $time_diff = $dateNow - $row[3];

   if ($time_diff > $o_warn){
	$var_return = $ERRORS{"WARNING"};	
	$str_resultOutput = "WARNING: The Automatic Action Job: '".$row[0]."' had been executed '".$time_diff."' Seconds ago. (Limit $o_warn) | last_execution=$time_diff;$o_warn;$o_warn ";
   }else{
	$var_return = $ERRORS{"OK"};	
	$str_resultOutput = "OK: The Automatic Action Job: '".$row[0]."' had been executed '".$time_diff."' Seconds ago. | last_execution=$time_diff;$o_warn;$o_warn ";
   } 
   $str_resultOutput .= " Last real import of asset data by automatic Job: '".$row[0]."' last execution: '".$row[1]."' ( '".$time_diff."' Seconds ago). | last_execution=$time_diff;$o_warn;$o_warn ";
   $str_detailOutput .= "\n Job '".$row[0]."' last execution time:'".$row[1]."'";
}

}

############################################
sub check_glpi_software_installations 
############################################
{
	$dbh = DBI->connect("DBI:mysql:".$dbGLPIVars{"db"}.":".$dbGLPIVars{"host"},$dbGLPIVars{"user"}, $dbGLPIVars{"pass"}) or die "UNKNOWN - Cannot connect to GLPI DB\n";
	# First check GLPI version < 0.84
	$query = "SHOW COLUMNS FROM glpi_computers_softwareversions";
	$sqlQuery  = $dbh->prepare($query) or die "UNKNOWN - Can't prepare $query: $dbh->errstr\n";
	$rv = $sqlQuery->execute or die "UNKNOWN - Can't execute the query: $sqlQuery->errstr";
	# Now set query for 0.83
	$query = "SELECT `glpi_softwares`.`id` AS id, `glpi_softwares`.`name` AS SW_NAME, `glpi_entities`.`completename` AS ITEM_1, COUNT(DISTINCT `glpi_computers_softwareversions_23af9de72785ae510f81f99055099b74`.`id`) AS Num_Install, FLOOR(SUM(`glpi_softwarelicenses`.`number`) * COUNT(DISTINCT `glpi_softwarelicenses`.`id`) / COUNT(`glpi_softwarelicenses`.`id`)) AS Num_Licenses, MIN(`glpi_softwarelicenses`.`number`) AS ITEM_6_2 FROM `glpi_softwares` LEFT JOIN `glpi_entities` ON (`glpi_softwares`.`entities_id` = `glpi_entities`.`id` ) LEFT JOIN `glpi_softwareversions` ON (`glpi_softwares`.`id` = `glpi_softwareversions`.`softwares_id` ) LEFT JOIN `glpi_computers_softwareversions` AS glpi_computers_softwareversions_23af9de72785ae510f81f99055099b74 ON (`glpi_softwareversions`.`id` = `glpi_computers_softwareversions_23af9de72785ae510f81f99055099b74`.`softwareversions_id` AND `glpi_computers_softwareversions_23af9de72785ae510f81f99055099b74`.`is_deleted` = '0' AND `glpi_computers_softwareversions_23af9de72785ae510f81f99055099b74`.`is_template` = '0' ) LEFT JOIN `glpi_softwarelicenses` ON (`glpi_softwares`.`id` = `glpi_softwarelicenses`.`softwares_id` ) WHERE `glpi_softwares`.`is_deleted` = '0' AND `glpi_softwares`.`is_template` = '0' GROUP BY `glpi_softwares`.`id` ORDER BY SW_NAME ASC";
	while (@row= $sqlQuery->fetchrow_array()) {
		if ($row[0] =~ /is_deleted_computer/) {
			# This is 0.84
			$query = "SELECT `glpi_softwares`.`id` AS id, `glpi_softwares`.`name` AS SW_NAME, `glpi_entities`.`completename` AS ITEM_1, COUNT(DISTINCT `glpi_computers_softwareversions_23af9de72785ae510f81f99055099b74`.`id`) AS Num_Install, FLOOR(SUM(`glpi_softwarelicenses`.`number`) * COUNT(DISTINCT `glpi_softwarelicenses`.`id`) / COUNT(`glpi_softwarelicenses`.`id`)) AS Num_Licenses, MIN(`glpi_softwarelicenses`.`number`) AS ITEM_6_2 FROM `glpi_softwares` LEFT JOIN `glpi_entities` ON (`glpi_softwares`.`entities_id` = `glpi_entities`.`id` ) LEFT JOIN `glpi_softwareversions` ON (`glpi_softwares`.`id` = `glpi_softwareversions`.`softwares_id` ) LEFT JOIN `glpi_computers_softwareversions` AS glpi_computers_softwareversions_23af9de72785ae510f81f99055099b74 ON (`glpi_softwareversions`.`id` = `glpi_computers_softwareversions_23af9de72785ae510f81f99055099b74`.`softwareversions_id` AND `glpi_computers_softwareversions_23af9de72785ae510f81f99055099b74`.`is_deleted_computer` = '0' AND `glpi_computers_softwareversions_23af9de72785ae510f81f99055099b74`.`is_template_computer` = '0' ) LEFT JOIN `glpi_softwarelicenses` ON (`glpi_softwares`.`id` = `glpi_softwarelicenses`.`softwares_id` ) WHERE `glpi_softwares`.`is_deleted` = '0' AND `glpi_softwares`.`is_template` = '0' GROUP BY `glpi_softwares`.`id` ORDER BY SW_NAME ASC";
			break;
		}
	}

	$sqlQuery  = $dbh->prepare($query) or die "UNKNOWN - Can't prepare $query: $dbh->errstr\n";
	$rv = $sqlQuery->execute or die "UNKNOWN - Can't execute the query: $sqlQuery->errstr";

	$int_NumSW_exceeding_licenses_counter = 0;
	#print ($str_resultOutput.$str_detailOutput."\n");


	#Loop trough all rows
	while (@row= $sqlQuery->fetchrow_array()) {
	  if ($DEBUG==1) {
		print "Name: ".$row[1]." Entitiy ".$row[2]." Install No: ".$row[3]."  License No: ".$row[4]."\n";
	  }

	  if (check_if_host_to_exclude($row[1], @a_exclHosts) == 1){
		if ($DEBUG==1) { 
		   print "Skip software due to exclude: ".$row[1]."\n";
		}
	        next;
	  }

	  # Aggregate SW Name and Entity Description  
	  if ($row[2] =~ /\S/){
		$sw_name = $row[1]." (Entity: ".$row[2].")";
	  } else {
		$sw_name = $row[1];
	  }

	  #Cast number of installations && Cast number of licenses
	  if (($row[3] =~ /\d/) && ($row[4] =~ /\d/)){
	
		# Test number of Installation and avail Licenses
		if ($row[3] > $row[4]){
		   $str_detailOutput .= "SW \"".$sw_name."\" Installed: ".$row[3]." Licenses: ".$row[4]."\n";
		   $var_return = $ERRORS{"WARNING"};
		   $int_NumSW_exceeding_licenses_counter++;
		}
	  }

	  if ($int_NumSW_exceeding_licenses_counter > 0){
		$str_resultOutput = "WARNING: There are $int_NumSW_exceeding_licenses_counter Software Packages with a higher number of installations than Licenses";
	  } else {
		$str_resultOutput = "OK: The installed Software Packages respect the available Licenses";
	  }
	  $str_resultOutput .= "| exceeding_softwares=$int_NumSW_exceeding_licenses_counter;1;1;;";
	}
	$dbh->disconnect;
}

############################################
sub check_options
############################################
{
Getopt::Long::Configure ("bundling");
GetOptions(
'w:s'	=> \$o_warn,		'warning:s'	=> \$o_warn,
'c:s'	=> \$o_crit,		'critical:s'	=> \$o_crit,
'C:s'	=> \$o_command,		'command:s'	=> \$o_command,
'h'     => \$o_help,    	'help'        	=> \$o_help,
'v'	=> \$o_verb,		'verbous'	=> \$o_verb,
'I'	=> \$o_ignoretrash,	'ignoretrash'	=> \$o_ignoretrash,
'x:s'   => \$o_exclHosts,       'exlude:s'        =>\$o_exclHosts,
'e:s'   => \$o_glpiEntityID,      'glpi_entityid:s'        =>\$o_glpiEntityID,
's:s'   => \$o_glpiStatus,      'glpi_status:s'        =>\$o_glpiStatus,
't:s'   => \$o_glpiTechGroup,   'glpi_tech_group:s'        =>\$o_glpiTechGroup,
'a:s'   => \$o_glpiCronName,    'glpi_automatic_action_name:s'        =>\$o_glpiCronName,

);
if (defined ($o_help) ) { help(); exit $ERRORS{"UNKNOWN"}};
if ( ! defined($o_command)) # check input 
 	{ print_usage(); exit $ERRORS{"UNKNOWN"}}
if ( ! defined($o_warn)) { $o_warn =10; }
if ( ! defined($o_crit)) { $o_crit =20; }
if (defined ($o_verb) )   {
  $DEBUG=1; 
  print "Verbouse mode on !\n";
  #Log::Log4perl->easy_init( { level   => $DEBUG,
  #file    => ">>/tmp/check_assetmanagement.log" } );
  }
  if (defined($o_exclHosts)){
    if ($o_exclHosts =~ m/,/) {
      
      @a_exclHosts = split(/,/, $o_exclHosts);
    } else {
      
      $a_exclHosts[0]=$o_exclHosts;
    }

    
  }
}

############################################
#Exclude logic
sub check_if_host_to_exclude
############################################
{
  my($curr_host, @a_exclHosts) = @_;
  
  $found=0;
  foreach $host (@a_exclHosts) {
    $curr_host =~ s/^\s+//;
    $curr_host =~ s/\s+$//;

    if ($curr_host =~ /$host/i){
      #print "Machted: $curr_host =~ $host \n";
      $found=1;
    }
    #print "matching ".$host."<>".$curr_host."\n";

    #if (lc($curr_host) eq lc($host)) {
    #  $found=1;
    #}
  }
  #if ($found==1) { 
  #  next;
  #}
  return $found;
}


############################################
sub print_usage
############################################
{
    print "Usage: $0 -C <command> [-I] [-w <item age warning in days>] [-c <item age critical in days>] [-x \"<host1,host2,host3,..>\" ]\n";
    print "-command: age|duplicates|ocs_duplicates|ocs_newsoft|glpi_duplicates|glpi_software\n";
    print "\n";
    print "Run plugin with --help for more info\n";
}
############################################
sub help
############################################
{
print "\nCheck OCS for hardware asset not beeing updated for a while.\nCheck also for duplicate items in the asset management.\n";
print "Version: ".$Version."\n\n";

print_usage();
print <<EOT;

-h, --help
print this help message
-C, --command
specify the kind of check to perform on the OCS assetmanagement 
  - age:            check for old not up-to-date assets 
  - duplicates      check in OCS and GLPI for duplicate assests having the same host name
  - ocs_duplicates  check in OCS for duplicate assests having the same host name 
  - ocs_newsoft     check in OCS for software in category NEW 
  - glpi_duplicates check in GLPI for duplicate assests having the same host name  
  Each Duplicate check will lead to a WARNING if a duplicate is found
  - automatic_action_last_run check regular execution of automatic action: verify last run
  - os_count check count of computers with relation to a non existing operating system

-w <int> --warning <int> 
specify the number of days an asset item has not to be updated before returning a warning.
Default: 10
-c <int> --critical <int> 
specify the number of days an asset item has not to be updated before returning a critical
Default: 20
-x "host1,host2,neteye_.*,..."
    exlude those host name from the check results
    Expression is taken as case insensitive Perl Regular Expression

-I Ignore items marked as deleted

-e GLPI Entity ID (only for -C duplications )
-s GLPI STATUS ID (only for -C assets_in_monitoring )
-t GLPI Tech. Groups ID (only for -C assets_in_monitoring )
-a GLPI automatic action name to verify (only for -C automatic_action_last_run)
-v, --verbose
verbouse execution mode

Example Usage:
$0 -C age -x \"host1,host2,host3,..\" -w 30 -c 60
$0 -C duplicates -x \"host1,host2,host3,..\"
$0 -C automatic_action_last_run -a DataInjection -w 86400
   OK: The Automatic Action Job: 'DataInjection' had been executed '2421' Seconds ago. | last_execution=2421;86400;86400

EOT
}
