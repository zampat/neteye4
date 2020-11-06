#[root@neteye ~]# cat  /data/neteye/etc/nagios/neteye/sms/phonesend.sh
#! /bin/sh
#
export PATH=.:$PATH
#logfile=/var/log/phone-send-protocol.log
logfile=/neteye/local/smsd/log/phone-send-protocol.log
tmpfile=/tmp/phonesend_email_tmp$$.txt
queuefile=/var/tmp/.phonequeue_$USER.txt
number=""
POPTS=""
trap 'rm -f $tmpfile; exit 1' 1 2 15
trap 'rm -f $tmpfile' 0
#sudo /etc/nagios/neteye/sms/fix-protocol-file.sh $logfile
function showhelp() {
    echo -e '\nphonesend.sh - Make a phonecall through the smstools daemon.\n\nUsage: phonesend.sh <file|number>\n\n<file>: containing the list of recipients, one per line, in the international phone format (+XXxxxxxxx). #comments are ignored\n<number>: one phonenumber in the international phone format (+XXxxxxxxx)'
}
function getqueue() {
    if [ -n "$QUEUES" ]
    then
        n=$(echo "$QUEUES" | tr -C -d ',' | wc -c)
        NQUEUE=$(expr $n + 1)
        if [ -e $queuefile ]
        then
            AQUEUE=$(cat $queuefile | tr -C -d "0123456789")
            if [ -z "$AQUEUE" ]
            then
                AQUEUE=0
            fi
        else
            AQUEUE=0
        fi
        AQUEUE=$(expr $AQUEUE + 1)
        if [ $AQUEUE -gt $NQUEUE ]
        then
            AQUEUE=1
        fi
        QSTR=$(echo "$QUEUES" | cut -d, -f$AQUEUE)
        POPTS="-q $QSTR"
        echo -n "$AQUEUE" >$queuefile
    fi
}
function getphonenumber() {
    if [[ "$1" =~ ^\+[0-9]+$ ]]
    then
        number="$1"
    elif [[ "$1" =~ ^[0-9]+$ ]]
    then
        number="$1"
    elif [ -f "$PHONEBOOK" ]
    then
        if grep "$1" $PHONEBOOK | grep '+'
        then
            number=`grep "$1" $PHONEBOOK | head -1 | cut -d+ -f2`
        fi
    fi
    if [ -z "$number" ]
    then
        number="$1"
    fi
}
function single_sendphone() {
    getphonenumber $1
    if [ -z "$DEBUG" ]
    then
        getqueue
        echo "`date`:$number" >>$logfile
        ff=$(mktemp -p $OUTGOINGDIR phone.XXXXXXXXXX)
        echo -e "To: $number\nVoicecall: yes\n\nTONE: $PHONE_TONE" >$ff
    else
        echo "`date`:$number:$text"
    fi
}
function file_sendphone() {
    file=$1
    while read -r number comment
    do
        single_sendphone "$number"
    done <  $file
}
if [ "$1" = "-D" ]
then
    echo "ACTIVATING DEBUG MODE"
    DEBUG=1
    shift
fi
if [ $# -lt 1 ]
then
    showhelp
    exit 0
fi
rdir=`dirname $0`
if [ ! -f "$rdir/smsd.conf" ]
then
    rdir=/neteye/local/smsd/conf
fi
if [ ! -f "$rdir/smsd.conf" ]
then
    echo "ERROR: cannot find sms.cfg inside dir($rdir)" >>$logfile
    echo "ERROR: cannot find sms.cfg inside dir($rdir)" | mail -s "ERROR in smssend" root
    exit 0
fi
cd $rdir
#. ./smsd.conf
if [ -z "$PHONEBOOK" ]
then
    PHONEBOOK="$rdir/phonebook/phone"
fi
if [ -z "$OUTGOINGDIR" ]
then
    OUTGOINGDIR=/neteye/local/smsd/data/spool/outgoing
fi
#
# If special phonebook exists send to all recipients in that phonebook
#
param=`echo $1 | sed -e 's/+//g'`
if [ -f "${PHONEBOOK}_$param" ]
then
    file="${PHONEBOOK}_$param"
    file_sendphone "$file"
else
    single_sendphone "$param"
fi
