#! /bin/sh
#

# NetEye 3 tool to disover NagVis maps where a host is contained
# Discovery works for Hostname and related Host Groups in NagVis
# This script presents a html table with a reference to the related NagVis Maps 
# This script presents a html table with a reference to the related Nagios Hostgroups 
#
# Author: Patrick Zambelli <patrick.zambelli@wuerth-phoenix.com>
# Copyright: 2019, Wuerth Phoenix GmbH
# License: GPLv3 

TMPFILE_hosts=/tmp/map_hosts$$.txt
TMPFILE_hostgroups=/tmp/maps_hostgroups_$$.txt
TMPFILE_maps_found=/tmp/maps_found_$$.txt
NAGVIS_MAPS_DIR=/var/lib/neteye/plugins/nagvis/etc/maps
MONITORING_LIVESTATUS_SOCKET_FILE=/var/log/nagios/rw/live

trap 'rm -f $TMPFILE_hosts $TMPFILE_hostgroups $TMPFILE_maps_found; exit 1' 1 2 15
trap 'rm -f $TMPFILE_hosts $TMPFILE_hostgroups $TMPFILE_maps_found' 0

#--------------------------------------------------------------------------

function print_html_init {
        if [ "$format" = "text" ]
        then
                enc="text/ascii"
        elif [ "$format" = "csv" ]
        then
                enc="text/csv"
        fi

        cat <<EOM
Cache-Control: no-store
Pragma: no-cache
Last-Modified: Wed, 24 Nov 2010 14:31:49 CET
Expires: Thu, 01 Jan 1970 00:00:00 GMT
Content-type: $enc

EOM
}

function print_html_header {
        cat <<EOM
<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN" "http://www.w3.org/TR/html4/loose.dtd">
<html>
<head>
<title>NetEye NagVis link</title>
<meta http-equiv="Content-Type" content="text/html; charset=utf-8">
<meta name="author" content="Juergen Vigna">
<meta name="language" content="en">

<style>

body {
   font-family: "Helvetica Neue",Helvetica,Arial,sans-serif;
   font-size: 14px;
   line-height: 1.42857143;
}
h1, .h1 {
   font-size: 36px;
   margin-top: 20px;
   margin-bottom: 10px;
   font-weight: 500;
}

table.monitoring2maps {
  font-family: "Lucida Sans Unicode", "Lucida Grande", sans-serif;
  border: 1px solid #120CA4;
  background-color: #EEEEEE;
  width: 80%;
  text-align: left;
  border-collapse: collapse;
}
table.monitoring2maps td, table.monitoring2maps th {
  border: 1px solid #AAAAAA;
  padding: 7px 5px;
}
table.monitoring2maps tbody td {
  font-size: 16px;
  color: #00004A;
}
table.monitoring2maps tr:nth-child(even) {
  background: #D0E4F5;
}
table.monitoring2maps thead {
  background: #1C6EA4;
  background: -moz-linear-gradient(top, #5592bb 0%, #327cad 66%, #1C6EA4 100%);
  background: -webkit-linear-gradient(top, #5592bb 0%, #327cad 66%, #1C6EA4 100%);
  background: linear-gradient(to bottom, #5592bb 0%, #327cad 66%, #1C6EA4 100%);
  border-bottom: 2px solid #444444;
}
table.monitoring2maps thead th {
  font-size: 17px;
  font-weight: bold;
  color: #FFFFFF;
  border-left: 2px solid #D0E4F5;
}
table.monitoring2maps thead th:first-child {
  border-left: none;
}

table.monitoring2maps tfoot {
  font-size: 14px;
  font-weight: bold;
  color: #FFFFFF;
  background: #D0E4F5;
  background: -moz-linear-gradient(top, #dcebf7 0%, #d4e6f6 66%, #D0E4F5 100%);
  background: -webkit-linear-gradient(top, #dcebf7 0%, #d4e6f6 66%, #D0E4F5 100%);
  background: linear-gradient(to bottom, #dcebf7 0%, #d4e6f6 66%, #D0E4F5 100%);
  border-top: 2px solid #444444;
}
table.monitoring2maps td {
  font-size: 14px;
}
table.monitoring2maps .col_normal {
  width: 80px;
}
table.monitoring2maps .col_wide {
  width: 70%;
}
table.monitoring2maps .links {
  text-align: right;
}
table.monitoring2maps .links a{
  display: inline-block;
  background: #1C6EA4;
  color: #FFFFFF;
  padding: 2px 8px;
  border-radius: 5px;
}

</style>
</head>
<body bgcolor="#FFFFFF" topmargin="10" leftmargin="10" rightmargin="10" bottommargin="10" marginheight="10" marginwidth="10">
EOM
}

function print_html_footer {
        echo "</body>"
        echo "</html>"
}

function print_html_form {
        if [ -z "$shost" ]
        then
                shostout=ALL
        else
                shostout=`php -r "echo urldecode('$shost');"`
        fi

        html_hostgroups_list=""



        # Searching for mapgs where host is registered directly
        grep -ri "$shostout" ${NAGVIS_MAPS_DIR} > $TMPFILE_hosts

        for hostname in `cat $TMPFILE_hosts`;
        do
           #echo "Searching host_name: $hostname</br>"
           echo $hostname >> $TMPFILE_maps_found
        done

        # Searching for mapgs where host is regestered indirectly via its hostgroup
        echo -e "GET hosts\nFilter: name = $shostout\nColumns: groups\n" | unixcat ${MONITORING_LIVESTATUS_SOCKET_FILE} > $TMPFILE_hostgroups

        Field_Separator=$IFS
        # set comma as internal field separator for the string list
        IFS=,
        for host_group in `cat $TMPFILE_hostgroups`;
        do
           grep -E -ri ${host_group}$ $NAGVIS_MAPS_DIR >> $TMPFILE_maps_found
           html_hostgroups_list="${html_hostgroups_list} <tr><td>$host_group</td><td><div class='links'><a class='active' href='/thruk/cgi-bin/status.cgi?nav=&hidesearch=0&hidetop=&style=hostoverview&update.x=11&update.y=8&dfl_s0_type=hostgroup&dfl_s0_op=%3D&dfl_s0_value=$host_group'> $host_group </a></div></td></tr>"
        done
        IFS=$Field_Separator


        LINES=`cat $TMPFILE_maps_found | wc -l`
        #echo "lines count $LINES"
	
	# Start of HTML
	echo '<div class="container">'
        echo "<h1>Overview of monitoring maps related to hosts \"$shostout\"</h1>"

	echo '<table class="monitoring2maps">'
        echo "<thead><tr><th>Map name</th><th>Map link</th><th>Map preview</th></tr></thead>"

        if [ $LINES -le 0 ]
        then
           echo "<tr><td colspan='3'><h2> The host $shostout is not associated within any monitoring map </h2></td></tr>"

        else
           for map_name in `cat $TMPFILE_maps_found | grep -v .cfg.bak | sort | cut -d : -f 1 | uniq | cut -d . -f 1 | uniq`
           do
              nagvis_map_name=$(basename "$map_name")
	      nagvis_map_url="/nagvis/frontend/nagvis-js/index.php?mod=Map&act=view&show=$nagvis_map_name"

              echo "<tr><td class='col_normal'>Map Name: $nagvis_map_name </td>"
              echo "<td class='col_normal'><div class='links'><a class='active' href='$nagvis_map_url'> $nagvis_map_name </a></div></td>"
	      echo "<td class='col_wide'><iframe src='${nagvis_map_url}' style='border:0px #ffffff dotted;' name='monitoring2maps' scrolling='yes' frameborder='1' marginheight='0px' marginwidth='0px' height='300px' width='100%' allowfullscreen></iframe></td>"
              echo "</tr>"
           done
        fi
	echo '</table>'

	echo '<br/>'
	echo '<h2>Details list of Hostgroups related to Host:</h2>'

	echo '<table class="monitoring2maps">'
        echo "<thead><tr><th>Host Group</th><th>Hostgroup link</th></tr></thead>"
        if [ -z "$html_hostgroups_list" ]
        then
           echo "<tr><td colspan='2'><h4> The host $shostout is not associated to any hostgroup </h4></td></tr>"
        else
	   
           echo "${html_hostgroups_list}"
        fi
        echo "</table>"
	echo '<br/><br/>'


}

#--------------------------------------------------------------------------

VARS=`echo $REQUEST_URI | cut -d\? -f2 | sed -e 's/&/;/g'`
#echo "VARS: $VARS" >/tmp/abc

eval $VARS

if [ "$shost" = "ALL" ]
then
        shost=""
else
        shost=`php -r "echo urldecode('$shost');"`
fi


print_html_init
print_html_header
print_html_form
print_html_footer
