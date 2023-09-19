#
# Apple arm64 iOS
#

IOS_ARM64=arm64-apple-ios
# 12.0
PLATFORMS+=$(IOS_ARM64)

ifeq ($(PLATFORM),$(IOS_ARM64))

modify_rpath: $(LIBMOBILE)
	install_name_tool -id "@rpath/libmobile.dylib" $<

.PHONY: modify_rpath

libmobile: modify_rpath

# ---------------------------------------------------------------------
# Compiler selection 
# ---------------------------------------------------------------------

CCC = clang++ -O0
CC  = clang -O0

CROSS_ENABLED=1
CROSS_OS=ios
CROSS_ARCH = arm64

IOS_ARCH=$(IOS_ARM64)
TRIPLET = $(IOS_ARCH)

DFILES: libphobos-arm64-ios
DFILES: libdruntime-arm64-ios

SHARED?=1
OS:=darwin
DLLEXT:=dylib
DFLAGS+=$(DDEFAULTLIBSTATIC)
DFLAGS+=-i
DFLAGS+=-mtriple=$(TRIPLET)
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

CONFIGUREFLAGS_SECP256K1 += CC=$(CC_CROSS)
CONFIGUREFLAGS_SECP256K1 += CFLAGS="-arch $(CROSS_ARCH) -fpic -g -Os -pipe -isysroot $(CROSS_SYSROOT) -mios-version-min=12.0"

endif

env-ios:
	$(PRECMD)
	$(call log.header, $@ :: cross)
	$(call log.kvp, XCODE_ROOT, $(XCODE_ROOT))
	${call log.kvp, OS, $(OS)}
	${call log.kvp, SHARED, $(SHARED)}
	$(call log.close)
