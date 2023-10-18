#!/bin/bash

usage() { echo "Usage: $0 -b <bindir> [-n <nodes=5>] [-w <wallets=5>] [-k <network dir = ./network>] [-t <wallets dir = ./wallets>]" 1>&2; exit 1; }


bdir=""
nodes=5
wallets=5
bills=10
ndir=$(readlink -m "./network")
wdir=$(readlink -m "./wallets")

while getopts "n:w:b:k:t:h" opt
do
    case $opt in
        h)  usage ;;
        n)  nodes=$OPTARG ;;
        w)  wallets=$OPTARG ;;
        b)  bdir=$(readlink -m "$OPTARG") ;;
        k)  ndir=$(readlink -m "$OPTARG") ;;
        t)  wdir=$(readlink -m "$OPTARG") ;;
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

mkdir -p $ndir
mkdir -p $wdir


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

  for (( b=1; b <= bills; b++)); 
  do
    bill_name=$(readlink -m "$wdir/bill$i-$b.hibon")
    $bdir/geldbeutel "$wallet_config" -x "$pincode" --amount 10000 -o "$bill_name" 
    echo "Created bill $bill_name"
  done 

done

bill_files=$(ls $wdir/bill*.hibon)
$bdir/stiefel $bill_files -o $wdir/dart_recorder.hibon

mkdir -p $ndir

for ((i = 0; i <= nodes-1; i++)); 
do
  dartfilename="${ndir}/Node_${i}_dart.drt"
  echo "$dartfilename"
  $bdir/dartutil --initialize "$dartfilename"
  $bdir/dartutil "$dartfilename" $wdir/dart_recorder.hibon -m
done

rm -rf $wdir/bill*.hibon

cat << EOF > $ndir/tagionwave.json
{
    "collector": null,
    "dart": {
        "dart_filename": "dart.drt",
        "dart_path": "",
        "folder_path": "${ndir}"
    },
    "dart_interface": {
        "dart_prefix": "DART_",
        "pool_size": 12,
        "sendbuf": 4096,
        "sendtimeout": 1000,
        "sock_addr": "abstract:\/\/DART_NEUEWELLE"
    },
    "epoch_creator": {
        "scrap_depth": 5,
        "timeout": 15
    },
    "hirpc_verifier": {
        "rejected_hirpcs": "",
        "send_rejected_hirpcs": false
    },
    "inputvalidator": {
        "sock_addr": "abstract:\/\/CONTRACT_NEUEWELLE",
        "sock_recv_buf": 4096,
        "sock_recv_timeout": 1000,
        "sock_send_buf": 1024,
        "sock_send_timeout": 200
    },
    "monitor": {
        "dataformat": "json",
        "enable": false,
        "port": 10900,
        "taskname": "monitor",
        "timeout": 500,
        "url": "127.0.0.1"
    },
    "replicator": {
        "folder_path": "${ndir}\/recorder"
    },
    "subscription": {
        "address": "abstract:\/\/SUBSCRIPTION_NEUEWELLE",
        "sendbufsize": 4096,
        "sendtimeout": 1000,
        "tags": ""
    },
    "task_names": {
        "collector": "collector ",
        "dart": "dart",
        "dart_interface": "dartinterface",
        "epoch_creator": "epoch_creator",
        "hirpc_verifier": "hirpc_verifier",
        "inputvalidator": "inputvalidator",
        "program": "tagion",
        "replicator": "replicator",
        "supervisor": "supervisor",
        "transcript": "transcript",
        "tvm": "tvm"
    },
    "transcript": null,
    "tvm": null,
    "wave": {
        "network_mode": "INTERNAL",
        "number_of_nodes": $nodes,
        "prefix_format": "Node_%s_"
    }
}
EOF

cd -

echo "Run the network this way:"
echo "$bdir/neuewelle $ndir/tagionwave.json"


