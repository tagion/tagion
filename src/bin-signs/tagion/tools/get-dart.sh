#!/usr/bin/env bash

# Define the directory path
DIRECTORY="/home/imrying/work/demo"

CONTAINER_ID="$1"
echo "Copying from $CONTAINER_ID:/opt/tagion/nodes/data"
docker cp "$CONTAINER_ID:/opt/tagion/nodes/node-master/data/" "$DIRECTORY"



# Check if the "--old" argument is provided
if [[ "$2" == "--r" ]]; then
  mkdir -p "$DIRECTORY/replica_db"
  mv "$DIRECTORY"/data/* "$DIRECTORY/replica_db"
  echo "----------------------------------------------------------------------------"
  for i in 0 1 2 3 4
  do
    BULLSEYE=$(dartutil "$DIRECTORY/replica_db/node$i/dart.drt" --eye)
    echo "node$i| $BULLSEYE"
  done
  
else 
  mkdir -p "$DIRECTORY/network"
  mv "$DIRECTORY"/data/* "$DIRECTORY/network"
  echo "----------------------------------------------------------------------------"
  for i in 0 1 2 3 4
  do
    BULLSEYE=$(dartutil "$DIRECTORY/network/node$i/dart.drt" --eye)
    echo "node$i| $BULLSEYE"
  done
fi

# Clean up
rm -rf "$DIRECTORY"/data/
