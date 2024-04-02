#!/usr/bin/env bash
set -xe
cd $(git rev-parse --show-toplevel)
git subtree pull --prefix=src/lib-nngd/libnng/ git@github.com:tagion/libnng.git master
git subtree pull --prefix=src/lib-nngd/nngd/ git@github.com:tagion/nng.git master
cd -
