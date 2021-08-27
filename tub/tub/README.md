# Tub

Tbu stands for **T**agion **u**nit **b**uilder, it's a build system for Tagion core libraries and binaries. Tub is based on [GNU Make](https://www.gnu.org/software/make/).

<!-- You can use [Tagil](https://github.com/tagion/tagil) for better developer experience. -->

## Getting Started

### Install Dependencies

Tub works with Linux and macOS. The preferred distribution is Ubuntu 20.04.2.0 LTS (Focal Fossa).

At the moment, there is no cross-compilation flow, meaning you can only compile to your host machine's architecture.

Make sure to install dependencies:

- [ldc2 1.26.0](https://github.com/ldc-developers/ldc/releases/tag/v1.26.0) as main D compiler
- [libgmp3-dev](https://packages.ubuntu.com/bionic/libgmp3-dev)
- [dstep](https://github.com/jacob-carlborg/dstep) for `p2p-go-wrapper`
- [golang](https://golang.org/doc/install#download) for `p2p-go-wrapper`
- [dh-autoreconf](https://packages.ubuntu.com/bionic/dh-autoreconf) for `secp256k1`

### 1. Install Tub

Use tub `install` script to install Tub in your local directory.

```bash
cd <project-dir>
git clone git@github.com:tagion/tub.git
./tub/install
```

#### Install using [curl](https://curl.se/) or [wget](https://www.gnu.org/software/wget/):

You can copy one of the commands below to install tub in your directory:

```bash
sh <(curl -s https://raw.githubusercontent.com/tagion/tub/master/install) project
sh <(wget -qO - https://raw.githubusercontent.com/tagion/tub/master/install) project
```

### 2. Initialize from blueprint

Once you have a clean tub, you have to choose which modules to work with. You can have very minimal local setup with few specific modules. But to make onboarding easier, we have prepared two blueprints. If you have access to private core modules, use:

```bash
make add/core
```

If you are an external contributor, use:

```bash
make add/public
```

### 3. Compile and test any available module

We use `make` for compilation. Here is you compile any tagion module:

```bash
make libtagionutils # Will compile a static library from core-lib-utils module
make tagionwave # Will compile an executable from core-bin-wave module
make wrap-secp256k1 # Will compile an external library from core-wrap-secp256k1
```

## Tagion's Modular Structure

Tagion core is split into modules, that follow the naming convention:

- `core-lib-[library]`: library module, compiles to `libtagion[library].a`
- `core-bin-[binary]`: binary module, compiles to `tagion[binary]`
- `core-wrap-[wrapper]`: wrapper for external libraries

## Tub script

Once you install `tub`, you will have `tub` script on your `PATH`, it will execute any command on each module in you `src` directory.

```bash
tub git checkout 0.1.alpha # Checkout specific alpha branch
tub git branch 0.1.jd # Create your working branch, if you are John Dorian
tub ls # List files and directories in every module
```

---

## Versioning

**Alpha** and **Beta** versions consist only of two digits: `1.0.alpha`, `1.5.beta` or `2.3.alpha`. We also have a shortcut `alpha` branch that always points to the latest alpha.

**Stable** versions have normal [semver](https://semver.org/) specification: `1.0.1` or `2.3.4`.

New set of features always starts with **alpha** version. When the work is done, it is promoted to **beta** and is closed for any modifications except big fixes.

After **beta** version passed all automatic and manual tests, it is promoted to **stable** version, e.g., `2.3.0`. At this stage, only patches are allowed, and every patch must increment thrid version digit, e.g., `2.3.1`.

## Branching

Before you modify anything, you must branch from a specific alpha version and name your branch according to your username, e.g., `1.0.jd` or `1.4.peppa`, ~~if you are a pig~~.

- If you branch from `1.0.alpha`, your working branch must be named `1.0.<jd>`.
- If you branch from stable `1.5.8`, you working branch must be named `1.5.8.<jd>`.

**Important!** You should only branch from **stable** or **beta** to make a patch. All new features, or refactors must be initiated from **alpha** branches.

## Troubleshooting

> To report a bug or request a feature, [create an issue](https://github.com/tagion/tub/issues/new). As problems appear, we will add solutions to this section.

### No rule to make target

It means you don't have the required dependency.

1. Define the type of dependency: `lib` or `wrap`
1. Do `make add/lib-[library]` or `make add/wrap-[wrapper]`

Try to compile again.

## Roadmap

- [x] Tagion module compilation script
- [x] Introduction guide
- [x] Tub install script
- [ ] Module dependency graph
- [ ] Cross compilation flow
- [x] Replace `meta-git` with `tub`

## Maintainers

- [@vladpazych](https://github.com/vladpazych)
