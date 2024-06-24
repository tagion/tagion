#!/usr/bin/env bash

if [ -z "$1" ]; then
    echo "Usage: $0 <num_addresses>"
    exit 1
fi

num_addresses=$1

subscribe_command="./bin/subscriber --tag=node_action -o nodeevents.hibon"

for ((i=0; i<$num_addresses; i++))
do
    address="abstract://Mode1_${i}_SUBSCRIPTION_NEUEWELLE"
    subscribe_command="$subscribe_command --address $address"
done

eval $subscribe_command

