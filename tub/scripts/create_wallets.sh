#!/usr/bin/env bash

usage() { echo "Usage: $0 -b <bindir> [-n <nodes=5>] [-w <wallets=5>] [-q <bills=50>] [-k <network dir = ./network>] [-t <wallets dir = ./wallets>] [-u <key filename=./keys>]" 1>&2; exit 1; }

bdir=""
nodes=5
wallets=5
bills=50
ndir=$(readlink -m "./network")
wdir=$(readlink -m "./wallets")
keyfile=$(readlink -m "keys")

while getopts "n:w:b:k:t:h:u:q:" opt
do
    case $opt in
        h)  usage ;;
        n)  nodes=$OPTARG ;;
        w)  wallets=$OPTARG ;;
        b)  bdir=$(readlink -m "$OPTARG") ;;
        k)  ndir=$(readlink -m "$OPTARG") ;;
        t)  wdir=$(readlink -m "$OPTARG") ;;
        u)  keyfile=$(readlink -m "$OPTARG") ;;
        q)  bills=$OPTARG ;;
        *)  usage ;;
    esac
done

if [ -z "$bdir" -o ! -f "$bdir/dartutil" ]; then
    echo "Binary not found at $bdir" 1>&2
    usage
fi        

bdir=$(readlink -m "$bdir")

if [ $nodes -lt 3 -o $nodes -gt 7 ]; then
    echo "Invalid nodes number" 1>&2
    usage
fi

if [ $wallets -lt 3 -o $wallets -gt 7 ]; then
    echo "Invalid wallets number" 1>&2
    usage
fi

mkdir -p $ndir | echo "folder already exists"
mkdir -p $wdir | echo "folder already exists"
rm "$keyfile" | echo "No key file to delete"
touch $keyfile


all_infos=""

# Create the wallets in a loop
for ((i = 1; i <= wallets; i++)); 
do
  wallet_dir=$(readlink -m  "${wdir}/wallet$i")
  mkdir -p $wallet_dir
  wallet_config=$(readlink -m  "${wdir}/wallet$i.json")
  password="password$i"
  pincode=$(printf "%04d" $i)

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

  for (( b=1; b <= bills; b++)); 
  do
    bill_name=$(readlink -m "$wdir/bill$i-$b.hibon")
    $bdir/geldbeutel "$wallet_config" -x "$pincode" --amount 10000 -o "$bill_name" 
    echo "Created bill $bill_name"
    echo "$bdir/geldbeutel $wallet_config -x $pincode --force $bill_name"
    $bdir/geldbeutel "$wallet_config" -x "$pincode" --force "$bill_name"
    echo "Forced bill into wallet $bill_name"
  done 


done

echo "$all_infos"

bill_files=$(ls $wdir/bill*.hibon)
cat $wdir/bill*.hibon |"${bdir}/stiefel" -a $all_infos -o $wdir/dart_recorder.hibon
mkdir -p $ndir | echo "folder already exists"

for ((i = 0; i <= nodes-1; i++)); 
do
  dartfilename="${ndir}/Node_${i}_dart.drt"
  echo "$dartfilename"
  $bdir/dartutil --initialize "$dartfilename"
  $bdir/dartutil "$dartfilename" $wdir/dart_recorder.hibon -m
done

# rm -rf $wdir/bill*.hibon

cd $ndir

$bdir/neuewelle -O --option=wave.number_of_nodes:$nodes --option=subscription.tags:taskfailure

cd -

echo "Run the network this way:"
echo "$bdir/neuewelle $ndir/tagionwave.json --keys $wdir < $keyfile"
