#!/bin/env bash

# Check if the number of wallets argument is provided
if [ $# -ne 1 ]; then
  echo "Usage: $0 <number_of_wallets>"
  exit 1
fi

# Extract the number of wallets from the command line argument
num_wallets=$1

# Create the wallets in a loop
for ((i = 0; i <= num_wallets; i++)); do
  wallet_dir="wallet$i"
  wallet_config="wallet$i.json"
  password="password$i"
  pincode=$(printf "%04d" $i)

  # Step 1: Create wallet directory and config file
  geldbeutel -O --path "./$wallet_dir" "$wallet_config"

  # Step 2: Generate wallet passphrase and pincode
  geldbeutel "$wallet_config" -P "$password" -x "$pincode"

  echo "Created wallet $i in $wallet_dir with passphrase: $password and pincode: $pincode"
done
