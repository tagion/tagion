#!/usr/bin/env bash

usage() { echo "Usage:[-a <artifact number>" 1>&2; exit 1;}

artifact_number=""

while getopts "h:a:" opt
do
  case $opt in
    h) usage ;;
    a) artifact_number=$OPTARG ;;
  esac
done

# Check if artifact number is set
if [ -z "$artifact_number" ]; then
  echo "Artifact number not provided"
  usage
  exit 1
fi

# Check if tagionshell service is running
if systemctl is-active --quiet --user tagionshell; then
    echo "Error: tagionshell service is running. Please stop the service before updating."
    exit 1
fi

# Check if neuewelle service is running
if systemctl is-active --quiet --user neuewelle; then
    echo "Error: neuewelle service is running. Please stop the service before updating."
    exit 1
fi

loginctl enable-linger moonbase
echo "Downloading artifact $artifact_number"
gh run download "$artifact_number" -n "successful_artifact" --repo "tagion/tagion"
ls
tar -xzf *.tar.gz

cd build/x86_64-linux/bin
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

