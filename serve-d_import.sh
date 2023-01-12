#!/usr/bin/env bash

REPO_DIR=$(git rev-parse --show-toplevel);
cd $REPO_DIR;

# Use the newest serve-d socket file
SOCKET_FILE=$(ls /tmp/workspace-d* | tail -1);
#echo $SOCKET_FILE;
IMPORT_PATH=$REPO_DIR/src/*;

IMPORTS=$(for P in $IMPORT_PATH; do echo -I="$P"; done);
IMPORTS+=" $REPO_DIR/bdd/";

# echo $IMPORTS;

dcd-client --socketFile=$SOCKET_FILE $IMPORTS;
