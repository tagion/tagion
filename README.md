[![codecov](https://codecov.io/gh/tagion/tagion/branch/current/graph/badge.svg?token=TM12EX8GSB)](https://codecov.io/gh/tagion/tagion)
[![CI](https://github.com/tagion/tagion/actions/workflows/main.yml/badge.svg?branch=current)](https://github.com/tagion/tagion/actions/workflows/main.yml)
[![Dev uptime](https://img.shields.io/badge/dynamic/json?label=dev_uptime&query=$.age&url=https://pulse.tagion.org/tagion/api/v1/data)](https://pulse.tagion.org/tagion/)

# Tagion

> 🚧 This document is still in development. Some things may be out of date or incomplete

👋 Welcome to the Tagion project! 

This repository is a home for all core units, also containing scripts for cross-compilation, testing and docs generation.

[Documentation](https://docs.tagion.org)
[DDOC](https://ddoc.tagion.org)

## Installation
*Installation tested on ubuntu 22.04, archlinux from 17/05/23*

### Setup steps & preflight checks

1. Make sure that you have add your ssh keys to your github profile

Follow this guide:  
https://docs.github.com/en/authentication/connecting-to-github-with-ssh/generating-a-new-ssh-key-and-adding-it-to-the-ssh-agent

2. First of all please be sure that you have everything, command
You can run the following command as root, if you are using arch or ubuntu
    
```bash
# Ubuntu
apt-get install make screen autoconf golang clang libclang-dev libtool libssl-dev perl dub
# Arch
pacman -Syu make screen autoconf go clang libtool perl dub
```
    
3. Choose a D compiler ldc2 or dmd
        
- LLVM D compiler - ldc2 (latest working version is 1.29)
```bash
wget https://github.com/ldc-developers/ldc/releases/download/v1.29.0/ldc2-1.29.0-linux-x86_64.tar.xz
tar xf ldc2-1.29.0-linux-x86_64.tar.xz
export PATH="path-to-ldc2/ldc2-1.29.0-linux-x86_64/bin:$PATH"
```
        
- Reference D compiler - dmd
```bash
wget https://downloads.dlang.org/pre-releases/2.x/2.102.0/dmd.2.102.0-rc.1.linux.tar.xz
tar xf dmd.2.102.0-rc.1.linux.tar.xz
export PATH="path-to-dmd2/dmd2/linux/bin64:$PATH"
```

4. dstep download release binaries (or follow build instruction from https://github.com/jacob-carlborg/dstep)
    
```bash
wget https://github.com/jacob-carlborg/dstep/releases/download/v1.0.0/dstep-1.0.0-linux-x86_64.tar.xz
tar xf dstep-1.0.0-linux-x86_64.tar.xz
# Then copy the executable to a directory searched by your path, like the path you added when you set up your compiler
```
    
5. Verify that the binaries are available and check their version (comments showing versions used as of writing)
    
```bash
dstep --version # 1.0.0
ldc2 --version # LDC - the LLVM D compiler (1.29.0): ...
dmd --version
go version # go version go1.19.5 linux/amd64
```

6. Cloning tagion repo

```bash
git clone git@github.com:tagion/tagion.git
```

### Compiling

1. Running unittests

```bash
make unittest
```

2. Compiling binaries

```bash
make tagion
make install
# Will install to dir specified by INSTALL=/path/to/dir
# This directory should also be in your PATH variable
# such that you can use the tools from you shell
```

3. Compile binaries and running network in mode0

```bash
make mode0
```

4. General info about build flow

```bash
# Help info
make help
# or
make help-<topic>

# Info about environment variables
make env
# or
make env-<topic>
```

5. Compilation options, can be specified on the commandline or in a `local.mk` in the project root

```bash
# Showing the default values
WOLFSSL=1 # Use wolfssl as ssl implementation, otherwise use openssl
ONETOOL=1 # Everything is statically linked in to a single executable
          # and individual tools are symbolic links to that binary
OLD=1     # Uses and old transaction system
DC=       # D compiler to use, default will try to pick between dmd and ldc2
CC=       # C compiler to use, default will try to pick between gcc and clang
```

### Profiling 

Profiling can be enabled in two way.

#### Buildin profiler
Enable the dmd build profiler with the `PROFILE` environment.
```bash
make PROFILE=1 DC=dmd <target>
```
The result of the profile can be sorted and displayed with the `tprofile` (onetool).


#### Profiling Valgrind
Valgrind profiler can be started with the `VALGRIND` environment.

Run the unittest with [valgrind](https://valgrind.org) and [callgrind](https://valgrind.org/docs/manual/cl-manual.html).
```bash
make VALGRIND=1 unittest
```
Any of the test/bdd target can be executed with the `VALGRIND=1`.

Note. The result from the `callgrind` viewed with [Kcachegrind](https://kcachegrind.github.io/html/Home.html).


## Overview

```bash
./documents/ # Development flow docs

./src/
     /lib-* # Library source code
     /bin-* # Executable source code
     /wrap-* # Vendor library compilation scripts

./bdd/ # behaviour driven tests
./tub/ # Build flow scripts
./Makefile # Pre-build Make file
./integration # High level integration services
```

## Generating Docs
### Installation
You have to install docsify globally.
```
npm i docsify-cli -g
```
### Building the docs
To build the docs use the command:

```
make ddoc
```

### Running the document servers

```
make servedocs
```

This will start two servers ( default 3000 and 3001 ), with each of them running the different servers.
### Tools 
[See tools](src/bin-tools/tagion/tools/README.md)

### Tagion Node Architecture
The [Tagion Node Architecture](https://docs.tagion.org)

### BDD-test tools
[BDD-tool](src/bin-collider/tagion/tools/README.md)


## Maintainers

- [@cbleser](https://github.com/cbleser)
- [@vladpazych](https://github.com/vladpazych)
