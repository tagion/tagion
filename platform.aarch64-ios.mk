
IOS_AARCH64=aarch64-iso
PLATFORMS+=$(IOS_AARCH64)

ifeq ($(PLATFORM),$(ISO_AARCH64))
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
