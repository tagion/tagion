#!/usr/bin/env bash

# Set the directory path
DIRECTORY=$PWD
DART_BACKEND="0.0.0.0:8081/test"
# Loop through all files in the directory
for file in "$DIRECTORY"/*; do
  if [ -f "$file" ]; then
    # Get the filename without the path
    filename=$(basename "$file")

    # Run hibonutil command and capture the output
    output=$(hibonutil -bc "$file")

    # Remove leading and trailing whitespace from the output
    output=$(echo "$output" | awk '{$1=$1};1')

    # Run curl command with the output string and capture the response
    response=$(curl --location --request POST "$DART_BACKEND/$output")

    # Extract the fingerprint from the JSON response
    fingerprint=$(echo "$response" | jq -r '.data.fingerprint')

    # Echo the fingerprint
    echo "Fingerprint for $filename: $fingerprint"
    # Display QR code for the URL containing the fingerprint
    if [ "$filename" = "delivery_event1.hibon" ]; then
      qrencode -t ansiutf8 "0.0.0.0:8081/test/$fingerprint"
    fi
  fi
done