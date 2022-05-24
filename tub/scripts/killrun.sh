#!/bin/bash
source $1
echo stop $PID
kill $PID
sleep 0.2
kill $PID
