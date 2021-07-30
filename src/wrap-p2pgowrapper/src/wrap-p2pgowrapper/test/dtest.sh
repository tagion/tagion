#!/bin/bash
for (( c=1; c<=5; c++ ))
do
    gnome-terminal -- ./dtest --port=400$c -l
done