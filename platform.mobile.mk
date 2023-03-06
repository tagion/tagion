PLATFORMS+=MOBILE
DINC+=${shell find $(DSRC) -maxdepth 1 -type d -path "*src/lib-*" }
# Betterc source files
# DFILES?=${shell find $(DSRC) -type f -name "*.d" -path "*src/lib-betterc/*" -a -not -path "*/tests/*" -a -not -path "*/unitdata/*"}
DFILES?=${shell fd -e d . src/lib-mobile}
MTRIPLE=aarch64-android-linux

# We need the hosts precompiled runtime libraries and linker from android
LDCHOSTPATH?=/home/lucas/wrk/dondroid/ldc2-1.29.0-android-aarch64/
NDKPATH?=/home/lucas/wrk/dondroid/android-ndk-r21e/

DFLAGS+=-defaultlib=phobos2-ldc,druntime-ldc"
DFLAGS+=-link-defaultlib-shared=false"

# NDK Linux native c compiler
DFLAGS+=-gcc=$(NDKPATH)/toolchains/llvm/prebuilt/linux-x86_64/bin/aarch64-linux-android21-clang"
# NDK Linux native linker
DFLAGS+=-linker=$(NDKPATH)/toolchains/llvm/prebuilt/linux-x86_64/bin/ld.lld

.PHONY: platform
