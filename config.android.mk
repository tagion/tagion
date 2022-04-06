ANDROID_API?=30
ANDROID_NDK = $(ANDROID_TOOLS)/android-ndk-r23b

ANDROID_HOST=${call join-with,-,$(GETHOSTOS) $(GETARCH)}

ANDROID_OS=android
export ANDROID_ROOT=$(ANDROID_NDK)/toolchains/llvm/prebuilt/$(ANDROID_HOST)
export ANDROID_TOOLCHAIN=$(ANDROID_ROOT)/bin

export ANDROID_LD=$(ANDROID_TOOLCHAIN)/ld
export ANDROID_CC=$(ANDROID_TOOLCHAIN)/clang
export ANDROID_CPP=$(ANDROID_TOOLCHAIN)/clang++
export ANDROID_CROSS_CC=$(ANDROID_TOOLCHAIN)/$(TRIPPLE)

export ANDROID_SYSROOT=${abspath $(ANDROID_TOOLCHAIN)/../sysroot}

export ANDROID_CLANG_VER?=${shell ${ANDROID_CC} --version | $(DTUB)/clang_version.pl}

export ANDROID_CMAKE =$(ANDROID_NDK)/build/cmake/android.toolchain.cmake


#
# Android link flags
#
export ANDROID_LDFLAGS
ANDROID_LDFLAGS+=-z noexecstack
ANDROID_LDFLAGS+=-EL
ANDROID_LDFLAGS+=--warn-shared-textrel
ANDROID_LDFLAGS+=-z now
ANDROID_LDFLAGS+=-z relro
ANDROID_LDFLAGS+=-z max-page-size=4096
ANDROID_LDFLAGS+=--hash-style=gnu
ANDROID_LDFLAGS+=--enable-new-dtags
ANDROID_LDFLAGS+=--eh-frame-hdr
#
#
#
export ANDROID_DFLAGS
ANDROID_DFLAGS+=-mtriple=$(TRIPLET)
ANDROID_DFLAGS+=-Xcc=--sysroot=$(ANDROID_SYSROOT)

#ANDROID_CONFIG_MK:=$(DBUILD)/gen.android.mk

target-android: $(DBUILD)
#target-android: $(ANDROID_CONFIG_MK)


$(ANDROID_CONFIG_MK): $(DBUILD)
	env | $(DTUB)/copy_env.d -r "^ANDROID_" -w "CROSS_" -t target-android -e ANDROID_ENABLED >  $(ANDROID_CONFIG_MK)

#-include $(ANDROID_CONFIG_MK)

target-android:
	@echo $(CROSS_OS)
	@echo $(CROSS_CC)


# -m aarch64linux
# -shared
# -l:libunwind.a
# -ldl
# -lc
# -o bin/libtest-aarch64.so
# /home/carsten/Android/android-ndk-r23b/toolchains/llvm/prebuilt/linux-x86_64/bin/../sysroot/usr/lib/aarch64-linux-android/30/crtbegin_so.o
# -L/home/carsten/Android/android-ndk-r23b/toolchains/llvm/prebuilt/linux-x86_64/lib64/clang/12.0.8/lib/linux/aarch64
# -L/home/carsten/Android/android-ndk-r23b/toolchains/llvm/prebuilt/linux-x86_64/bin/../lib/gcc/aarch64-linux-android/4.9.x -L/home/carsten/Android/android-ndk-r23b/toolchains/llvm/prebuilt/linux-x86_64/bin/../sysroot/usr/lib/aarch64-linux-android/30
# -L/home/carsten/Android/android-ndk-r23b/toolchains/llvm/prebuilt/linux-x86_64/bin/../sysroot/usr/lib/aarch64-linux-android
# -L/home/carsten/Android/android-ndk-r23b/toolchains/llvm/prebuilt/linux-x86_64/bin/../sysroot/usr/lib
# -soname bin/libtest-aarch64.so
# bin/libtest-aarch64.o
# /home/carsten/Android/android-ndk-r23b/toolchains/llvm/prebuilt/linux-x86_64/lib64/clang/12.0.8/lib/linux/libclang_rt.builtins-aarch64-android.a
# /home/carsten/Android/android-ndk-r23b/toolchains/llvm/prebuilt/linux-x86_64/lib64/clang/12.0.8/lib/linux/libclang_rt.builtins-aarch64-android.a
# /home/carsten/Android/android-ndk-r23b/toolchains/llvm/prebuilt/linux-x86_64/bin/../sysroot/usr/lib/aarch64-linux-android/30/crtend_so.o

env-android:
	$(PRECMD)
	${call log.header, $@ :: env}
	${call log.kvp, ANDROID_NDK, $(ANDROID_NDK)}
	${call log.kvp, ANDROID_API, $(ANDROID_API)}
	${call log.kvp, ANDROID_ABI, $(ANDROID_ABI)}
	${call log.kvp, ANDROID_ROOT, $(ANDROID_ROOT)}
	${call log.kvp, ANDROID_TOOLCHAIN, $(ANDROID_TOOLCHAIN)}
	${call log.kvp, ANDROID_LD, $(ANDROID_LD)}
	${call log.kvp, ANDROID_CC, $(ANDROID_CC)}
	${call log.kvp, ANDROID_CPP, $(ANDROID_CPP)}
	${call log.kvp, ANDROID_SYSROOT, $(ANDROID_SYSROOT)}
	${call log.kvp, ANDROID_CLANG_VER, $(ANDROID_CLANG_VER)}
	${call log.env, ANDROID_CMAKE, $(ANDROID_CMAKE)}
	${call log.env, ANDROID_LDFLAGS, $(ANDROID_LDFLAGS)}
	${call log.close}

env: env-android

help-android:
	$(PRECMD)
	${call log.header, $@ :: help}
	${call log.help, "Configure", "The path to the NDK is by the ANDROID_NDK"}
	${call log.help, "", "and the SDK version is set by the ANDROID_SDK_NO"}
	${call log.help, "make env-android", "Will list the current setting"}
	${call log.help, "make help-platform", "This will show how to change tagion platform change"}
	${call log.close}

help: help-android

.PHONY: env-android help-android
