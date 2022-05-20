
IOS_AARCH64=aarch64-iso
PLATFORMS+=$(IOS_AARCH64)

ifeq ($(PLATFORM),$(ISO_AARCH64))
ifndef CC_CROSS
${error CC_CROSS not defined}
endif
ifndef CROSS_SYSROOT
${error CROSS_SYSROOT not defined}
endif
ifndef CROSS_ARCH
${error CROSS_ARCH not defined}
endif
CONFIGUREFLAGS_SECP256K1 += CC=$(CC_CROSS)
CONFIGUREFLAGS_SECP256K1 += CFLAGS="-arch $(CROSS_ARCH) -fpic -g -Os -pipe -isysroot $(CROSS_SYSROOT) -mios-version-min=12.0"

SHARED?=1
#SPLIT_LINK?=1
IOS_ARCH=$(IOS_AARCH64)
TRIPLET = $(ANDROID_ARCH)
#include $(DROOT)/config.android.mk
DINC+=${shell find $(DSRC) -maxdepth 1 -type d -path "*src/lib-*" }
DFILES?=${shell find $(DSRC) -type f -name "*.d" -path "*src/lib-betterc*" -not -path "*/tests/*"}

CROSS_LIB=$(CROSS_SYSROOT)/usr/lib/$(ANDROID_ARCH)/$(ANDROID_NDK)
OBJS+=$(CROSS_LIB)/crtbegin_so.o

${call DDEPS,$(DBUILD),$(DFILES)}

CROSS_LDFLAGS+=--fix-cortex-a53-843419

endif
#DCCROSS_FLAGS+=-mtriple=$(TRIPLET)

ifdef SHARED
DCCROSS_FLAGS+=-shared
DCCROSS_FLAGS+=--relocation-model=pic
endif

#-link-defaultlib-shared=false"
