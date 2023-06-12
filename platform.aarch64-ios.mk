
# ifeq ($(PLATFORM), arm64-apple-ios12.0)

# # DINC+=${shell find $(DSRC) -maxdepth 1 -type d -path "*src/lib-*" }
# TARGET=arm64-apple-ios12.0

# CROSS_ENABLED=1

# CROSS_OS=ios12.0
# CROSS_ARCH=arm64
# CROSS_VENDOR=apple

# MTRIPLE:= $(CROSS_ARCH)-$(CROSS_VENDOR)-$(CROSS_OS)
# TRIPLET:=$(MTRIPLE)
# DFLAGS+=-mtriple=$(MTRIPLE)

# XCODE_ROOT := ${shell xcode-select -print-path}
# XCODE_DEVICE_SDK = $(XCODE_ROOT)/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS$(IPHONE_SDKVERSION).sdk
# CROSS_SYSROOT=$(XCODE_DEVICE_SDK)


# env-ios:
#  $(PRECMD)
#  $(call log.header, $@ :: env)
#  $(call log.kvp, MTRIPLE, $(MTRIPLE))
#  $(call log.kvp, CROSS_ENABLED, $(CROSS_ENABLED))
#  $(call log.kvp, CROSS_ARCH, $(CROSS_ARCH))
#  $(call log.kvp, CROSS_VENDOR, $(CROSS_VENDOR))
#  $(call log.kvp, CROSS_OS, $(CROSS_OS))
#  $(call log.kvp, CROSS_SYSROOT, $(CROSS_SYSROOT))
#  $(call log.kvp, XCODE_ROOT, $(XCODE_ROOT))
#  $(call log.close)

# env: env-ios

# help-ios:
# 	$(PRECMD)
# 	${call log.header, $@ :: help}
# 	${call log.help, "make env-android", "Will list the current setting"}
# 	${call log.help, "make help-android", "This will show how to change tagion platform change"}
# 	${call log.close}

# help: help-ios

# .PHONY: env-ios help-ios
# endif

# PREBUILD=1 # Disable the dependency thingy 🤮
# export REPOROOT?=${shell git rev-parse --show-toplevel}
# include tub/main.mk

IOS_AARCH64=aarch64-ios
PLATFORMS+=$(IOS_AARCH64)

ifeq ($(PLATFORM),$(IOS_AARCH64))

CONFIGUREFLAGS_SECP256K1 += CC=$(CC_CROSS)
CONFIGUREFLAGS_SECP256K1 += CFLAGS="-arch $(CROSS_ARCH) -fpic -g -Os -pipe -isysroot $(CROSS_SYSROOT) -mios-version-min=12.0"

SHARED?=1
DLLEXT:=dylib
DFILES: libphobos-aarch64-ios
DFILES: libdruntime-aarch64-ios
IOS_ARCH=$(IOS_AARCH64)
TRIPLET = $(IOS_ARCH)
ARCH = aarch64
CROSS_OS=ios
DFLAGS+=$(DDEFAULTLIBSTATIC)
DFLAGS+=-mtriple=$(TRIPLET)
DINC+=${shell find $(DSRC) -maxdepth 1 -type d -path "*src/lib-*" }

# XCode dipipo

XCODE_ROOT := ${shell xcode-select -print-path}
XCODE_SIMULATOR_SDK = $(XCODE_ROOT)/Platforms/iPhoneSimulator.platform/Developer/SDKs/iPhoneSimulator$(IPHONE_SDKVERSION).sdk
XCODE_DEVICE_SDK = $(XCODE_ROOT)/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS$(IPHONE_SDKVERSION).sdk

endif

env-ios:
	$(PRECMD)
	$(call log.header, $@ :: cross)
	$(call log.kvp, XCODE_ROOT, $(XCODE_ROOT))
	$(call log.close)
