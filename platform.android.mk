#
# Linux aarch64 Android
#

ANDROID_AARCH64=aarch64-linux-android
PLATFORMS+=$(ANDROID_AARCH64)

ifeq ($(PLATFORM),$(ANDROID_AARCH64))

MTRIPLE:=aarch64-linux
TRIPLET:=$(MTRIPLE)-android
ANDROID_ABI?=$(TRIPLET)
ANDROID_ARCH=$(ANDROID_AARCH64)

endif


ANDROID_ARMV7A=armv7a-linux-android
PLATFORMS+=$(ANDROID_ARMV7A)

ifeq ($(PLATFORM),$(ANDROID_ARMV7A))

MTRIPLE:=armv7a-linux
TRIPLET:=$(MTRIPLE)-android
ANDROID_ABI?=armv7a-linux-androideabi
ANDROID_ARCH=$(ANDROID_ARMV7A)

endif


ANDROID_x86_64=x86_64-linux-android
PLATFORMS+=$(ANDROID_x86_64)

ifeq ($(PLATFORM),$(ANDROID_x86_64))

MTRIPLE:=x86_64-linux
TRIPLET:=$(MTRIPLE)-android
ANDROID_ABI?=$(TRIPLET)
ANDROID_ARCH=$(ANDROID_x86_64)

endif

# General android config
ifneq (,$(findstring android,$(PLATFORM)))

DC:=ldc2

# This is the default ANDROID_NDK location where the install script dowloads to.
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

DFLAGS+=$(DVERSION)=MOBILE
CROSS_ENABLED:=1
CROSS_OS:=android

SHARED?=1
DFLAGS+=$(DDEFAULTLIBSTATIC)
DFLAGS+=-i

DINC+=${shell find $(DSRC) -maxdepth 1 -type d -path "*src/lib-*" }

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
	${call log.close}

env: env-android

help-android:
	$(PRECMD)
	${call log.header, $@ :: help}
	echo '     _________________________________________ '
	echo '    / It looks like youre trying to cross     \'
	echo '    | compile for android, did you know that  |'
	echo '    | you need androids snowflake linker in   |'
	echo '    | order to that. You can specify it by    |'
	echo '    | providing the path you android ndk with |'
	echo '    \ ANDROID_NDK=                            /'
	echo '     ----------------------------------------- '
	echo '     \                                         '
	echo '      \                                        '
	echo '         __                                    '
	echo '        /  \                                   '
	echo '        |  |                                   '
	echo '        @  @                                   '
	echo '        |  |                                   '
	echo '        || |/                                  '
	echo '        || ||                                  '
	echo '        |\_/|                                  '
	echo '        \___/                                  '
	${call log.help, "make env-android", "Will list the current setting"}
	${call log.help, "make help-android", "This will show how to change tagion platform change"}
	${call log.close}

help: help-android

.PHONY: env-android help-android
