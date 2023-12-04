#!/bin/bash

k=1

while true; 
do 
curl -s --output res http://localhost:8088/api/v1/time
#curl -s --output res  -X "POST" -d "{\"todo\":\"time\"}" http://localhost:8088/api/v1
echo "-- ${k}" 
k=$((k+1)) 
done

