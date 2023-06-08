#!/usr/bin/env bash

# Set the directory path
DIRECTORY=$PWD
DART_BACKEND="https://api-services.decard.io/test"
DART_FRONTEND="https://rawdata.decard.io/?fp="
LAST_FILE="final_destination.hibon"
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
    response=$(curl -k --location --request POST "$DART_BACKEND/$output")

    # Extract the fingerprint from the JSON response
    fingerprint=$(echo "$response" | jq -r '.data.fingerprint')

    # Echo the fingerprint
    echo "Fingerprint for $filename: $fingerprint"
    # Display QR code for the URL containing the fingerprint
    if [ "$filename" = $LAST_FILE ]; then
      qrencode -t ansiutf8 "$DART_FRONTEND$fingerprint"
      echo "URL: $DART_FRONTEND$fingerprint"
    fi
  fi
done


