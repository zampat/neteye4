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
# 12. April 2021: Patrick Zambelli <patrick.zambelli@wuerth-phoenix.com>
# Version 0.2.0


# Defaults 
PROXY='proxy.mydomain'
proxyport=3128

user='username'
TMPFILE=/tmp/check_curl_krb5$$.tmp

# variwable not used: 
# parameter --netrc-file not compatible with curl of CentOS6
#pwfile='./.netrc'


RET_CODE=3
RET_STRING="Unknown"

#trap 'rm -f $TMPFILE' 0

# Scripts tries to get Kerberos Ticket to authenticate against server which requires negtiate Auth
function get_usage() {
   echo "Usage: check_curl_krb5.sh -u <url> -k <keytab_file> -s <search_string>"
   echo " "
   echo " -u the url to open"
   echo " -p the proxy url or 'noproxy' to disable"
   echo " -k keytab file"
   echo " -s search string"
   echo " "
   echo "Hint: How to generate a keytab holding kerberos principal: "
   echo "# ktutil "
   echo "ktutil:  add_entry -password -p useraccount@domain -k 1 -e arcfour-hmac-md5 "
   echo "ktutil:  write_kt /root/kerberos/keytab_file"
   echo " "
}

# Parsing of parameters
if [ -z "$5" ]
then
   get_usage
   exit $RET_CODE
fi

while [ $# -gt 0 ]; do
    case $1 in
        -h|--help)
            print_help
            exit 0
            ;;
        -V|--version)
            print_version
            exit 0
            ;;
        -u)
            URL=$2
            shift 2
            ;;
        -k)
            KEYTAB=$2
            shift 2
            ;;
        -s)
            SEARCH_STR=$2
            shift 2
            ;;
        -p)
            PROXY=$2
            shift 2
            ;;
        *)
            echo "Internal Error: option processing error: $1" 1>&2
            exit $STATE_UNKNOWN
            ;;
    esac
done

#Validations
if [ -z $KEYTAB ]
then
   echo "please define a keytab file."
   get_usage
   exit $RET_CODE
fi

# get ticket
kinit $user -k -t $KEYTAB
RES=$?
if [ $RES -ne 0 ]
then
   echo "Error during kerberos ticket generation 'kinit'. Please test kinit manually."
   exit $RET_CODE
fi


# curl run 
if [ $PROXY == "noproxy" ]
then
   #curl -s -o /tmp/nego_check_result --negotiate --netrc-file $pwfile $1 -k --proxy $PROXY:$proxyport
   curl -s -o $TMPFILE --negotiate --netrc $URL -k
   RES=$?
   if [ $RES -ne 0 ]
   then
      echo "Non-OK CURL return code. Return code: $RES"
   fi
elif [ ! -z $PROXY ]
then

   curl -s -o $TMPFILE --negotiate --netrc $URL -k --proxy $PROXY:$proxyport
   RES=$?
   if [ $RES -ne 0 ]
   then
      echo "Non-OK CURL return code. Return code: $RES"
   fi
else
   echo "Proxy not defined. No check executed. Return code: $RES"
fi

#`cat $TMPFILE`
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
