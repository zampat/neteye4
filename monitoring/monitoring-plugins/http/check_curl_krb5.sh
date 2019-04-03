#!/bin/bash

# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# or version 3 of the License.
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
# (C) Würth Phoenix GmbH
# 3. April 2019: Patrick Zambelli <patrick.zambelli@wuerth-phoenix.com>
# Version 0.1.0


# Please change this
proxyport=3128
proxy='proxy.mydomain.lan'
user='my_kerberos_user'

# constants
TMPFILE=/tmp/check_curl_krb5$$.tmp

RET_CODE=3
RET_STRING="Unknown"

trap 'rm -f $TMPFILE' 0

# Scripts tries to get Kerberos Ticket to authenticate against server which requires negtiate Auth
function get_usage() {
   echo "Usage: check_curl_krb5.sh -u <url> -k <keytab_file> -s <search_string>"
   echo " "
   echo "Hint: This Plugins defines a proxy server and kerberos user as constant. Please change this inside the file!"
   echo " "
   echo "Hint: How to generate a keytab holding kerberos principal: "
   echo "# ktutil "
   echo "ktutil:  add_entry -password -p useraccount@domain -k 1 -e arcfour-hmac-md5 "
   echo "ktutil:  write_kt /root/kerberos/keytab_file"
   echo " "
}


if [ -z "$5" ]
then
   get_usage
   exit $RET_CODE
fi


if [ "$1" = "-u" ]
then
        shift
        URL=$1
        shift
fi

if [ "$1" = "-k" ]
then
        shift
        KEYTAB=$1
        shift
fi

if [ "$1" = "-s" ]
then
        shift
        SEARCH_STR=$1
        shift
fi


if [ -z $KEYTAB ]
then
   echo "please define a keytab file."
   get_usage
   exit $RET_CODE
fi

# variables
pwfile='./.netrc'

# get ticket
kinit $user -k -t $KEYTAB
RES=$?
if [ $RES -ne 0 ]
then
   echo "Error during kerberos ticket generation 'kinit'. Please test kinit manually."
   exit $RET_CODE
fi


# curl
#curl -s -o /tmp/nego_check_result --negotiate --netrc-file $pwfile $1 -k --proxy $proxy:$proxyport
curl -s -o $TMPFILE --negotiate --netrc $URL -k --proxy $proxy:$proxyport
RES=$?
if [ $RES -ne 0 ]
then
   echo "Non-OK CURL return code. Return code: $RES"
fi


# parse the outputfile for the expected String
if  grep -q $SEARCH_STR $TMPFILE 
then
        RET_STRING="HTTP OK: $SEARCH_STR was found in output file"
	RET_CODE=0
else
        RET_STRING="HTTP Critical: $SEARCH_STR was not found in output file "
        RET_STRING+=`grep \<title\> $TMPFILE`
	RET_CODE=2
fi

## Cleanup ##
# rm kerberos tickets
/usr/bin/kdestroy

echo $RET_STRING
exit $RET_CODE
