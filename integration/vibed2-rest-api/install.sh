#!/usr/bin/env bash

mkdir -p ~/.local/share/dart_api
mkdir -p ~/.config/systemd/user
cp vibed2-project ~/.local/share/dart_api
cp dart_api.service ~/.config/systemd/user
systemctl --user daemon-reload

echo "restart the service with: systemctl restart --user dart_api"
