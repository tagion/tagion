#!/usr/bin/env bash

# Define the directory path
DIRECTORY="/home/imrying/work/demo"

CONTAINER_ID="$1"
echo "Copying from $CONTAINER_ID:/opt/tagion/nodes/data"
docker cp "$CONTAINER_ID:/opt/tagion/nodes/node-master/data/" "$DIRECTORY"



# Check if the "--old" argument is provided
if [[ "$2" == "--r" ]]; then
  mkdir -p "$DIRECTORY/replica_DB_at_Service_Delivery_Point"
  mv "$DIRECTORY"/data/* "$DIRECTORY/replica_DB_at_Service_Delivery_Point"
  echo "----------------------------------------------------------------------------"
  for i in 0 1 2 3 4
  do
    BULLSEYE=$(dartutil "$DIRECTORY/replica_DB_at_Service_Delivery_Point/node$i/dart.drt" --eye)
    echo "node$i| $BULLSEYE"
  done
  
else 
  mkdir -p "$DIRECTORY/DC_DB_at_District_Centres"
  mv "$DIRECTORY"/data/* "$DIRECTORY/DC_DB_at_District_Centres"
  echo "----------------------------------------------------------------------------"
  for i in 0 1 2 3 4
  do
    BULLSEYE=$(dartutil "$DIRECTORY/DC_DB_at_District_Centres/node$i/dart.drt" --eye)
    echo "node$i| $BULLSEYE"
  done
fi

# Clean up
rm -rf "$DIRECTORY"/data/
