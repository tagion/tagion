
#
# Linux aarch64 Android
#

ANDROID_AARCH64=aarch64-linux-android
PLATFORMS+=$(ANDROID_AARCH64)

ifeq ($(PLATFORM),$(ANDROID_AARCH64))

ANDROID_API?=21
ANDROID_ABI?=aarch64

ANDROID_TOOLCHAIN?=$(ANDROID_NDK)/toolchains/llvm/prebuilt/$(OS)-$(ARCH)

CC=$(ANDROID_TOOLCHAIN)/$(TRIPLET)$(ANDROID_API)-clang
AR=$(ANDROID_TOOLCHAIN)/bin/$(TARGET)-ar
AS=$(ANDROID_TOOLCHAIN)/bin/$(TARGET)-as
CC=$(ANDROID_TOOLCHAIN)/bin/$(TARGET)$(ANDROID_API)-clang
CXX=$(ANDROID_TOOLCHAIN)/bin/$(TARGET)$(ANDROID_API)-clang++
LD=$(ANDROID_TOOLCHAIN)/bin/$(TARGET)-ld
RANLIB=$(ANDROID_TOOLCHAIN)/bin/$(TARGET)-ranlib
STRIP=$(ANDROID_TOOLCHAIN)/bin/$(TARGET)-strip

## Still need to see if can somehow specify the ldc's lib-dirs from commandline
ANDROID_LDC_LIBS=$(ANDROID_LDC)

CROSS_ENABLED=1
CROSS_OS=android
CROSS_GO_ARCH=arm64
CROSS_ARCH=aarch64

MTRIPLE:=aarch64-linux
TRIPLET:=$(MTRIPLE)-android

SHARED?=1
DFLAGS+=$(DDEFAULTLIBSTATIC)
DFLAGS+=-i

ANDROID_ARCH=$(ANDROID_AARCH64)
DFLAGS+=-mtriple=$(PLATFORM)

DINC+=${shell find $(DSRC) -maxdepth 1 -type d -path "*src/lib-*" }

env-android:
	$(PRECMD)
	${call log.header, $@ :: env}
	${call log.kvp, ANDROID_NDK, $(ANDROID_NDK)}
	${call log.kvp, ANDROID_API, $(ANDROID_API)}
	${call log.kvp, ANDROID_ABI, $(ANDROID_ABI)}
	${call log.kvp, ANDROID_TOOLCHAIN, $(ANDROID_TOOLCHAIN)}
	${call log.kvp, ANDROID_LD, $(LD)}
	${call log.kvp, ANDROID_CC, $(CC)}
	${call log.kvp, ANDROID_CXX, $(CXX)}
	${call log.kvp, ANDROID_STRIP, $(STRIP)}
	${call log.kvp, ANDROID_AR, $(AR)}
	${call log.kvp, ANDROID_RANLIB, $(RANLIB)}
	${call log.kvp, ANDROID_AS, $(AS)}
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

endif
