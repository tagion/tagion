---
sidebar_position: 1
---

# Developer Guides

## Setup

Install the required tools to build tagion
    
### Ubuntu

```bash
apt-get install git autoconf build-essential libtool dub cmake
```
Download a D compiler ldc or dmd

- LLVM D compiler - ldc2 (v1.37.0)
```bash
wget https://github.com/ldc-developers/ldc/releases/download/v1.37.0/ldc2-1.37.0-linux-x86_64.tar.xz
tar xf ldc2-1.37.0-linux-x86_64.tar.xz
export PATH="path-to-ldc2/ldc2-1.34.0-linux-x86_64/bin:$PATH"
```
        
- Reference D compiler - dmd (v2.107.1)
```bash
wget https://downloads.dlang.org/releases/2.x/2.107.1/dmd.2.107.1.linux.tar.xz
tar xf dmd.2.107.1.linux.tar.xz
export PATH="path-to-dmd2/dmd2/linux/bin64:$PATH"
```


### Arch

```bash
pacman -Syu git make autoconf gcc libtool dlang cmake
```


### Nix

```bash
nix develop
```

## Verify
For good measure verify that the tools you installed are available and the proper version.

```bash
ldc2 --version # LDC - the LLVM D compiler (1.37.0): ...
dmd --version # v2.107.1
```

## Clone repo

```bash
git clone git@github.com:tagion/tagion.git
cd tagion
```

## Compiling

```bash
make tagion
```

This will result in an tagion executable in `./build/(host-platform)/bin/tagion`

## Installing

You can install the executables in to the path specified by the `INSTALL` variable
The directory specified by `INSTALL` should be referenced in Your `PATH` variable.

```bash
make install INSTALL=~/.local/bin/
```
