# Cross compiling Android 

Guide for cross compiling mobile library for android from Ubuntu 22.10 x86_64

## Install build tools
This is the subset of tools from the README used to compile the mobile android library

```sh
# apt-get update
# apt-get install make screen autoconf libtool git
```

## View Available target platforms

You can view which target android platforms are available with. 
As well as viewing the currently configured environment

```sh
make env-android
```

These platforms can be specified by setting the PLATFORM= variable


## Install android specific libraries and tools
there is an install script that will download the required tools to build

It will do 4 things
1. Download a ldc compiler for the host
2. Download a ldc compiler for the target platform, which includes the necessary libraries
3. Download the android ndk, which includes android specific c compiler and linkers
4. Configure the host compiler to use the android specific libraries and tools

```sh
make PLATFORM=aarch64-linux-android install-android-toolchain
```

## Buiding mobile lib

```sh
make PLATFORM=aarch64-linux-android libmobile
```


## Additional info
If you have installed the android ndk in a different location you may configure it with ANDROID_NDK=

```
ANDROID_NDK=tools/android-ndk-r21b/
```

The android target defaults to using the D compiler installed by the script.  
You have to override it if you want to use a different compiler.

```
DC=/path/to/my/ldc/bin
```

```sh
make help-android
```
