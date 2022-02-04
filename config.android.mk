ANDROID_SDK_NO?=30
ANDROID_NDK = $(ANDROID_TOOLS)/android-ndk-r23b

CROSS_BIN=$(ANDROID_NDK)/toolchains/llvm/prebuilt/$(NATIVE_PLATFORM)/bin
CROSS_LD=$(CROSS_BIN)/ld
CROSS_CC=$(CROSS_BIN)/clang
CROSS_CPP=$(CROSS_BIN)/clang++

CROSS_SYSROOT=${abspath $(CROSS_BIN)/../sysroot}

CROSS_CLANG_VER?=${shell ${CROSS_CC} --version | $(DTUB)/clang_version.pl}

CROSS_LDFLAGS+=-z noexecstack
CROSS_LDFLAGS+=-EL
CROSS_LDFLAGS+=--warn-shared-textrel
CROSS_LDFLAGS+=-z now
CROSS_LDFLAGS+=-z relro
CROSS_LDFLAGS+=-z max-page-size=4096
CROSS_LDFLAGS+=--hash-style=gnu
CROSS_LDFLAGS+=--enable-new-dtags
CROSS_LDFLAGS+=--eh-frame-hdr
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
	${call log.header, $@ :: android}
	${call log.kvp, ANDROID_NDK, $(ANDROID_NDK)}
	${call log.kvp, ANDROID_SDK_NO, $(ANDROID_SDK_NO)}
	${call log.kvp, CROSS_LD, $(CROSS_LD)}
	${call log.kvp, CROSS_CC, $(CROSS_CC)}
	${call log.kvp, CROSS_CPP, $(CROSS_CPP)}
	${call log.kvp, CROSS_SYSROOT, $(CROSS_SYSROOT)}
	${call log.kvp, CROSS_CLANG_VER, $(CROSS_CLANG_VER)}
	${call log.env, CROSS_LDFLAGS, $(CROSS_LDFLAGS)}
	${call log.close}

env: env-android

help-android:
	$(PRECMD)
	${call log.header, $@ :: android}
	${call log.help, "Configure", "The path to the NDK is by the ANDROID_NDK"}
	${call log.help, "", "and the SDK version is set by the ANDROID_SDK_NO"}
	${call log.help, "make env-android", "Will list the current setting"}
	${call log.help, "make help-platform", "This will show how to change tagion platform change"}
	${call log.close}

help: help-android

.PHONY: env-android help-android
