#!/bin/sh

DIR_INSTALL=$1

echo

if [ -z "$DIR_INSTALL" ];
then
DIR_INSTALL=./
echo "Project path: $(pwd)/"
else
echo "Project path: $(pwd)/$DIR_INSTALL"
mkdir -p $DIR_INSTALL && cd $DIR_INSTALL
fi

echo

echo "------------------------------"
git clone git@github.com:tagion/tub.git 
ln -s ./tub/Makefile ./
mkdir -p build
mkdir -p src
mkdir -p wraps
echo "------------------------------"

echo
echo "Your Tagion lab is successfully installed. "
echo "Have fun ;)"
echo