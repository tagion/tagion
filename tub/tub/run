#!/usr/bin/env bash

while [[ $(pwd) != / ]] ; do
    TUBROOT=$(find "$(pwd)"/ -maxdepth 1 -name "tubroot")
    if [[ -z "$TUBROOT" ]] ; then
    cd ..
    else
    ORIGIN_PATH=$(pwd)
    break
    fi
done

if [[ -z "$ORIGIN_PATH" ]] ; then
echo "No tubroot found in parent directories."
echo "Make sure you have tubroot file on the same level as 'src' of your project."
exit
fi

echo
echo "You are in project: $ORIGIN_PATH"
echo

for DIR in $(ls src); do
    echo -e "\033[1m$DIR\033[0m"
    
    cd "$ORIGIN_PATH/src/$DIR/";
    C=''
    for i in "$@"; do 
        i="${i//\\/\\\\}"
        C="$C \"${i//\"/\\\"}\""
    done
    bash -c "$C"

    echo 
done