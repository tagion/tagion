#!/bin/bash

if [ $# -lt 1 ]; then
    echo "Usage: $0 path/to/create_wallets.sh [path/to/network/folder]"
    exit 1
fi

# Parse args
CREATE_WALLETS="$1"
NETWORK_FOLDER="${2:-$(pwd)}"

# Clear 
rm /tmp/neuewelle_pm2.log
rm /tmp/subscriber_pm2.log

# Optionally clear network folder
read -p "Clear given network folder '$NETWORK_FOLDER'? [Y/n]: " answer

case $answer in
    [Yy]* ) 
        echo "Clearing given folder..."
        rm -r $NETWORK_FOLDER/*
        echo "Done"
        ;;
    * ) 
        echo "Folder without changes"
        ;;
esac

BIN_FOLDER="/home/ivanbilan/bin/"

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

# Create wallets
bash $CREATE_WALLETS -b $BIN_FOLDER/ -n 5 -w 5 -k $NETWORK_FOLDER/wave -t $NETWORK_FOLDER/wallets -u $NETWORK_FOLDER/keys.txt

# Start network with pm2
echo "********* Start network *********"
pm2 start $SCRIPT_DIR/neuewelle.sh -- $NETWORK_FOLDER

# Check neuewelle state
sleep 1s
pm2 ls

# Check neuewelle state
sleep 1s
pm2 ls

# Start subscriber
pm2 start $SCRIPT_DIR/subscriber.config.json

# Waiting for user input
read -n 1 -s -r -p "Press any key to stop"
echo

# Stop subscriber and neuewelle
echo "********* Stop network *********"
pm2 delete subscriber neuewelle
