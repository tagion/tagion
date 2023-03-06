# machine-vendor-operatingsystem
#TRIPLET ?= $(ARCH)-unknown-$(OS)

#TRIPLET_SPACED := ${subst -, ,$(TRIPLET)}

# If TRIPLET specified with 2 words
# fill the VENDOR as unknown
# CROSS_ARCH := ${word 1, $(TRIPLET_SPACED)}
# ifeq (${words $(TRIPLET_SPACED)},2)
# CROSS_VENDOR := unknown
# CROSS_OS := ${word 2, $(TRIPLET_SPACED)}
# else
# CROSS_VENDOR := ${word 2, $(TRIPLET_SPACED)}
# CROSS_OS := ${word 3, $(TRIPLET_SPACED)}
# endif

#CROSS_ENABLED := 1

# If same as host - reset vars not to trigger
# cross-compilation logic
# ifeq ($(CROSS_ARCH),$(ARCH))
# ifeq ($(CROSS_OS),$(OS))
# CROSS_ARCH :=
# CROSS_VENDOR :=
# CROSS_OS :=
# CROSS_ENABLED :=
# endif
# endif

#MTRIPLE := $(CROSS_ARCH)-$(CROSS_VENDOR)-$(CROSS_OS)

ifeq ($(MTRIPLE),--)
MTRIPLE := $$(TRIPLET)
endif

ifdef CROSS_ENABLED
# ---
# iOS
# Only care about iOS compilation if on macOS
ifeq ($(OS),darwin)
ifeq ($(CROSS_OS),ios)
XCODE_ROOT := ${shell xcode-select -print-path}
XCODE_SIMULATOR_SDK = $(XCODE_ROOT)/Platforms/iPhoneSimulator.platform/Developer/SDKs/iPhoneSimulator$(IPHONE_SDKVERSION).sdk
XCODE_DEVICE_SDK = $(XCODE_ROOT)/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS$(IPHONE_SDKVERSION).sdk

ifeq ($(CROSS_ARCH),arm64)
CROSS_SYSROOT=$(XCODE_DEVICE_SDK)
else
CROSS_SYSROOT=$(XCODE_SIMULATOR_SDK)
endif
endif
endif

define cross.setup
"${shell env | grep ANDROID_CROSS_}"
endef

# ---
# Android
# arm    => "arm-linux-androideabi",
# arm64  => "aarch64-linux-android",
# mips   => "mipsel-linux-android",
# mips64 => "mips64el-linux-android",
# x86    => "i686-linux-android",
# x86_64 => "x86_64-linux-android",
# Will match android and androideabi
IS_ANDROID := ${findstring android,$(CROSS_OS)}
ifeq ($(IS_ANDROID),android)

ifeq ($(OS),darwin)
ANDROID_NDK_HOST_TAG = darwin-x86_64
else
ANDROID_NDK_HOST_TAG = linux-x86_64
endif

CROSS_ANDROID_API = 30

CROSS_ROOT=$(ANDROID_NDK)/toolchains/llvm/prebuilt/$(HOST_PLATFORM)
CROSS_TOOLCHAIN=$(CROSS_ROOT)/bin
CROSS_SYSROOT=$(CROSS_ROOT)/sysroot
endif
endif


env-cross:
	$(PRECMD)
	$(call log.header, $@ :: cross)
	$(call log.kvp, MTRIPLE, $(MTRIPLE))
	$(call log.kvp, TRIPLE, $(TRIPLE))
	$(call log.kvp, HOST_PLATFORM, $(HOST_PLATFORM))
	$(call log.kvp, PLATFORM, $(PLATFORM))
	$(call log.kvp, CROSS_ENABLED, $(CROSS_ENABLED))
	$(call log.kvp, CROSS_ARCH, $(CROSS_ARCH))
	$(call log.kvp, CROSS_VENDOR, $(CROSS_VENDOR))
	$(call log.kvp, CROSS_OS, $(CROSS_OS))
	$(call log.kvp, CROSS_SYSROOT, $(CROSS_SYSROOT))
	$(call log.kvp, ANDROID_ROOT, $(ANDROID_ROOT))
	$(call log.kvp, ANDROID_NDK, $(ANDROID_NDK))
	$(call log.kvp, XCODE_ROOT, $(XCODE_ROOT))
	$(call log.close)

env: env-cross


TEST89=${shell env | grep ANDROID}

test89:
	@echo "$(TEST89)"
