#!/usr/bin/env sh

# Should be run from a package archive

user_install() {
    INSTALL=${INSTALL:-${HOME}/.local/bin}
    mkdir -p "$INSTALL"
    install -m +x bin/tagion "$INSTALL"
    "$INSTALL/tagion" -s
}

user_install
