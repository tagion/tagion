#!/usr/bin/env bash
# $1 : Screen name
#
echo $*
case $1 in
start)
	export STARTED=`screen -ls | grep $REPORTER_NAME`
	if [ -z "$STARTED" ]; then
		cd $REPORT_ROOT
		pwd
		screen -S $REPORTER_NAME -dm $REPORT_VIEWER &
	else
	#	echo "
	echo "Started" $STARTED
	fi;;
stop)
	screen -X -S $REPORTER_NAME quit;;
list)
	screen -ls | grep $REPORTER_NAME;;
*)
  echo "$1 false argument";;
esac




