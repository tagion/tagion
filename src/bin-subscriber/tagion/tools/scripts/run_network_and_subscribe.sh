#!/bin/bash

if [ $# -lt 1 ]; then
    echo "Usage: $0 path/to/create_wallets.sh [path/to/network/folder]"
    exit 1
fi

# Parse args
CREATE_WALLETS="$1"
FOLDER="${2:-$(pwd)}"


# 0. Optionally clear network folder
read -p "Clear given network folder '$FOLDER'? [Y/n]" answer

case $answer in
    [Yy]* ) 
        echo "Clearing given folder..."
        rm -r $FOLDER/*
        echo "Done"
        ;;
    * ) 
        echo "Folder without changes"
        ;;
esac

BIN_FOLDER="/home/ivanbilan/bin/"

# 1. Create wallets
bash $CREATE_WALLETS -b $BIN_FOLDER/ -n 5 -w 5 -k $FOLDER/wave -t $FOLDER/wallets -u $FOLDER/keys.txt

# 2. Start network with pm2
echo "********* Start network *********"
pm2 start $BIN_FOLDER/neuewelle --name neuewelle -- --option=subscription.tags:recorder,trt_created $FOLDER/wave/tagionwave.json --keys $FOLDER/wallets < $FOLDER/keys.txt

# 3. Start subscriber
echo "********* Start subscriber *********"
pm2 start $BIN_FOLDER/subscriber --name sub -- --address abstract://SUBSCRIPTION_NEUEWELLE -w --tag recorder

echo "Wait 5..."
sleep 5

# 4. Stop subscriber
echo "********* Stop subscriber *********"
pm2 delete sub

# 4. Stop network
echo "********* Stop network *********"
pm2 delete neuewelle