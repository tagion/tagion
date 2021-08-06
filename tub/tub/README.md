# Tagil

Tagil stands for **Tagi**on **l**ab, it's a build system for Tagion core libraries and binaries. Tagil is based on [GNU Make](https://www.gnu.org/software/make/).

You can use [Tagil CLI](https://github.com/tagion/tagil-cli) for better developer experience.

## Initialize Tagil Project

### Using [curl](https://curl.se/):

Install into current directory:

```bash
sh <(curl -s https://raw.githubusercontent.com/tagion/tagil/master/scripts/install.sh)
```

Install into [project-name]:

```bash
sh <(curl -s https://raw.githubusercontent.com/tagion/tagil/master/scripts/install.sh) project-name
```

### Using [wget](https://www.gnu.org/software/wget/):

Install into current directory:

```bash
sh <(wget -qO - https://raw.githubusercontent.com/tagion/tagil/master/scripts/install.sh)
```

Install into [project-name]:

```bash
sh <(wget -qO - https://raw.githubusercontent.com/tagion/tagil/master/scripts/install.sh) project-name
```

## Get Help

Get list of available commands with:

```bash
make help
```

## Install Depencies

Tagil, as a build system, works with Linux and macOS. The preferred distribution is Ubuntu 20.04.2.0 LTS (Focal Fossa).

At the moment, there is no cross-compilation flow, meaning you can only compile to your host machine's architecture.

Make sure to install dependencies:

- [ldc2](https://github.com/ldc-developers/ldc) as main D compiler
- [libgmp3-dev](https://packages.ubuntu.com/bionic/libgmp3-dev)
- [libssl-dev](https://packages.ubuntu.com/bionic/libssl-dev)
- [dstep](https://github.com/jacob-carlborg/dstep) for `core-wrap-p2p-go-wrapper`
- [golang](https://golang.org/doc/install#download) for `core-wrap-p2p-go-wrapper`
- [dh-autoreconf](https://packages.ubuntu.com/bionic/dh-autoreconf) for `core-wrap-secp256k1`

If you plan contributing to the Tagion Origin:

- [nodejs](https://packages.ubuntu.com/bionic/libgmp3-dev)
- [meta-git](https://github.com/mateodelnorte/meta-git)

## Understand Tagion's Modular Structure

Tagion core is split into modules, that follow the naming convention:

- `core-lib-[library]`: library module, compiles to `libtagion[library].a`
- `core-bin-[binary]`: binary module, compiles to `[binary]`
- `core-wrap-[wrapper]`: external library wrapper module, compiles to `lib[wrapper].a`

## How to Compile Tagion Library

### Add Modules

```bash
# make add/lib/[core lib name] adds library module
# make add/bin/[core lib name] adds binary module
# make add/wrap/[core lib name] adds external library wrapper module

make add/lib/basic # Will add core-lib-basic to ./src/libs/basic
make add/lib/utils # Will add core-lib-utils to ./src/libs/utils

# utils depends on basic
```

### Compile `core-lib-utils`

```bash
make lib/utils
```

### Run Unit Tests

```bash
make test/lib/utils
```

## How to Use Meta Git

> Will be replaced with Tagil CLI soon.

Since Tagion core modules live in separate repositories, we recommend using [meta-git](https://github.com/mateodelnorte/meta-git) (CLI from NPM) to perform operations on multiple repositories at once:

### Start With Predefined Modules

```bash
# If you have access to private core repositories:
make meta/core
# If you do not:
make meta/public

meta git update # To clone the missing repositories
```

### Add Modules

```bash
meta project import src/[type]/[name] git@github.com:tagion/core-[type]-[name]

# For example:
meta project import src/lib/basic git@github.com:tagion/core-lib-basic
```

### Branch With Meta

With meta-git you can checkout and branch all you repositories at once:

```bash
meta git checkout 1.1.alpha # Checkout desired alpha branch
meta git branch 1.1.jd # Create your working branch
```

---

## Versioning

**Alpha** and **Beta** versions consist only of two digits: `1.0.alpha`, `1.5.beta` or `2.3.alpha`.

Stable versions have normal [semver](https://semver.org/) specification: `1.0.1` or `2.3.4`.

New set of features always starts with **alpha** version. When the work is done, it is promoted to **beta** and is closed for any modifications except big fixes.

After **beta** version passed all automatic and manual tests, it is promoted to stable version, e.g., `2.3.0`. At this stage, only patches are allowed, and every patch must increment thrid digit, e.g., `2.3.1`.

## Branching

Before you modify anything, you branch from a specific version and create a branch with your identifier, e.g., `1.0.jd`, `1.4.peppa`.

- If you branch from `1.0.alpha`, your working branch must be named `1.0.vp`.
- If you branch from stable `1.5.8`, you working branch must be named `1.5.8.vp`.

**Important!** You only branch from **stable** or **beta** branches to make a patch. All new features, or refactors must be initiated from **alpha** branches.

## Troubleshooting

> To report a bug or request a feature, [create an issue](https://github.com/tagion/tagil/issues/new). As problems appear, we will add solutions to this section.

### No rule to make target

It means you don't have the required dependency.

1. Define the type of dependency: `lib` or `wrap`
1. Do `make add/lib/[library]` or `make add/wrap/[wrapper]`

Try to compile again.

## Roadmap

- [x] Tagion module compilation script
- [x] Introduction guide
- [x] Tagil install script
- [ ] Module dependency graph
- [ ] Cross compilation flow
- [ ] Replace `meta-git` with `tagil` cli

## Maintainers

- [@vladpazych](https://github.com/vladpazych)
