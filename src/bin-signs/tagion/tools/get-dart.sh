#!/usr/bin/env bash
CONTAINER_ID="$1"
docker cp "$CONTAINER_ID:/opt/tagion/nodes/node-master/data/node0/dart.drt" "/tmp/dart.drt"
