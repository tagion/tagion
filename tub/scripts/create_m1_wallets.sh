#!/usr/bin/env bash


set -xe

# Display usage instructions
usage() { echo "Usage: $0 -b <bindir> [-n <nodes=5>] [-w <wallets=5>] [-q <bills=50>] [-k <network dir = ./network>] [-t <wallets dir = ./wallets>] [-u <key filename=./keys>]" 1>&2; exit 1; }

# Initialize default values
bdir=""
nodes=5
wallets=5
bills=50
ndir="$(readlink -m "./network")/mode1"
wdir=$(readlink -m "./wallets")

# Process command-line options
while getopts "n:w:b:k:t:h:u:q:" opt
do
    case $opt in
        h)  usage ;;
        n)  nodes=$OPTARG ;;
        w)  wallets=$OPTARG ;;
        b)  bdir=$(readlink -m "$OPTARG") ;;
        k)  ndir="$(readlink -m "$OPTARG")/mode1" ;;
        t)  wdir=$(readlink -m "$OPTARG") ;;
        q)  bills=$OPTARG ;;
        *)  usage ;;
    esac
done

# Check if the required binary is in the specified directory
if [ -z "$bdir" -o ! -f "$bdir/dartutil" ]; then
    echo "Binary not found at $bdir" 1>&2
    usage
fi        

# Finalize binary directory path
bdir=$(readlink -m "$bdir")

# Validate the number of nodes
if [ $nodes -lt 3 -o $nodes -gt 7 ]; then
    echo "Invalid nodes number" 1>&2
    usage
fi

# Validate the number of wallets
if [ $wallets -lt 3 -o $wallets -gt 7 ]; then
    echo "Invalid wallets number" 1>&2
    usage
fi

# Create network and wallets directories, handle existing folders
mkdir -p "$ndir" "$wdir"

# Variable to accumulate wallet information
all_infos=""

# Create wallets in a loop
for ((i = 1; i <= wallets; i++)); 
do
  # Set up wallet directory and configuration
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
  pkey="${address/[^,]*,/}"
  ipaddr=$((10700+i))
  echo "$pkey tcp://0.0.0.0:$ipaddr" >> "$ndir/address_book.txt"
  all_infos+=" -p $address,$name"

  # Create bills for the wallet
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

# Display accumulated wallet information
echo "$all_infos"

# Concatenate and process all bill files
echo "Create genesis dart_recorder"
cat $wdir/bill*.hibon |"${bdir}/stiefel" -a $all_infos -o "$wdir/dart_recorder.hibon"

echo "Create genesis trt_recorder"
cat $wdir/bill*.hibon |"${bdir}/stiefel" --trt -o "$wdir/trt_recorder.hibon"

# Create a dart filename
dartfilename="${ndir}/genesis_dart.drt"
echo "DART file $dartfilename"

# Create initial dart file
"$bdir/dartutil" --initialize "$dartfilename"

# Modify the node with the dart_recorder file
"$bdir/dartutil" "$dartfilename" "$wdir/dart_recorder.hibon" -m

# Create TRT filename for each node
trtfilename="${ndir}/genesis_trt.drt"
echo "TRT file $trtfilename"

# Create initial TRT file
"$bdir/dartutil" --initialize "$trtfilename"

# Modify the node with the trt_recorder file
"$bdir/dartutil" "$trtfilename" "$wdir/trt_recorder.hibon" -m

# Print instructions on how to run the network
echo "Run the network this way:"

# Loop to initialize and modify nodes
echo "Run the network this way:"
for ((i = 0; i <= nodes-1; i++)); 
do
    node_dir="$ndir/node$i"
    mkdir -p "$node_dir"
    cp "$dartfilename" "$node_dir"/dart.drt
    cp "$trtfilename" "$node_dir"/trt.drt

    (
        # Change directory to the network directory
        cd "$node_dir"

        # Configure the network with the neuewelle binary
        "$bdir/neuewelle" -O --option=wave.network_mode:LOCAL --option=subscription.tags:taskfailure
    )

    echo "$bdir/neuewelle $node_dir/tagionwave.json"

done
