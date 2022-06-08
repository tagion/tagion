#!/bin/bash
if [[ -f "$1" ]]; then
source $1
echo stop $PID
kill $PID || true > /dev/null
sleep 0.2
kill $PID || true > /dev/null
fi
