# Tagion

> 🚧 This document is still in development.

👋 Welcome to the Tagion project! 

This repository is a home for all core units, also containing scripts for cross-compilation, testing and docs generation.


## Installation
*Installation tested on ubuntu 20.04*
### Needed packages

* ```dmd``` - see installation instructions here: https://dlang.org/download.html
* make, autoconf, golang, screen, clang, libclang-dev, libtool. Can be installed with: ```sudo apt-get install make screen autoconf golang clang libclang-dev libtool```
* dstep - follow the installation instructions here: https://github.com/jacob-carlborg/dstep *remember to add dstep to path.

Now you should be able to run ```make unittest```


## Overview

```bash
./docs/ # Development flow docs

./src/
     /lib-* # Library source code
     /bin-* # Executable source code
     /wrap-* # Vendor library compilation scripts

./tub # Build flow scripts
./Makefile # Pre-build Make file
```
### Tools 
[See tools](src/bin-tools/tagion/tools/README.md)

### BDD-test tools
[BDD-tool](src/bin-behaviour/tagion/tools/README.md)
### Unit types

#### Library
**Prefix:** `lib`

Contains business logic covered by unit tests, compiles to the static or shared library;

#### Binary
**Prefix:** `bin`

Contains CLI interface to libraries, compiles to executable;

#### Wrapper
**Prefix:** `wrap`

Contains external libraries integrated in Tagion build system compiles to the static or shared library.

## Maintainers

- [@cbleser](https://github.com/cbleser)
- [@vladpazych](https://github.com/vladpazych)
