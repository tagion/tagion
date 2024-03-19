#!/usr/bin/env bash

usage() { echo "Usage: $0 <version tag>" 1>&2; exit 1;}

prompt() {
    text=$1
    read -p "$text (Y/n) " yn
    
    if [[ -z "$yn" ]]; then
        yn="y"
    fi

    case $yn in 
        [Yy]* ) echo "Proceeding...";;
        [Nn]* ) echo "Exiting..."; exit;;
        * ) echo "Invalid response";;
    esac
}

version=$1
artifact_name="successful_artifact.zip"
release_url="https://github.com/tagion/tagion/releases/download/$version/$artifact_name"

if [[ -z "$version" ]]; then
    usage
fi

prompt "Stop shell service?"
systemctl stop --user tagionshell

prompt "Stop neuewelle service?"
systemctl stop --user neuewelle


mkdir -p "$version"
cd "$version"

echo "Downloading $release_url to $PWD/$artifact_name"
wget "$release_url"
unzip "$artifact_name"
tar xzf *.tar.gz

echo
echo "old: $(tagion --version | head -1)"
echo "new: $(./build/x86_64-linux/bin/tagion --version | head -1)"

prompt "Confirm upgrade from old version to new?"

loginctl enable-linger

export INSTALL=~/.local/bin
(cd ./build/x86_64-linux/bin
    mkdir -p "$INSTALL"
    make install
)

echo "Deploying revision" 
"$INSTALL/tagion" --version

systemctl --user daemon-reload

cd ~/.local/share/tagion/

dbs=$(ls wave/Node_*_dart.drt)
for db in $dbs; do
    dartutil --eye $db
done
