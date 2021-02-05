#! /bin/sh
#

TMPFILE=$(mktemp)
trap 'rm -f $TMPFILE; exit 1' 1 2 15
trap 'rm -f $TMPFILE' 0

cat >$TMPFILE
if grep 'Content-Transfer-Encoding.*base64' $TMPFILE >/dev/null
then
        cat $TMPFILE | /usr/bin/socat - /var/run/eventhandler/rw/email.socket
elif grep 'Encoding.*quoted-printable' $TMPFILE >/dev/null
then
        cat $TMPFILE | perl -pe 'use MIME::QuotedPrint; $_=MIME::QuotedPrint::decode($_);' | /usr/bin/socat - /var/run/eventhandler/rw/email.socket
else
        cat $TMPFILE | /usr/bin/socat - /var/run/eventhandler/rw/email.socket
fi
