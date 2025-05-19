#!/usr/bin/env bash

usage() { echo "Usage: $0 dart_file |-f|" 1>&2; exit 1; }

FIX_BROKEN_ADDRESS=false

while getopts "f" opt
do
    case $opt in
        f)  FIX_BROKEN_ADDRESS=true ;;
        *)  usage ;;
    esac
done
if [[ -z $1 ]]; then
    echo "No dart file specified"
    exit 1
fi

dart_file="$1"

tmp_nnr_file=$(mktemp)
tmp_address_file=$(mktemp)
tmp_key_file=$(mktemp)

# dartutil --dump /tmp/tagion/wave/Node_0_dart.drt | hirep -r \$@NNR | hibonutil -p | jq -r '.["#$node"][1], .["$addr"]'
dartutil --dump "$dart_file" | hirep -r \$@NNR > "$tmp_nnr_file"
hibonutil -p < "$tmp_nnr_file" | jq -r '.["#$node"][1]' > "$tmp_key_file"

# Get node addr and replace with task name
if [[ -z "$FIX_BROKEN_ADDRESS" ]]; then 
    hibonutil -p < "$tmp_nnr_file" | jq -r '.["$addr"]' | sed 's/^./N/' | sed 's/$/_node_interface/' > "$tmp_address_file"
else
    hibonutil -p < "$tmp_nnr_file" | jq -r '.["$addr"]' > "$tmp_address_file"
fi

paste "$tmp_key_file" "$tmp_address_file"
rm $tmp_key_file $tmp_address_file $tmp_nnr_file
