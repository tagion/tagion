
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

endif
