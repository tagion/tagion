#!/bin/bash

dmd -od=build/tmp $(find src -maxdepth 1 -type d -path "src/lib-*" |awk '{print "-I="$1}' |tr '\n' ' ') -O -d -m64 -i -L-lnng  $1 $2 $3 
