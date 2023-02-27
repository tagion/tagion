# Tagion

> 🚧 This document is still in development.

👋 Welcome to the Tagion project! 

This repository is a home for all core units, also containing scripts for cross-compilation, testing and docs generation.

<a href="/docs/ActorException.html">ActorException</a>

[Actor documentation](ddoc://tagion.actor.Actor.html)  
[Actor source](src://lib-actor/tagion/actor/Actor.d)  

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

### Runnning the document servers

```
make servedocs
```

This will start two servers ( default 3000 and 3001 ), with each of them running the different servers.
### Tools 
[See tools](src/bin-tools/tagion/tools/README.md)

### Tagion Node Architecture
The [Tagion Node Architecture](documents/architecture/Network_Architecture.md)

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
