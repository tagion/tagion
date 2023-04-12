Cross compiling mobile library for android from Ubuntu 22.10 x86_64

Install the following tools

```console
# apt-get update
# apt-get install make screen autoconf libtool wget xz-utils unzip git
```

Create a working directory to house your files
```
mkdir dondroid
cd dondroid
```

Install the host D compiler

```
wget https://github.com/ldc-developers/ldc/releases/download/v1.29.0/ldc2-1.29.0-linux-x86_64.tar.xz
tar xf ldc2-1.29.0-linux-x86_64.tar.xz
export PATH="/path/to/ldc2-1.29.0-linux-x86_64/bin:$PATH"
```

Download the target compiler files (We need the precompiled runtime and std library)

```
wget https://github.com/ldc-developers/ldc/releases/download/v1.29.0/ldc2-1.29.0-android-aarch64.tar.xz
tar xf ldc2-1.29.0-android-aarch64.tar.xz
```

Download the android NDK toolchain
```
wget https://dl.google.com/android/repository/android-ndk-r21b-linux-x86_64.zip
unzip android-ndk-r21b-linux-x86_64.zip
```

Copy ldc2 configuration
```
cp /path/to/tagion_source/tub/ldc2.conf ldc2-1.29.0-linux-x86_64/etc/ldc2.conf
```

Compile the mobile library in the root of the tagion source repo
```
make -f noconf.android.mk DC=ldc2 ANDROID_NDK=/path/to/android-ndk-r21b/ PLATFORM=aarch64-linux-android libmobile
```
