#!/usr/bin/env bash

# Define the directory path
DIRECTORY="/home/imrying/work/demo"

CONTAINER_ID="$1"
echo "Copying from $CONTAINER_ID:/opt/tagion/nodes/data"
docker cp "$CONTAINER_ID:/opt/tagion/nodes/node-master/data/" "$DIRECTORY"



# Check if the "--old" argument is provided
if [[ "$2" == "--old" ]]; then
  mkdir -p "$DIRECTORY/service_point"
  mv "$DIRECTORY"/data/* "$DIRECTORY/service_point"

else 
  mkdir -p "$DIRECTORY/new"
  mv "$DIRECTORY"/data/* "$DIRECTORY/new"
fi


# Clean up
rm -rf "$DIRECTORY"/data/
