#!/usr/bin/env bash
DART_BACKEND="https://api-services.decard.io/test"
DART_FRONTEND="https://rawdata.decard.io/?fp="

file="$1"
output=$(hibonutil -bc "$file")
output=$(echo "$output" | awk '{$1=$1};1')
response=$(curl -k --location --request POST "$DART_BACKEND/$output")
fingerprint=$(echo "$response" | jq -r '.data.fingerprint')
echo "Fingerprint for $file: $fingerprint"
qrencode -t ansiutf8 "$DART_FRONTEND$fingerprint"
echo "$DART_FRONTEND$fingerprint"