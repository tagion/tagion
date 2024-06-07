#!/usr/bin/env bash

# Update nng subtree's

set -xe
cd $(git rev-parse --show-toplevel)
git subtree pull --prefix=src/lib-libnng/ git@github.com:tagion/libnng.git master
git subtree pull --prefix=src/lib-nngd/ git@github.com:tagion/nng.git master
cd -
