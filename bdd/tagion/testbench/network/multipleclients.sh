#!/bin/bash
./client.sh hugo &


exit 0
for i in {0..1} 
do
    export y="process_$i"
    echo $y
    ./client.sh $y &
done