#!/usr/bin/env bash

# Define the directory path
DIRECTORY="/tmp/test"
rm -rf $DIRECTORY
mkdir -p $DIRECTORY

CONTAINER_ID="$1"
docker cp "$CONTAINER_ID:/opt/tagion/nodes/node-master/data/" "$DIRECTORY"



# Check if the "--old" argument is provided

mkdir -p "$DIRECTORY/replica_db"
mv "$DIRECTORY"/data/* "$DIRECTORY/replica_db"
echo "----------------------------------------------------------------------------"
for i in 0 1 2 3 4
do
  BULLSEYE=$(dartutil "$DIRECTORY/replica_db/node$i/dart.drt" --eye)
  echo "node$i| $BULLSEYE"
done

# Clean up
rm -rf "$DIRECTORY"/data/
