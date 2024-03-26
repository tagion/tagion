#!/usr/bin/env bash

# Display usage instructions
usage() { echo "Usage: $0 -b <bindir> [-n <nodes=5>] [-w <wallets=5>] [-q <bills=50>] [-k <network dir = ./network>] [-t <wallets dir = ./wallets>] [-u <key filename=./keys>]" 1>&2; exit 1; }

# Initialize default values
bdir=""
nodes=5
wallets=5
bills=50
ndir=$(readlink -m "./network")
wdir=$(readlink -m "./wallets")
keyfile=$(readlink -m "keys")

# Process command-line options
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

# Check if the required binary is in the specified directory
if [ -z "$bdir" -o ! -f "$bdir/dartutil" ]; then
    echo "Binary not found at $bdir" 1>&2
    usage
fi        

# Finalize binary directory path
bdir=$(readlink -m "$bdir")

# Validate the number of nodes
if [ $nodes -lt 3 -o $nodes -gt 51 ]; then
    echo "Invalid nodes number" 1>&2
    usage
fi

# Validate the number of wallets
if [ $wallets -lt 3 -o $wallets -gt 51 ]; then
    echo "Invalid wallets number" 1>&2
    usage
fi

# Create network and wallets directories, handle existing folders
mkdir -p $ndir || echo "folder already exists"
mkdir -p $wdir || echo "folder already exists"

# Remove existing key file, if any, and create a new one
rm "$keyfile" || echo "No key file to delete"
touch $keyfile

# Variable to accumulate wallet information
all_infos=""

# Create wallets in a loop
for ((i = 0; i < wallets; i++)); 
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
  node_info=$($bdir/geldbeutel "$wallet_config" --info) 
  address=$(printf "Node_%d_epoch_creator" $i)
  all_infos+=" -p $node_info,$address"
  echo "wallet$i:$pincode" >> "$keyfile"

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
bill_files=$(ls $wdir/bill*.hibon)
echo "Create genesis dart_recorder"
cat $wdir/bill*.hibon |"${bdir}/stiefel" -a $all_infos -o $wdir/dart_recorder.hibon

echo "Create genesis trt_recorder"
cat $wdir/bill*.hibon |"${bdir}/stiefel" --trt -o $wdir/trt_recorder.hibon

# Create network directory if not already present
mkdir -p $ndir | echo "folder already exists"

# Loop to initialize and modify nodes
for ((i = 0; i < nodes; i++)); 
do
  # Create dart filename for each node
  dartfilename="${ndir}/Node_${i}_dart.drt"
  echo "DART file $dartfilename"

  # Create initial dart file
  $bdir/dartutil --initialize "$dartfilename"

  # Modify the node with the dart_recorder file
  $bdir/dartutil "$dartfilename" $wdir/dart_recorder.hibon -m

  # Create TRT filename for each node
  trtfilename="${ndir}/Node_${i}_trt.drt"
  echo "TRT file $trtfilename"

  # Create initial TRT file
  $bdir/dartutil --initialize "$trtfilename"

  # Modify the node with the trt_recorder file
  $bdir/dartutil "$trtfilename" $wdir/trt_recorder.hibon -m
done

# rm -rf $wdir/bill*.hibon

# Change directory to the network directory
cd $ndir

# Configure the network with the neuewelle binary
$bdir/neuewelle -O --option=wave.number_of_nodes:$nodes --option=subscription.tags:taskfailure,recorder

# Return to the previous directory
cd -

# Print instructions on how to run the network
echo "Run the network this way:"
echo "$bdir/neuewelle $ndir/tagionwave.json --keys $wdir < $keyfile"
