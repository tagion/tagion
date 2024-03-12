#!/bin/bash

usage() {
    echo "Usage: bash $0 -n <network_path> -f <from_wallet> -t <to_wallet> -a <amount>"
    echo "  -w <create_wallets>  Specify the create_wallets script"
    echo "  -n <network_path>    Specify the path for network files"
    echo "  -t <tags>            Specify the tags to subscribe"
}

NETWORK_FOLDER=""
FROM_WALLET=""
TO_WALLET=""
AMOUNT=""

while getopts "n:f:t:a:" opt; do
  case $opt in
    n)
      NETWORK_FOLDER="$OPTARG"
      ;;
    f)
      FROM_WALLET="$OPTARG"
      ;;
    t)
      TO_WALLET="$OPTARG"
      ;;
    a)
      AMOUNT="$OPTARG"
      ;;
    \?)
      echo "Invalid option: -$OPTARG" >&2
      ;;
  esac
done

if [ -z "$NETWORK_FOLDER" ] || [ -z "$FROM_WALLET" ] || [ -z "$TO_WALLET" ] || [ -z "$AMOUNT" ]; then
    echo "Error. Missing required arguments."
    usage
    exit 1
fi

echo "Input args:"
echo "    network_path   : $NETWORK_FOLDER"
echo "    from_wallet    : $FROM_WALLET"
echo "    to_wallet      : $TO_WALLET"
echo "    amount         : $AMOUNT"

update_wallet()
{
    local wallet=$1

    echo "Update wallet$wallet:"
    geldbeutel $NETWORK_FOLDER/wallets/wallet$wallet.json --update --sendkernel -x 000$wallet
}

check_sum()
{
    local wallet=$1

    echo "Check sum of wallet$wallet:"
    geldbeutel $NETWORK_FOLDER/wallets/wallet$wallet.json -s
}

echo
update_wallet $FROM_WALLET

echo
update_wallet $TO_WALLET

echo
check_sum $FROM_WALLET

echo
check_sum $TO_WALLET

TMP_PAYMENT="/tmp/payment.hibon"
echo
echo "Create payment request:"
geldbeutel $NETWORK_FOLDER/wallets/wallet$TO_WALLET.json --amount $AMOUNT -o $TMP_PAYMENT -x 000$TO_WALLET

echo
echo "Pay request:"
geldbeutel $NETWORK_FOLDER/wallets/wallet$FROM_WALLET.json --pay $TMP_PAYMENT --sendkernel -x 000$FROM_WALLET

echo
update_wallet $FROM_WALLET

echo
update_wallet $TO_WALLET

echo
check_sum $FROM_WALLET

echo
check_sum $TO_WALLET
