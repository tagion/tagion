# Tub

> 🚧 This document is still in development.

Tub stands for **T**agion **u**nit **b**uilder, it's a build system for Tagion core libraries and binaries, and is meant to build Tagion units from source. Tub consists of [GNU Make](https://www.gnu.org/software/make/) files, `bash` and `d` scripts.

## Getting started

Tub was tested in **Ubuntu 20.04.2.0 LTS** (Focal Fossa) and **macOS Catalina**.

> 🧐 **Keep in mind**  
> At the moment, there is no cross-compilation flow, meaning you can only compile to your host machine's architecture.

### Installing dependencies

- GNU Make 3.82+
- [ldc2 1.26.0](https://github.com/ldc-developers/ldc/releases/tag/v1.26.0) as main D compiler
- [libgmp3-dev](https://packages.ubuntu.com/bionic/libgmp3-dev)
- [dstep](https://github.com/jacob-carlborg/dstep) for `p2p-go-wrapper`
- [golang](https://golang.org/doc/install#download) for `p2p-go-wrapper`
- [dh-autoreconf](https://packages.ubuntu.com/bionic/dh-autoreconf) for `secp256k1`

### Installing Tub

```bash
# Clone the directory
cd <project-dir>
git clone git@github.com:tagion/tub.git

# Root the tub into project
./tub/root 
```

> You should run tub scripts from **root project directory**, not from **tub directory**.

### Compiling

Before compiling, you must run `make configure` to ensure necessary files are generated. 

> Every time you create, rename or delete a file, you must run `make configure`.

#### Examples

To comile `core-lib-basic`:

```bash
make clone-lib-basic BRANCH=master
make configure
make libbasic
```

To comile `core-bin-hibonutil`:

```bash
make clone-bin-hibonutil BRANCH=master
make configure
make tagionhibonutil
```

## Creating new unit

If you want to create another executable or a new library, you must ensure tub-compatible structure.

### Types of units

|                 | Executables | Libraries | Wrappers    |
| --------------- | ----------- | --------- | ----------- |
| Prefix          | `bin-`      | `lib-`    | `wrap-`     |
| Unit tests      | not allowed | allowed   | not allowed |
| Business logic  | not allowed | allowed   | not allowed |
| Interface logic | CLI         | `export`  | not allowed |

### Unit structure

All units must have `context.mk` with structure similar to the following:

```make
# lib-dart unit

# Units that must be present for this unit to compile
DEPS += lib-crypto
DEPS += lib-communication

PROGRAM := libdart

DARD_DIFILES := ${call dir.resolve, tagion/c/secp256k1_ecdh.di}

# Depend on header files on preconfigure step
$(PROGRAM).preconfigure: $(DARD_DIFILES)

# Define SOURCE - where to look for sources
# Keep in mind, if no .d files found in the specified dirs,
# Make will throw an error.
$(PROGRAM).configure: SOURCE := tagion/**/*.d

# Specify external libraries to link for
# unit test binary:
$(DBIN)/$(PROGRAM).test: $(DTMP)/libsecp256k1.a
$(DBIN)/$(PROGRAM).test: $(DTMP)/libssl.a
```

## Maintainers

- [@cbleser](https://github.com/cbleser)
- [@vladpazych](https://github.com/vladpazych)
