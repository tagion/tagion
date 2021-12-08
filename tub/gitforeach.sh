#!/usr/bin/env bash

while [[ $(pwd) != / ]]; do
    ROOT=$(find "$(pwd)"/ -maxdepth 1 -name ".root")

    if [[ -z "$ROOT" ]]; then
        cd ..
    else
        ORIGIN_PATH=$(pwd)
        break
    fi
done

if [[ -z "$ORIGIN_PATH" ]]; then
    echo "No .root found in parent directories."
    echo "Make sure you have .root file in the root of your project."
    exit
fi

if [ "$1" == "dirty" ]; then
    MODE_DIRTY=1
fi

echo "Project: $ORIGIN_PATH"
echo "Showing $1 submodules"
echo

C=''
for i in "${@:2}"; do 
    i="${i//\\/\\\\}"
    C="$C \"${i//\"/\\\"}\""
done

function show_output() {
    echo -e "\033[1m$DIR\033[0m"
    bash -c "git $C"
    echo
}

SUBMODULES=$(git config --file .gitmodules --get-regexp path | awk '{ print $2 }')

for DIR in $SUBMODULES; do
    cd "$ORIGIN_PATH/$DIR/"

    if [[ -z "$MODE_DIRTY" ]]; then
        show_output
    else
        if [[ $(git diff --stat) != '' ]]; then
            show_output
        fi
    fi

done
