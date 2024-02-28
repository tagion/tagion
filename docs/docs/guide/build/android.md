# Cross compiling Android 

Guide for cross compiling mobile library for android from Ubuntu 22.10 x86_64

## Install build tools
This is the subset of tools from the README used to compile the mobile android library

```sh
# apt-get update
# apt-get install make screen autoconf libtool git
```

## Install android specific libraries and tools
there is an install script that will download the required tools to build

It will do 4 things
1. Download a ldc compiler for the host
2. Download a ldc compiler for the target platform, which includes the necessary libraries
3. Download the android ndk, which includes android specific c compiler and linkers
4. Configure the host compiler to use the android specific libraries and tools

```sh
# The script will use these tools to install everything
# apt-get install wget xz-utils unzip make
make -j -f tub/scripts/setup_android_toolchain.mk LDC_TARGET=ldc2-1.29.0-android-aarch64
make -j -f tub/scripts/setup_android_toolchain.mk LDC_TARGET=ldc2-1.29.0-android-armv7a
# The x86_64 libraries are included and configured when downloading the aarch64 libraries
```

## Add the host ldc compiler to your path

```sh
export PATH="$PWD/tools/ldc2-1.29.0-linux-x86_64/bin/:$PATH/"
``` 

## Buiding mobile lib

```sh
make PLATFORM=aarch64-linux-android libmobile
make PLATFORM=armv7a-linux-android libmobile
make PLATFORM=x86_64-linux-android libmobile
```


## Additional info
If you have installed the android ndk in a different location you may configure it with ANDROID_NDK
```
ANDROID_NDK=tools/android-ndk-r21b/
```
