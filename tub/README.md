# Tub

> 🚧 This document is still in development.

Tub stands for **T**agion **u**nit **b**uilder, it's a build system for Tagion core libraries and binaries, and is meant to build Tagion units from source. Tub consists of [GNU Make](https://www.gnu.org/software/make/) files, `bash` and `d` scripts.

## Getting started

Tub was tested in **Ubuntu 20.04.2.0 LTS** (Focal Fossa) and **macOS Catalina**.

> 🧐 **Keep in mind**  
> At the moment, there is no cross-compilation flow, meaning you can only compile to your host machine's architecture.

## Creating new unit

If you want to create another executable or a new library, you must ensure tub-compatible structure.

### Types of units

|                 | Executables | Libraries | 3rdParty    |
| --------------- | ----------- | --------- | ----------- |
| Prefix          | `bin-`      | `lib-`    | `fork-`     |
| Unit tests      | not allowed | allowed   | not allowed |

### Unit structure

All units must have `context.mk` with structure similar to the following:

## Maintainers

- [@cbleser](https://github.com/cbleser)
