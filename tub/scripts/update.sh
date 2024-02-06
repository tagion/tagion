#!/usr/bin/env bash

usage() { echo "Usage: $0 <version tage>" 1>&2; exit 1;}

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
# wget "$release_url"
# unzip "$artifact_name"
# tar xzf *.tar.gz

echo
echo "old: $(tagion --version | head -1)"
echo "new: $(./build/x86_64-linux/bin/tagion --version | head -1)"

prompt "Confirm upgrade from old version to new?"

loginctl enable-linger

cd ./build/x86_64-linux/bin
export DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1001/bus
export XDG_RUNTIME_DIR=/run/user/1001

cp run_network.sh ~/.local/share/tagion/wave/
cp failed.sh ~/.local/share/tagion/wave/
cp tagion ~/.local/bin/
~/.local/bin/tagion -s
cp tagionshell.service neuewelle.service ~/.config/systemd/user
echo "Deploying revision" 
~/.local/bin/tagion --version

systemctl --user daemon-reload
