#!/usr/bin/env bash

FROM=$1
TO=$2

echo $FROM $TO

inotifywait -m -e create --format "ifiler $FROM/%f $TO -v" $FROM \
| while read line; do
    echo "$line"
    $line &
done
