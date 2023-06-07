Cross compiling mobile library for android from Ubuntu 22.10 x86_64

Install the following tools

```sh
# apt-get update
# apt-get install make screen autoconf libtool wget xz-utils unzip git
```

Also install dstep
as described in the README

```sh
wget https://github.com/jacob-carlborg/dstep/releases/download/v1.0.0/dstep-1.0.0-linux-x86_64.tar.xz
tar xf dstep-1.0.0-linux-x86_64.tar.xz
# Then copy the executable to a directory searched by your path, like the path you added when you set up your compiler
```


Create a working directory to house your files
```sh
mkdir dondroid
cd dondroid
```

Install the host D compiler

```sh
wget https://github.com/ldc-developers/ldc/releases/download/v1.29.0/ldc2-1.29.0-linux-x86_64.tar.xz
tar xf ldc2-1.29.0-linux-x86_64.tar.xz
export PATH="/path/to/ldc2-1.29.0-linux-x86_64/bin:$PATH"
```

Download the target compiler files (We need the precompiled runtime and std library)

```sh
wget https://github.com/ldc-developers/ldc/releases/download/v1.29.0/ldc2-1.29.0-android-aarch64.tar.xz
tar xf ldc2-1.29.0-android-aarch64.tar.xz
```

Download the android NDK toolchain
```sh
wget https://dl.google.com/android/repository/android-ndk-r21b-linux-x86_64.zip
unzip android-ndk-r21b-linux-x86_64.zip
```

Copy ldc2 configuration
```sh
cp /path/to/tagion_source/tub/ldc2.conf ldc2-1.29.0-linux-x86_64/etc/ldc2.conf
```

Compile the mobile library in the root of the tagion source repo
```sh
make prebuild
make DC=ldc2 ANDROID_NDK=/path/to/android-ndk-r21b/ PLATFORM=aarch64-linux-android libmobile
```
