#!/usr/bin/env bash
## /etc/icinga2/scripts/service-by-telegram.sh / 20170330
## Marianne M. Spiller <github@spiller.me>
## Last updated 20190820
## Last tests used icinga2-2.10.5-1.stretch 

PROG="`basename $0`"
HOSTNAME="`hostname`"
TRANSPORT="curl"
unset DEBUG

if [ -z "`which $TRANSPORT`" ] ; then
  echo "$TRANSPORT not in \$PATH. Consider installing it."
  exit 1
fi

Usage() {
cat << EOF

service-by-telegram notification script for Icinga 2 by spillerm <github@spiller.me>

The following are mandatory:
  -4 HOSTADDRESS (\$address$)
  -6 HOSTADDRESS6 (\$address6$)
  -d LONGDATETIME (\$icinga.long_date_time$)
  -e SERVICENAME (\$service.name$)
  -l HOSTALIAS (\$host.name$)
  -n HOSTDISPLAYNAME (\$host.display_name$)
  -o SERVICEOUTPUT (\$service.output$)
  -p TELEGRAM_BOT (\$telegram_bot$)
  -q TELEGRAM_CHATID (\$telegram_chatid$)
  -r TELEGRAM_BOTTOKEN (\$telegram_bottoken$)
  -s SERVICESTATE (\$service.state$)
  -t NOTIFICATIONTYPE (\$notification.type$)
  -u SERVICEDISPLAYNAME (\$service.display_name$) 

And these are optional:
  -b NOTIFICATIONAUTHORNAME (\$notification.author$)
  -c NOTIFICATIONCOMMENT (\$notification.comment$)
  -i HAS_ICINGAWEB2 (\$icingaweb2url$, Default: unset)
  -v (\$notification_logtosyslog$, Default: false)
  -D DEBUG enable debug output - meant for CLI debug only

EOF
exit 1;
}

while getopts 4:6:b:c:d:e:f:hi:l:n:o:p:q:r:s:t:u:v:D opt
do
  case "$opt" in
    4) HOSTADDRESS=$OPTARG ;;
    6) HOSTADDRESS6=$OPTARG ;;
    b) NOTIFICATIONAUTHORNAME=$OPTARG ;;
    c) NOTIFICATIONCOMMENT=$OPTARG ;;
    d) LONGDATETIME=$OPTARG ;;
    e) SERVICENAME=$OPTARG ;;
    h) Usage ;;
    i) HAS_ICINGAWEB2=$OPTARG ;;
    l) HOSTALIAS=$OPTARG ;;
    n) HOSTDISPLAYNAME=$OPTARG ;;
    o) SERVICEOUTPUT=$OPTARG ;;
    p) TELEGRAM_BOT=$OPTARG ;; 
    q) TELEGRAM_CHATID=$OPTARG ;;
    r) TELEGRAM_BOTTOKEN=$OPTARG ;;
    s) SERVICESTATE=$OPTARG ;;
    t) NOTIFICATIONTYPE=$OPTARG ;;
    u) SERVICEDISPLAYNAME=$OPTARG ;;
    v) VERBOSE=$OPTARG ;;
    D) DEBUG=1; echo -e "\n**********************************************\nWARNING: DEBUG MODE, DEACTIVATE ASAP\n**********************************************\n" ;;
   \?) echo "ERROR: Invalid option -$OPTARG" >&2
       Usage ;;
    :) echo "Missing option argument for -$OPTARG" >&2
       Usage ;;
    *) echo "Unimplemented option: -$OPTARG" >&2
       Usage ;;
  esac
done

## Build the message's subject
SUBJECT="[$NOTIFICATIONTYPE] $SERVICEDISPLAYNAME on $HOSTDISPLAYNAME is $SERVICESTATE!"

## Build the message itself
NOTIFICATION_MESSAGE=$(cat << EOF
[$SERVICESTATE] $SERVICEDISPLAYNAME is $SERVICESTATE since $LONGDATETIME
Host: $HOSTALIAS (IPv4 $HOSTADDRESS)
More info: $SERVICEOUTPUT
EOF
)

## Is this host IPv6 capable?
if [ -n "$HOSTADDRESS6" ] ; then
  NOTIFICATION_MESSAGE="$NOTIFICATION_MESSAGE
IPv6?    $HOSTADDRESS6"
fi

## Are there any comments? Put them into the message!
if [ -n "$NOTIFICATIONCOMMENT" ] ; then
  NOTIFICATION_MESSAGE="$NOTIFICATION_MESSAGE

Comment by $NOTIFICATIONAUTHORNAME:
  $NOTIFICATIONCOMMENT"
fi

## Are we using Icinga Web 2? Put the URL into the message!
if [ -n "$HAS_ICINGAWEB2" ] ; then
  NOTIFICATION_MESSAGE="$NOTIFICATION_MESSAGE
Get live status:
  $HAS_ICINGAWEB2/monitoring/host/show?host=$HOSTALIAS"
fi

## Are we verbose? Then put a message to syslog...
if [ "$VERBOSE" == "true" ] ; then
  logger "$PROG sends $SUBJECT => Telegram Channel $TELEGRAM_BOT"
fi

## debug output or not?
if [ -z $DEBUG ];then
    CURLARGS="--silent --output /dev/null"
else
    CURLARGS=-v
    set -x
    echo -e "DEBUG MODE!"
fi

## And finally, send the message
/usr/bin/curl $CURLARGS \
    --data-urlencode "chat_id=${TELEGRAM_CHATID}" \
    --data-urlencode "text=${NOTIFICATION_MESSAGE}" \
    --data-urlencode "parse_mode=HTML" \
    --data-urlencode "disable_web_page_preview=true" \
    "https://api.telegram.org/bot${TELEGRAM_BOTTOKEN}/sendMessage"
set +x
