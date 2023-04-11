Cross compiling mobile library for android from Ubuntu 22.10 x86_64

Install the following tools

```console
 # apt-get install make screen autoconf libtool # clang libclang-dev
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
export PATH="path-to-ldc2/ldc2-1.29.0-linux-x86_64/bin:$PATH"
```

Download the target compiler files (We need the precompiled runtime and std library)

```
wget https://github.com/ldc-developers/ldc/releases/download/v1.29.0/ldc2-1.29.0-android-aarch64.tar.xz
tar xf ldc2-1.29.0-android-aarch64.tar.xz
```

Download the android NDK toolchains

Configure ldc to use the target libraries and android tool
```

```

or copy a preconfigured file
```
cp /path/to/tagion_source/tub/ldc2.conf ldc2-1.29.0-linux-x86_64/etc/ldc2.conf
```

Compile the mobile library
```
make -f noconf.android.mk DC=ldc2 PLATFORM=aarch64-linux-android libmobile
```
