# Cross compiling iOS

Tagion libmobile is a subset of the tagion modules which can be cross compiled for iOS.
Compilation for iOS is only supported with OSX/MacOS as a host.


## Setup

1. Install build tools using brew  
*Some tools like `make` are already distributed with OSX, but they're too old and will not work.*  

```
brew install autoconf libtool m4 automake make pkg-config ldc
```

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
Cross compiling from one architecture to another is not supported. Eg from x86-64 to arm64
:::

```
arm64-apple-ios
arm64-apple-ios-simulator
x86-64-apple-ios
x86-64-apple-ios-simulator
```
