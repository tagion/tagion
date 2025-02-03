#
# Linux aarch64 Android
#

ANDROID_AARCH64=aarch64-linux-android
ANDROID_PLATFORMS+=$(ANDROID_AARCH64)

ifeq ($(PLATFORM),$(ANDROID_AARCH64))

MTRIPLE:=aarch64-linux
TRIPLET:=$(MTRIPLE)-android
ANDROID_ABI?=$(TRIPLET)
ABI:=arm64-v8a
ANDROID_ARCH=$(ANDROID_AARCH64)

endif


ANDROID_ARMV7A=armv7a-linux-android
ANDROID_PLATFORMS+=$(ANDROID_ARMV7A)

ifeq ($(PLATFORM),$(ANDROID_ARMV7A))

MTRIPLE:=armv7a-linux
TRIPLET:=$(MTRIPLE)-android
ANDROID_ABI?=armv7a-linux-androideabi
ABI:=armeabi-v7a
ANDROID_ARCH=$(ANDROID_ARMV7A)

endif


ANDROID_x86_64=x86_64-linux-android
ANDROID_PLATFORMS+=$(ANDROID_x86_64)

ifeq ($(PLATFORM),$(ANDROID_x86_64))

MTRIPLE:=x86_64-linux
TRIPLET:=$(MTRIPLE)-android
ANDROID_ABI?=$(TRIPLET)
ABI:=x86_64
ANDROID_ARCH=$(ANDROID_x86_64)

endif

PLATFORMS+=$(ANDROID_PLATFORMS)

# General android config
ifneq (,$(findstring android,$(PLATFORM)))

LD_EXPORT_DYN?=-export-dynamic
TARGET_ARCH:=$(word 1, $(subst -, ,$(PLATFORM)))

include $(DTUB)/scripts/setup_android_toolchain.mk

# DC:=$(TOOLS)/$(LDC_HOST)/bin/ldc2

# This is the default ANDROID_NDK location where the install script downloads to.
# You may override this in your local.mk
ANDROID_NDK:=$(REPOROOT)/tools/android-ndk-r21b/

DFLAGS+=-mtriple=$(PLATFORM)

ANDROID_API?=21
HOST_OS:=${shell uname -s | tr '[:upper:]' '[:lower:]' }
HOST_ARCH:=${shell uname -m}
ANDROID_TOOLCHAIN:=$(abspath $(ANDROID_NDK)/toolchains/llvm/prebuilt/${HOST_OS}-${HOST_ARCH})

export AR:=$(ANDROID_TOOLCHAIN)/bin/llvm-ar
export AS:=$(ANDROID_TOOLCHAIN)/bin/llvm-as
export CC:=$(ANDROID_TOOLCHAIN)/bin/$(ANDROID_ABI)$(ANDROID_API)-clang
export CXX:=$(ANDROID_TOOLCHAIN)/bin/$(ANDROID_ABI)$(ANDROID_API)-clang++
export LD:=$(ANDROID_TOOLCHAIN)/bin/ld.ldd
export RANLIB:=$(ANDROID_TOOLCHAIN)/bin/llvm-ranlib
export STRIP:=$(ANDROID_TOOLCHAIN)/bin/llvm-strip
export CMAKE_TOOLCHAIN_FILE=$(ANDROID_NDK)/build/cmake/android.toolchain.cmake
# export CMAKE:=$(REPOROOT)/tools/android-cmake/bin/cmake

CONFIGUREFLAGS_SECP256K1 += CMAKE_TOOLCHAIN_FILE=$(CMAKE_TOOLCHAIN_FILE)
CONFIGUREFLAGS_SECP256K1 += ANDROID_ABI=$(ABI)
CONFIGUREFLAGS_SECP256K1 += ANDROID_PLATFORM=$(ANDROID_API)
CONFIGUREFLAGS_SECP256K1 += SECP256K1_BUILD_BENCHMARK=OFF

# I don't know if this is still necessary. It should be set by the cmake toolchain
BUILDENV_SECP256K1+= CFLAGS="-fpic"

DVERSIONS+=MOBILE
CROSS_ENABLED:=1
CROSS_OS:=android

SHARED?=1
DFLAGS+=$(DDEFAULTLIBSTATIC)

else
install-android-toolchain:
	$(PRECMD)
	echo "You need to specify an android target PLATFORM= to choose which android toolchain to install"
	${call log.kvp, PLATFORM, $(PLATFORM)}
	${call log.env, ANDROID_PLATFORMS, $(ANDROID_PLATFORMS)}
endif

env-android:
	$(PRECMD)
	${call log.header, $@ :: env}
	${call log.kvp, ANDROID_NDK, $(ANDROID_NDK)}
	${call log.kvp, ANDROID_API, $(ANDROID_API)}
	${call log.kvp, ANDROID_ABI, $(ANDROID_ABI)}
	${call log.kvp, ANDROID_TOOLCHAIN, $(ANDROID_TOOLCHAIN)}
	${call log.kvp, LD, $(LD)}
	${call log.kvp, CC, $(CC)}
	${call log.kvp, CXX, $(CXX)}
	${call log.kvp, STRIP, $(STRIP)}
	${call log.kvp, AR, $(AR)}
	${call log.kvp, RANLIB, $(RANLIB)}
	${call log.kvp, AS, $(AS)}
	${call log.env, ANDROID_PLATFORMS, $(ANDROID_PLATFORMS)}
	${call log.close}

env: env-android

help-android:
	$(PRECMD)
	${call log.header, $@ :: help}
	${call log.help, "https://docs.tagion.org/tech/guide/build/android", "View help guide for this target"}
	${call log.help, "make env-android", "Will list the current setting"}
	${call log.help, "make help-android", "This will show how to change tagion platform change"}
	${call log.help, "make install-android-toolchain", "Installs the android ndk and configured ldc compiler"}
	${call log.close}

help: help-android

.PHONY: env-android help-android
