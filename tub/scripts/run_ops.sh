#!/usr/bin/env bash
#
# Runs operational tests
#
set -ex

platform="x86_64-linux"
bdir=$(realpath -m ./build/$platform/bin)
# TMP_DIR=$(mktemp -d /tmp/tagion_opsXXXX)
TMP_DIR="$HOME/.local/share/tagion"

"$bdir"/tagion -s || echo "";

wdir=$TMP_DIR/wallets
net_dir="$TMP_DIR"/net
amount=1000000
keyfile="$wdir/keys.txt"
mkdir -p "$wdir" "$net_dir"

create_wallet_and_bills() {
    _name=$1
    i=$_name
    _bills=$2
    _wdir=$3
    _pincode=$4

    wallet_dir=$(readlink -m  "${_wdir}/wallet$i")
    mkdir -p "$wallet_dir"
    wallet_config=$(readlink -m  "${_wdir}/wallet$i.json")
    password="password$i"

    # Step 1: Create wallet directory and config file
    "$bdir"/geldbeutel -O --path "$wallet_dir" "$wallet_config"

    # Step 2: Generate wallet passphrase and pincode
    "$bdir"/geldbeutel "$wallet_config" -P "$password" -x "$_pincode"
    echo "Created wallet $i in $wallet_dir with passphrase: $password and pincode: $_pincode"

    for (( b=1; b <= _bills; b++)); 
    do
      bill_name=$(readlink -m "$_wdir/bill$i-$b.hibon")
      "$bdir"/geldbeutel "$wallet_config" -x "$_pincode" --amount "$amount" -o "$bill_name" 
      echo "Created bill $bill_name"
      "$bdir"/geldbeutel "$wallet_config" -x "$_pincode" --force "$bill_name"
      echo "Forced bill into wallet $bill_name"
    done 

}

pincode=0000
bills=1
wallets=100
nodes=5
for ((i = 1; i <= wallets; i++ ));
do
    create_wallet_and_bills $i $bills $wdir $pincode;
done

all_infos=""
# Generate a node name and insert into all infos
for ((i = 1; i <= nodes; i++ ));
do
    name="node_$i"
    wallet_config=$(readlink -m  "${wdir}/wallet$i.json")
    "$bdir"/geldbeutel "$wallet_config" -x "$pincode" --name "$name"
    address=$("$bdir"/geldbeutel "$wallet_config" --info) 
    all_infos+=" -p $address,$name"
    echo "wallet$i:$pincode" >> "$keyfile"
done

echo $all_infos
# bill_files=$(ls $wdir/bill*.hibon)
cat "$wdir"/bill*.hibon | "${bdir}/stiefel" -a $all_infos -o "$wdir"/dart_recorder.hibon

for ((i = 0; i <= nodes-1; i++)); 
do
  dartfilename="${net_dir}/Node_${i}_dart.drt"
  echo "$dartfilename"
  "$bdir/dartutil" --initialize "$dartfilename"
  "$bdir/dartutil" "$dartfilename" "$wdir"/dart_recorder.hibon -m
done

cd "$net_dir"
"$bdir"/neuewelle -O \
    --option=wave.number_of_nodes:$nodes \
    --option=wave.fail_fast:true \
    --option=subscription.tags:taskfailure
cd -

systemctl stop --user neuewelle.service || echo "No wave service was running"
systemctl stop --user tagionshell.service || echo "No shell service was running"
mkdir -p ~/.local/share/bin ~/.config/systemd/user
cp "$bdir/tagion" ~/.local/share/bin/
cp "$bdir/tagionshell.service" "$bdir/neuewelle.service" ~/.config/systemd/user

systemctl --user daemon-reload
systemctl restart --user neuewelle.service
systemctl restart --user tagionshell.service

# "$bdir"/neuewelle "$TMP_DIR"/net/tagionwave.json --verbose --keys "$wdir" < "$keyfile" > "$net_dir"/wave.log &

WAVE_PID=$!
echo "waiting for network to start!"
sleep 20;


"$bdir"/bddenv.sh "$bdir"/testbench operational -w "$wdir"/wallet1.json -x "$pincode" -w "$wdir"/wallet2.json -x "$pincode"

kill -s SIGINT "$WAVE_PID"
wait "$WAVE_PID"

echo "data files in $TMP_DIR"
