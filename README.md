[![codecov](https://codecov.io/gh/tagion/tagion/branch/current/graph/badge.svg?token=TM12EX8GSB)](https://codecov.io/gh/tagion/tagion)
[![CI](https://github.com/tagion/tagion/actions/workflows/main.yml/badge.svg?branch=current)](https://github.com/tagion/tagion/actions/workflows/main.yml)

# Tagion

> 🚧 This document is still in development. Some things may be out of date or incomplete

👋 Welcome to the Tagion project! 

Tagion is a decentralized ledger for creating high volume transaction.
It differs from blockchain based ledgers in that it uses a hashgraph as the consensus mechanism and a database based on a merkletree (DART) to store the bills of the system.
Thus it does not need to record the entire transaction history to maintain integrity, only the state of world is recorded.

General system documentation https://docs.tagion.org  
Code documentation https://ddoc.tagion.org  
Whitepaper https://www.tagion.org/resources/tagion-whitepaper.pdf  

## Installation
*Installation tested on ubuntu 22.04, nixos-unstable*

### Setup steps & preflight checks

1. First of all please be sure that you have everything, command
You can run the following commands, if you are using arch, nix or ubuntu
    
- **Ubuntu**

```bash
apt-get install git autoconf build-essential libtool dub cmake
```
Download a D compiler ldc or dmd

- LLVM D compiler - ldc2 (v1.35.0)
```bash
wget https://github.com/ldc-developers/ldc/releases/download/v1.35.0/ldc2-1.35.0-linux-x86_64.tar.xz
tar xf ldc2-1.35.0-linux-x86_64.tar.xz
export PATH="path-to-ldc2/ldc2-1.34.0-linux-x86_64/bin:$PATH"
```
        
- Reference D compiler - dmd (v2.105.2)
```bash
wget https://downloads.dlang.org/releases/2.x/2.105.2/dmd.2.105.2.linux.tar.xz
tar xf dmd.2.105.2.linux.tar.xz
export PATH="path-to-dmd2/dmd2/linux/bin64:$PATH"
```

- **Arch**

```bash
pacman -Syu git make autoconf gcc libtool dlang cmake
```

- **Nix**

```bash
nix develop
```

2. Verify that the binaries are available and check their version (comments showing versions used as of writing)
    
```bash
ldc2 --version # LDC - the LLVM D compiler (1.35.0): ...
dmd --version # v2.105.2
```

3. Cloning tagion repo

```bash
git clone git@github.com:tagion/tagion.git
```

### Compiling

1. Running tests

```bash
make test
```

2. Compiling binaries

```bash
make tagion
make install
# Will install to dir specified by INSTALL=/path/to/dir
# This directory should also be in your PATH variable
# such that you can use the tools from you shell
```

3. General info about build flow

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

4. Compilation options, can be specified on the commandline or in a `local.mk` in the project root

Notice that if you choose to compile with ldc there is a bug which means that the unittests wont run.

```bash
# Showing the default values
ONETOOL=1 # ALL tools linked in to a single executable
          # and individual tools are symbolic links to that binary
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
     /fork-* # Vendor library compilation scripts
./bdd/ # behaviour driven tests
./tub/ # Build flow scripts
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
- [@lucasnethaj](https://github.com/lucasnethaj)
- [@imrying](https://github.com/imrying)

## License
The files in this repository is distributed under the [DECARD Services GmbH free and grant back license](LICENSE.md)  
unless otherwise specified.  
The parts which are distributed under other licenses include, but are not limited to the 
[pbkdf2](src/lib-crypto/tagion/crypto/pbkdf2.d) module and the translated [secp256k1 headers](src/lib-crypto/tagion/crypto/secp256k1/c/README.md)  
