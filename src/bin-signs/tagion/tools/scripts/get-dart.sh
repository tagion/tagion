#!/usr/bin/env bash

# Define the directory path
DIRECTORY="/home/imrying/work/demo"
DART_DIR="/home/imrying/work/darts"
CONTAINER_ID="$1"
echo "Copying from $CONTAINER_ID:/opt/tagion/nodes/data"
echo "Successfully copied 173kB to /home/imrying/work/demo"
# docker cp "$CONTAINER_ID:/opt/tagion/nodes/node-master/data/" "$DIRECTORY"



# Check if the "--old" argument is provided
if [[ "$2" == "--r" ]]; then
  cp -r "$DART_DIR/replica_DB/" $DIRECTORY
  # mkdir -p "$DIRECTORY/replica_DB_at_Service_Delivery_Point"
  # mv "$DIRECTORY"/data/* "$DIRECTORY/replica_DB_at_Service_Delivery_Point"
  echo "----------------------------------------------------------------------------"
  for i in 0 1 2 3 4
  do
    BULLSEYE=$(dartutil "$DIRECTORY/replica_DB/node$i/dart.drt" --eye)
    echo "node$i| $BULLSEYE"
  done
  
else
  cp -r "$DART_DIR/DC_DB/" $DIRECTORY 
  # mkdir -p "$DIRECTORY/DC_DB_at_District_Centres"
  # mv "$DIRECTORY"/data/* "$DIRECTORY/DC_DB_at_District_Centres"
  echo "----------------------------------------------------------------------------"
  for i in 0 1 2 3 4
  do
    BULLSEYE=$(dartutil "$DIRECTORY/DC_DB/node$i/dart.drt" --eye)
    echo "node$i| $BULLSEYE"
  done
fi

# Clean up
# rm -rf "$DIRECTORY"/data/
