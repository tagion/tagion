#!/usr/bin/env bash
#
# Runs operational tests
#

platform="x86_64-linux"
bdir=$(realpath -m ./build/$platform/bin)
# TMP_DIR=$(mktemp -d /tmp/tagion_opsXXXX)
TMP_DIR="$HOME/.local/share/tagion"

"$bdir"/tagion -s || echo "Soft links already exists";
make ci-files || echo "Not in source dir"

wdir=$TMP_DIR/wallets
net_dir="$TMP_DIR"/wave
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

(
    cd "$net_dir" || return 1
    "$bdir"/neuewelle -O \
        --option=wave.number_of_nodes:$nodes \
        --option=wave.fail_fast:true \
        --option=subscription.tags:taskfailure
)

systemctl stop --user neuewelle.service || echo "No wave service was running"
systemctl stop --user tagionshell.service || echo "No shell service was running"
mkdir -p ~/.local/bin ~/.config/systemd/user ~/.local/share/tagion/wave 
cp "$bdir/run_network.sh" ~/.local/share/tagion/wave/
cp "$bdir/tagion" ~/.local/bin/
cp "$bdir/tagionshell.service" "$bdir/neuewelle.service" ~/.config/systemd/user

systemctl --user daemon-reload
systemctl restart --user neuewelle.service
systemctl restart --user tagionshell.service

# "$bdir"/neuewelle "$TMP_DIR"/net/tagionwave.json --verbose --keys "$wdir" < "$keyfile" > "$net_dir"/wave.log &

echo "waiting for network to start!"
sleep 20;

set -ex

op_pids="";
log_dir="$PWD/logs/ops"
mv "$log_dir" "$log_dir.old" || echo "no old logs"
mkdir -p "$log_dir"
for ((i = 1; i <= wallets/2; i++)); 
do
    export DLOG="$log_dir/$i"
    mkdir -p "$DLOG"
    "$bdir"/testbench operational --duration 5 --unit minutes -w "$wdir"/wallet$i.json -x "$pincode" -w "$wdir"/wallet$((i*2)).json -x "$pincode" > "$DLOG/test.log" 2>&1 &
    op_pids+=${!}
    sleep 0.2s
done

echo "Running $((wallets/2)) test clients"

wait

echo "data files in $TMP_DIR"
