#!/bin/bash

usage() {
    echo "Usage: bash $0 -b <bin_path> -w <create_wallets> -n <network_path> [-t <tags>] [-p <payment_count>]"
    echo "  -b <bin_path>        Specify the path for binaries"
    echo "  -w <create_wallets>  Specify the create_wallets script"
    echo "  -n <network_path>    Specify the path for network files"
    echo "  -t <tags>            Specify the tags to subscribe"
    echo "  -p <payment_count>   Specify the number of payments to run"
}

BIN_FOLDER=""
CREATE_WALLETS=""
NETWORK_FOLDER=""
TAGS=""
PAYMENT_NUM=""

while getopts "b:w:n:t:p:" opt; do
  case $opt in
    b)
      BIN_FOLDER="$OPTARG"
      ;;
    w)
      CREATE_WALLETS="$OPTARG"
      ;;
    n)
      NETWORK_FOLDER="$OPTARG"
      ;;
    t)
      TAGS="$OPTARG"
      ;;
    p)
      PAYMENT_NUM="$OPTARG"
      ;;
    \?)
      echo "Invalid option: -$OPTARG" >&2
      ;;
  esac
done

if [ -z "$BIN_FOLDER" ] || [ -z "$NETWORK_FOLDER" ] || [ -z "$CREATE_WALLETS" ]; then
    echo "Error. Missing required arguments."
    usage
    exit 1
fi

echo "Input args:"
echo "    bin_path       : $BIN_FOLDER"
echo "    network_path   : $NETWORK_FOLDER"
echo "    create_wallets : $CREATE_WALLETS"
echo "    tags           : $TAGS"
echo "    payment_count  : $PAYMENT_NUM"
echo ""

if [ -z "$PAYMENT_NUM" ]; then
    echo "Payment count set to 0"
    PAYMENT_NUM=0
fi

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

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

# Create wallets
bash $CREATE_WALLETS -b $BIN_FOLDER/ -n 5 -w 5 -k $NETWORK_FOLDER/wave -t $NETWORK_FOLDER/wallets -u $NETWORK_FOLDER/keys.txt

# Start network with pm2
echo "********* Start network *********"
pm2 start $SCRIPT_DIR/neuewelle.sh -- $NETWORK_FOLDER $TAGS

# Check neuewelle state
sleep 1s
pm2 ls

# Check neuewelle state
sleep 1s
pm2 ls

# Start subscriber
pm2 start $SCRIPT_DIR/subscriber.config.json


# Make payments
for ((i=1; i<=$PAYMENT_NUM; i++)); do
    sleep 1s
    echo
    bash $SCRIPT_DIR/make_payment.sh -n $NETWORK_FOLDER -f 0 -t 1 -a 100
    echo "Payments done: $i"
done

# Waiting for user input
read -n 1 -s -r -p "Press any key to stop"
echo

# Stop subscriber and neuewelle
echo "********* Stop network *********"
pm2 delete subscriber neuewelle
