#!/bin/sh
#
TMPFILE=/var/tmp/phantomjs_$$.cmd
trap 'rm -f $TMPFILE; exit 1' 1 2 15
trap 'rm -f $TMPFILE' 0

echo "rm -f $TMPFILE" >$TMPFILE
if [ -x /usr/bin/phantomjs2 ]
then
	echo -n "/usr/bin/waitmax 900 /usr/bin/phantomjs2" >>$TMPFILE
else
	echo -n "/usr/bin/waitmax 900 /usr/bin/phantomjs" >>$TMPFILE
fi
n=0
for i in $@
do
	if [ -z "$sahisid" ]
	then
		sahisid=$(echo "$i" | sed -e 's/.*sahisid=\(.*\)sahi.*/\1/g')
	fi
	if [ "$sahisid" = "$i" ]
	then
		sahisid=""
	fi
	if [ -n "$sahisid" ]
	then
		TMPDIR=/neteye/shared/httpd/sahipro/tmp/$sahisid
		echo -n " \"$TMPDIR\" \"$i\"" >>$TMPFILE
	else
		echo -n " \"$i\"" >>$TMPFILE
	fi
done

if [ -n "$TMPDIR" ]
then
	mkdir -p $TMPDIR
	chmod g+rwx $TMPDIR
fi

if [ ! -d "$TMPDIR" ]
then
	echo "TMPDIR ($TMPDIR) not found: $0 $@" >>/neteye/shared/httpd/sahipro/sahipro_phantomjs.log
fi

sh $TMPFILE
