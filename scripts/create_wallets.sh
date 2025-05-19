#!/usr/bin/env bash

# Display usage instructions
usage() { 
    echo "Usage: $0
        -b <bindir, default is to search in user PATH>
        -n <nodes=5>
        -w <wallets=5>
        -q <bills=50>
        -k <data dir = ./ >
        -u <key filename=./keys>
        -m <network_mode = 0>" 1>&2;
    exit 1;
}

# Initialize default values
bdir=""
nodes=5
bills=50
network_mode=0
data_dir="$(readlink -f ./)"
keyfile="keys"

ADDRESS_FORMAT=${ADDRESS_FORMAT:=tcp6://[::1]:%PORT}

# Process command-line options
while getopts "n:w:b:k:t:h:u:q:m:" opt
do
    case $opt in
        h)  usage ;;
        n)  nodes=$OPTARG ;;
        w)  echo "option '-w' was removed only '-n' is supported"; exit 1 ;;
        b)  bdir=$(readlink -f "$OPTARG") ;;
        k)  data_dir=$(readlink -f "$OPTARG") ;;
        t)  echo "option '-t' was removed only '-k' is supported"; exit 1 ;;
        u)  keyfile=$(readlink -f "$OPTARG") ;;
        q)  bills=$OPTARG ;;
        m)  network_mode=$OPTARG ;;
        *)  usage ;;
    esac
done

if [ "$network_mode" -lt 0 ] || [ "$network_mode" -gt 2 ]; then
  echo "Unsupported network mode $network_mode"
  exit 1
fi

# Check if the required binary is in the specified directory
if [ -z "$bdir" ] && [ -x "$(which tagion)" ]; then
    bdir="$(dirname "$(which tagion)")"
elif [ -f "$bdir/tagion" ]; then
    # Finalize binary directory path
    bdir=$(readlink -f "$bdir")
else
    echo "Tagion executable not found either add them to your PATH or set the binary path with -b flag" 1>&2
    usage
fi


# Create network and wallets directories, handle existing folders
mkdir -p "${data_dir}/mode$network_mode/" || echo "folder already exists $ndir"
ndir=$(readlink -f "${data_dir}/mode$network_mode/")
wdir=$(readlink -f "${data_dir}/mode$network_mode/")

# Remove existing key file, if any, and create a new one
rm "$keyfile" || echo "No key file to delete"
touch "$keyfile"
keyfile=$(realpath "$keyfile")

# Variable to accumulate wallet information
all_infos=""

function create_wallet() {
  wallet_dir=$1
  wallet_config=$2
  pincode=$3
  password=$4
  amount_of_bills=$5
  amount_per_bill=$6

  mkdir -p "$wallet_dir"

  # Step 1: Create wallet directory and config file
  "$bdir/geldbeutel" -O --path "$wallet_dir" "$wallet_config"

  # Step 2: Generate wallet passphrase and pincode
  "$bdir/geldbeutel" "$wallet_config" -P "$password" -x "$pincode"
  echo "Created wallet $i in $wallet_dir with passphrase: $password and pincode: $pincode"


  # Create bills for the wallet
  echo "creating $amount_of_bills bills with value $amount_per_bill for $wallet_config"
  for (( b=1; b <= amount_of_bills; b++ )); 
  do
    bill_name="$wallet_dir/bill_$b.hibon"
    "$bdir/geldbeutel" "$wallet_config" -x "$pincode" --amount "$amount_per_bill" -o "$bill_name" > /dev/null
    "$bdir/geldbeutel" "$wallet_config" -x "$pincode" --force "$bill_name" > /dev/null
  done 
}

create_wallet "$wdir/shell/wallet/" "$wdir/shell/wallet.json" 0001 "shellpass01" 100 10000

# Create wallets in a loop
for ((i = 0; i < nodes; i++)); 
do
  # Set up wallet directory and configuration
  wallet_dir="${wdir}/node$i/wallet"
  mkdir -p "$wallet_dir"
  wallet_config="${wdir}/node$i/wallet.json"
  password="password$i"
  pincode=0000

  create_wallet "$wallet_dir" "$wallet_config" "$pincode" "$password" 0 0

  # Step 3: Generate a node name and insert into all infos
  name="node_$i"
  "$bdir/geldbeutel" "$wallet_config" -x "$pincode" --name "$name"
  node_info=$("$bdir/geldbeutel" "$wallet_config" --info) 

  if [ $network_mode -eq 0 ]; then
      address=$(printf "node%d.tid" $i)
      echo "node$i/wallet/device.hibon:$pincode" >> "$keyfile"
  elif [ $network_mode -ge 1 ]; then
      node=$i
      port=$((10700+i))
      # Replace %NODE and %PORT in address string with node number and port
      address=${ADDRESS_FORMAT//\%NODE/$node}
      address=${address//\%PORT/$port}
  fi

  all_infos+=" -p $node_info,$address"

done

# Display accumulated wallet information
echo "$all_infos"

# Concatenate and process all bill files
echo "Create genesis dart_recorder"
cat $wdir/shell/wallet/bill*.hibon $wdir/node*/wallet/bill*.hibon | "${bdir}/stiefel" -a $all_infos -o "$wdir/dart_recorder.hibon"

echo "Create genesis trt_recorder"
cat $wdir/node*/wallet/bill*.hibon | "${bdir}/stiefel" --trt -o "$wdir/trt_recorder.hibon"

# Create network directory if not already present
mkdir -p "$ndir" || echo "folder already exists"

# Create a genesis dart
genesis_dart="${ndir}/genesis_dart.drt"
# Create initial dart file
"$bdir/dartutil" --initialize "$genesis_dart"
# Modify the dart with the dart_recorder file
"$bdir/dartutil" "$genesis_dart" "$wdir/dart_recorder.hibon" -m

# Create a genesis trt
genesis_trt="${ndir}/genesis_trt.drt"
echo "TRT file $genesis_trt"
# Create initial TRT file
"$bdir/dartutil" --initialize "$genesis_trt"
# Modify the dart with the trt_recorder file
"$bdir/dartutil" "$genesis_trt" "$wdir/trt_recorder.hibon" -m

# Loop to initialize and modify nodes
for ((i = 0; i < nodes; i++)); 
do
  # copy the genesis dart to each node

  node_dir="${ndir}/node$i"
  mkdir -p "$node_dir"
  cp "$genesis_dart" "$node_dir"/dart.drt
  cp "$genesis_trt" "$node_dir"/trt.drt

done

# rm -rf $wdir/bill*.hibon

# Change directory to the network directory
if [ $network_mode -eq 0 ]; then
    (cd "$ndir"
        # Configure the network with the neuewelle binary
        "$bdir/neuewelle" -O --option=wave.number_of_nodes:"$nodes" --option=wave.prefix_format:"node%s/" --option=subscription.tags:taskfailure,recorder,monitor
    )
    # Print instructions on how to run the network
    echo "Run the network this way:"
    echo "$bdir/neuewelle $ndir/tagionwave.json --keys $wdir < $keyfile"
elif [ $network_mode -eq 1 ]; then
    echo "cd $data_dir/ && tagionshell"
    for ((i = 0; i < nodes; i++)); 
    do
        node_dir="$ndir/node$i"
        (
            # Change directory to the network directory
            cd "$node_dir"

            # Configure the network with the neuewelle binary
            "$bdir/neuewelle" -O \
               --option=wave.network_mode:LOCAL \
               --option=epoch_creator.timeout:500 \
               --option=wave.number_of_nodes:"$nodes" \
               --option=subscription.tags:taskfailure,monitor,recorder,payload_received,node_send,node_recv,in_graph \
               --option=rpcserver.sock_addr:abstract://node$i/DART_NEUEWELLE \
               --option=subscription.address:abstract://node$i/SUBSCRIPTION_NEUEWELLE \
               --option=node_interface.node_address:"tcp6://[::1]:$((10700+i))" 2&> /dev/null
        )
        echo "echo 0000 | $bdir/neuewelle $node_dir/tagionwave.json &"

    done
else
    echo "cd $data_dir/ && tagionshell"

    # Mirror node
    node_dir="$ndir/mirror"
    mkdir -p "$node_dir"
    cp "$genesis_dart" "$node_dir"/dart.drt
    cp "$genesis_trt" "$node_dir"/trt.drt
    i=$((nodes));

    # Set up wallet directory and configuration
    wallet_dir="$node_dir/wallet"
    mkdir -p "$wallet_dir"
    wallet_config="$node_dir/wallet.json"
    password="password$i"
    pincode=0000

    create_wallet "$wallet_dir" "$wallet_config" "$pincode" "$password" 0 0
    (
        # Change directory to the network directory
        cd "$node_dir"

        # Configure the network with the neuewelle binary
        "$bdir/neuewelle" -O \
           --option=wave.network_mode:MIRROR \
           --option=epoch_creator.timeout:500 \
           --option=wave.number_of_nodes:"$nodes" \
           --option=subscription.tags:taskfailure,monitor,recorder,payload_received,node_send,node_recv,in_graph \
           --option=rpcserver.sock_addr:abstract://node$i/DART_NEUEWELLE \
           --option=subscription.address:abstract://node$i/SUBSCRIPTION_NEUEWELLE \
           --option=node_interface.node_address:"tcp6://[::1]:$((10700+i))" 2&> /dev/null
    )

    echo "echo 0000 | $bdir/neuewelle $node_dir/tagionwave.json &"

    # Network nodes
    for ((i = 0; i < nodes; i++)); 
    do
        node_dir="$ndir/node$i"
        (
            # Change directory to the network directory
            cd "$node_dir"

            # Configure the network with the neuewelle binary
            "$bdir/neuewelle" -O \
               --option=wave.network_mode:LOCAL \
               --option=epoch_creator.timeout:500 \
               --option=wave.number_of_nodes:"$nodes" \
               --option=subscription.tags:taskfailure,monitor,recorder,payload_received,node_send,node_recv,in_graph \
               --option=rpcserver.sock_addr:abstract://node$i/DART_NEUEWELLE \
               --option=subscription.address:abstract://node$i/SUBSCRIPTION_NEUEWELLE \
               --option=node_interface.node_address:"tcp6://[::1]:$((10700+i))" 2&> /dev/null
        )

        echo "echo 0000 | $bdir/neuewelle $node_dir/tagionwave.json &"
    done
fi
