# Cross compilling iOS

Tagion libmobile is a subset of the tagion modules which can be cross compiled for iOS.
Compilation for iOS is only supported with OSX as a host.


## Setup

1. Install the ldc v1.36 OSX multilib from https://github.com/ldc-developers/ldc/releases/tag/v1.36.0
and add it to your `$PATH`.

2. Install xcode. Make sure that xcode-select is available

```bash
xcode-select --version
```

## Build

```bash
make DC=ldc2 PLATFORM=arm64-apple-ios libmobile
```

## Available platforms 

:::info
Cross compiling from one architecture to another is not supported
:::

```
arm64-apple-ios
arm64-apple-ios-simulator
x86-64-apple-ios
x86-64-apple-ios-simulator
```
