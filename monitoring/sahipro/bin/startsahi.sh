#! /bin/sh
#
DIR=$(dirname $0)

cd $DIR
rm -f ../database/db0*.db
./start_sahi.sh
