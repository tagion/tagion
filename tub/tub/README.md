# Tub

Tub stands for **T**agion **u**nit **b**uilder, it's a build system for Tagion core libraries and binaries. Tub consists of [GNU Make](https://www.gnu.org/software/make/) files.

Since Tagion core is split to many independent repositories, we recomment using [Rex](https://github.com/tagion/rex) to run any commands in all modules of current working directory.

## Getting Started

### Install Dependencies

Tub was tested on **Ubuntu 20.04.2.0 LTS** (Focal Fossa) and **macOS Catalina**.

> **Impoartant!** At the moment, there is no cross-compilation flow, meaning you can only compile to your host machine's architecture.

Make sure to install dependencies:

- GNU Make > 3.82
- [ldc2 1.26.0](https://github.com/ldc-developers/ldc/releases/tag/v1.26.0) as main D compiler
- [libgmp3-dev](https://packages.ubuntu.com/bionic/libgmp3-dev)
- [dstep](https://github.com/jacob-carlborg/dstep) for `p2p-go-wrapper`
- [golang](https://golang.org/doc/install#download) for `p2p-go-wrapper`
- [dh-autoreconf](https://packages.ubuntu.com/bionic/dh-autoreconf) for `secp256k1`

### Install Tub

```bash
cd <project-dir>
git clone git@github.com:tagion/tub.git

./tub/root
```

> Keep in mind, that **make scripts** in **tub** are meant to run from your root project directory, and not from `./tub` directory.

### Compile

Before compiling, you must run `make configure`. Every time you create, rename or delete a file, you must run `make configure`.

---

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

## Create New Unit

If you want to create another executable or a new library, you must ensure tub-compatible structure.

### Types of Units

|                 | Executables | Libraries | Wrappers    |
| --------------- | ----------- | --------- | ----------- |
| Prefix          | `bin-`      | `lib-`    | `wrap-`     |
| Unit tests      | not allowed | allowed   | not allowed |
| Business logic  | not allowed | allowed   | not allowed |
| Interface logic | CLI         | `export`  | not allowed |

### Structure

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

## Actions

- 🐞 [Report a bug](https://github.com/tagion/tub/issues/new)
- 🔺 [Request a feature](https://github.com/tagion/tub/issues/new)
- 🛣 [Visit the roadmap](https://github.com/tagion/tub/projects/1)
- 📚 [Read dev's manual](https://github.com/tagion/manual)

## Maintainers

- [@vladpazych](https://github.com/vladpazych)
