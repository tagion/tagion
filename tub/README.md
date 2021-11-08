# Tub

Tub stands for **T**agion **u**nit **b**uilder, it's a build system for Tagion core libraries and binaries. Tub consists of [GNU Make](https://www.gnu.org/software/make/) files.

Since Tagion core is split to many independent repositories, we recomment using [Rex](https://github.com/tagion/rex) to run any commands in all modules of current working directory.

## Getting Started

### Install Dependencies

Tub was tested on **Ubuntu 20.04.2.0 LTS** (Focal Fossa) and **macOS Catalina**.

> **Impoartant!** At the moment, there is no cross-compilation flow, meaning you can only compile to your host machine's architecture.

Make sure to install dependencies:

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
make init version-<version> # e.g. version-0.8.alpha
```

> Keep in mind, that **make scripts** in **tub** are meant to run from your root project directory, and not from `./tub` directory.

### Compile Units

Once you have `tubroot` and `local.branch.mk` (from install step), you can start compiling and testing core units available to you in [Tagion GitHub organization page](https://github.com/tagion?q=core-&type=&language=&sort=).

#### Compile Library

- All tagion library repos are named as `core-lib-<name>`;
- When compiling, you must specify `libtagion` prefix;

For this example, we will compile `core-lib-hibon`:

```bash
make libtagionhibon # Will compile a static library
make libtagionhibon TEST=1 # Will compile and run unit tests
```

### Compile Executable

- All tagion executable repos are named as `core-bin-<name>`;
- When you compile a tagion executable, you must specify `tagion` prefix;
- Unit tests are not supported for executable, since an executable must not contain any business logic and serve only as an interface into library.

For this example, we will compile `core-bin-hibonutil`:

```bash
make tagionhibonutil # Will compile an executable
```

### Compilation Configuration

We have multiple useful variable that control how the target is compiled:

```bash
# To regenerate dependency files, needed
# when you create or delete .d files:
make libtagionhibon DEPSREGEN=1

# To show tub debug information
make libtagionhibon MK_DEBUG=1
```

### Compilation Limitations

- Tub only meant to compile one target at a time, `make libtagionhibon tagionhibonutil` is not supported.
  
---

## Actions

- 🐞 [Report a bug](https://github.com/tagion/tub/issues/new)
- 🔺 [Request a feature](https://github.com/tagion/tub/issues/new)
- 🛣 [Visit the roadmap](https://github.com/tagion/tub/projects/1)
- 📚 [Read dev's manual](https://github.com/tagion/manual)

## Maintainers

- [@vladpazych](https://github.com/vladpazych)
