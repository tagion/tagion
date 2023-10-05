#!/bin/env bash

# Check if the number of wallets argument is provided
if [ $# -ne 1 ]; then
  echo "Usage: $0 <number_of_wallets>"
  exit 1
fi

get_abs_filename() {
  # $1 : relative filename
  echo "$(cd "$(dirname "$1")" && pwd)/$(basename "$1")"
}

# Extract the number of wallets from the command line argument
num_wallets=$1
num_bills=10
network_folder="network"
number_of_nodes=5

# Create the wallets in a loop
for ((i = 1; i <= num_wallets; i++)); 
do
  wallet_dir=$(get_abs_filename "./wallet$i")
  wallet_config="wallet$i.json"
  password="password$i"
  pincode=$(printf "%04d" $i)

  # Step 1: Create wallet directory and config file
  geldbeutel -O --path "$wallet_dir" "$wallet_config"

  # Step 2: Generate wallet passphrase and pincode
  geldbeutel "$wallet_config" -P "$password" -x "$pincode"
  echo "Created wallet $i in $wallet_dir with passphrase: $password and pincode: $pincode"

  for (( b=1; b <= num_bills; b++)); 
  do
    bill_name="bill$i-$b.hibon"
    geldbeutel "$wallet_config" -x "$pincode" --amount 10000 -o "$bill_name" 
    echo "Created bill $bill_name"
  done 

done

bill_files=$(ls bill*.hibon)
stiefel $bill_files -o dart_recorder.hibon

mkdir -p $network_folder

for ((i = 0; i <= number_of_nodes-1; i++)); 
do
  dartfilename="${network_folder}/Node_${i}_dart.drt"
  echo "$dartfilename"
  dartutil --initialize "$dartfilename"
  dartutil "$dartfilename" dart_recorder.hibon -m
done
