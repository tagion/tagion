
# TRIPLET64 = aarch64-linux-android
# TRIPLET32 = armv7a-linux-androideabi
# HOST=linux-x86_64
# export ANDROID_ROOT=$(ANDROID_NDK)/toolchains/llvm/prebuilt/$(HOST)
# export ANDROID_TOOLCHAIN=$(ANDROID_ROOT)/bin

# ANDROID_NDK = $(ANDROID_TOOLS)/android-ndk-r23b
# CMAKE_TOOLCHAIN_FILE =$(ANDROID_NDK)/build/cmake/android.toolchain.cmake

# #--shared
# LEVEL=30
ifdef LDC-BUILD-RUNTIME
BUILD-RUNTIME?=$(LDC-BUILD-RUNTIME)
endif

ifdef DMD-BUILD-RUNTIME
BUILD-RUNTIME?=$(DMD-BUILD-RUNTIME)
endif

DRUNTIME?=$(DTMP)/ldc-build-druntime.tmp/lib


$(DRUNTIME):
	$(PRECMD)
	$(BUILD-RUNTIME) \
	--buildDir=$@ \
	$(DRUNTIME_FLAGS)

druntime: $(DRUNTIME)

.PHONY: druntime

druntime-all:
	ldc-build-runtime \
	--dFlags="-mtriple=$(TRIPLET64) -flto=thin" \
	--targetSystem="Android;Linux;UNIX" \
	CMAKE_TOOLCHAIN_FILE="$(CMAKE_TOOLCHAIN_FILE)" \
	ANDROID_ABI=arm64-v8a \
	ANDROID_NATIVE_API_LEVEL=$(LEVEL) \
	ANDROID_PLATFORM=android-$(LEVEL) \
	MAKE_SYSTEM_VERSION=$(LEVEL) \
	BUILD_LTO_LIBS=ON


druntime-all32:
	ldc-build-runtime \
	--buildDir=./ldc-build-runtime-32.tmp \
	--dFlags="-mtriple=$(TRIPLET32) -flto=thin" \
	--targetSystem="Android;Linux;UNIX" \
	CMAKE_TOOLCHAIN_FILE="$(CMAKE_TOOLCHAIN_FILE)" \
	ANDROID_ABI=armeabi-v7a \
	ANDROID_NATIVE_API_LEVEL=$(LEVEL) \
	ANDROID_PLATFORM=android-$(LEVEL) \
	MAKE_SYSTEM_VERSION=$(LEVEL)


env-druntime-x:
	$(PRECMD)
	${call log.header, $@ :: env}
	${call log.kvp, DRUNTIME, $(DRUNTIME)}
	${call log.kvp, DRUNTIME_FLAGS, $(DRUNTIME_FLAGS)}
	${call log.kvp, BUILD-RUNTIME, $(BUILD-RUNTIME)}
	${call log.close}

env: env-druntime-x

help-druntime-x:
	$(PRECMD)
	${call log.header, $@ :: help}
	${call log.help, "make druntime", "Will build druntime and phobos"}
	${call log.close}

help: help-druntime-x
