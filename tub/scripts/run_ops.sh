#!/usr/bin/env bash
#
# Runs operational tests
#
set -ex

HOST=x86_64-linux
bdir=$(realpath -m ./build/$HOST/bin)
TMP_DIR=$(mktemp -d /tmp/tagion_opsXXXX)

$BIN_DIR/tagion -s || echo soft links already exists

wallet_dir=$TMP_DIR/wallets

create_net_wallets() {
    wallets=$1
    wdir=$2
    # Create the wallets in a loop
    for ((i = 1; i <= wallets; i++)); 
    do
      wallet_dir=$(readlink -m  "${wdir}/wallet$i")
      mkdir -p $wallet_dir
      wallet_config=$(readlink -m  "${wdir}/wallet$i.json")
      password="password$i"
      pincode=0000

      # Step 1: Create wallet directory and config file
      $bdir/geldbeutel -O --path "$wallet_dir" "$wallet_config"

      # Step 2: Generate wallet passphrase and pincode
      $bdir/geldbeutel "$wallet_config" -P "$password" -x "$pincode"
      echo "Created wallet $i in $wallet_dir with passphrase: $password and pincode: $pincode"
      # Step 3: Generate a node name and insert into all infos
      name="node_$i"
      $bdir/geldbeutel "$wallet_config" -x "$pincode" --name "$name"
      address=$($bdir/geldbeutel "$wallet_config" --info) 
      all_infos+=" -p $address,$name"
      echo "wallet$i:$pincode" >> "$keyfile"
    done
}

# This file is copied over by the ci flow, if you're running this in the source repo then you need to copy it over as well
$BIN_DIR/create_wallets.sh -b $BIN_DIR -k $TMP_DIR/net -t $wallet_dir -u $TMP_DIR/net/keys -w100

$BIN_DIR/tagion wave $TMP_DIR/net/tagionwave.json --keys $wallet_dir < $TMP_DIR/net/keys > $TMP_DIR/net/wave.log &

echo "waiting for network to start!"
sleep 20;

WAVE_PID=$!

$BIN_DIR/bddenv.sh $BIN_DIR/testbench operational -w $wallet_dir/wallet1.json -x 0001 -w $wallet_dir/wallet2.json -x 0002

kill -s SIGINT $WAVE_PID
wait $WAVE_PID

echo "data files in $TMP_DIR"
