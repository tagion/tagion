#
# Apple arm64 iOS
#

IOS_SIMULATOR_ARM64:=arm64-apple-ios-simulator
PLATFORMS+=$(IOS_SIMULATOR_ARM64)
ifeq ($(PLATFORM),$(IOS_SIMULATOR_ARM64))
IOS_ARCH:=$(IOS_SIMULATOR_ARM64)
TRIPLET:=arm64-apple-ios
endif

IOS_ARM64:=arm64-apple-ios
PLATFORMS+=$(IOS_ARM64)
ifeq ($(PLATFORM),$(IOS_ARM64))
IOS_ARCH:=$(IOS_ARM64)
TRIPLET=$(IOS_ARCH)
endif

IOS_SIMULATOR_X86_64:=x86_64-apple-ios-simulator
PLATFORMS+=$(IOS_SIMULATOR_X86_64)
ifeq ($(PLATFORM),$(IOS_SIMULATOR_X86_64))
IOS_ARCH:=$(IOS_SIMULATOR_X86_64)
TRIPLET:=x86_64-apple-ios
endif


IOS_X86_64:=x86_64-apple-ios
PLATFORMS+=$(IOS_X86_64)
ifeq ($(PLATFORM),$(IOS_X86_64))
IOS_ARCH:=$(IOS_X86_64)
TRIPLET=$(IOS_X86_64)
endif


ifneq (,$(findstring apple-ios,$(PLATFORM)))

CCC = clang++ -O0
CC  = clang -O0

DFLAGS+=$(DVERSION)=MOBILE
CROSS_ENABLED=1
CROSS_OS=ios
CROSS_ARCH = arm64

SHARED?=1
OS:=darwin
DLLEXT:=dylib
DFLAGS+=$(DDEFAULTLIBSTATIC)
DFLAGS+=-mtriple=$(IOS_ARCH)
DINC+=${shell find $(DSRC) -maxdepth 1 -type d -path "*src/lib-*" }

# ---------------------------------------------------------------------
# Xcode sysroot 
# ---------------------------------------------------------------------

IPHONE_SDKVERSION=16.4
XCODE_ROOT := ${shell xcode-select -print-path}

ifeq ($(CROSS_ARCH),arm64)
CROSS_SYSROOT=$(XCODE_ROOT)/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS$(IPHONE_SDKVERSION).sdk
else
CROSS_SYSROOT=$(XCODE_ROOT)/Platforms/iPhoneSimulator.platform/Developer/SDKs/iPhoneSimulator$(IPHONE_SDKVERSION).sdk
endif

# CONFIGUREFLAGS_SECP256K1 += CC=$(CC_CROSS)
CONFIGUREFLAGS_SECP256K1+=CFLAGS="-arch $(CROSS_ARCH) -fpic -g -Os -pipe -isysroot $(CROSS_SYSROOT) -mios-version-min=12.0"

endif

env-ios:
	$(PRECMD)
	$(call log.header, $@ :: cross)
	$(call log.kvp, XCODE_ROOT, $(XCODE_ROOT))
	${call log.kvp, OS, $(OS)}
	${call log.kvp, SHARED, $(SHARED)}
	${call log.kvp, TRIPLET, $(TRIPLET)}
	${call log.kvp, IOS_ARCH, $(IOS_ARCH)}
	${call log.kvp, CROSS_ENABLED, $(CROSS_ENABLED)}
	$(call log.close)
