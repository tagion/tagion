#!/usr/bin/env bash
# echo "run master node"
#export TAGIONWAVE = /home/carsten/work/tagion/build/x86_64-linux/bin/tagionwave
#gnome-terminal -- ./tagionwave --port 4020 -p 10810 -P 10910 --dart-synchronize=false --dart-init=false  --dart-filename=./dart.drt
echo TAGIONWAVE=$TAGIONWAVE
echo MODE1_CONFIG=$MODE1_CONFIG
echo MODE1_FALGS=$MODE1_FALGS
echo HOSTPORT=$HOSTPORT
echo TRANSACTIONPORT=$TRANSACTIONPORT
echo MONITORPORT=$MONITORPORT
echo DARTFILE=$DARTFILE
echo DARTSYNC=$DARTSYNC
exit
gnome-terminal -- $TAGIONWAVE --port 4020 -p 10810 -P 10910 --dart-synchronize=false --dart-init=false  --dart-filename=./dart.drt
for (( c=1; c<=5; c++ ))
do
   echo "run $c node"
   gnome-terminal -- $TAGIONWAVE --port 401$c -p 1080$c -P 1090$c --dart-filename=./dart$c.drt --dart-synchronize=true
done
