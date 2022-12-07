#!/bin/bash
x=$*
echo "børge$*"
for i in {0..1}
do
    y="$x"_"$i"
    echo "hugo$y"
    echo $y | /home/imrying/work/tagion/build/x86_64-linux/bin/ssl_client localhost 8004 
done