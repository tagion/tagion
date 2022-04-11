# Tagion

> 🚧 This document is still in development.

👋 Welcome to the Tagion project! 

This repository is a home for all core units, also containing scripts for cross-compilation, testing and docs generation.

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
