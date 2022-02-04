
ANDROID_AARCH64=aarch64-linux-android
PLATFORMS+=$(ANDROID_AARCH64)

ifeq ($(PLATFORM),$(ANDROID_AARCH64))
ANDROID_ARCH=$(ANDROID_AARCH64)

TRIPLET = aarch64-linux-android
#include $(DROOT)/config.android.mk
DINC+=${shell find $(DSRC) -maxdepth 1 -type d -path "*src/lib-*" }

CROSS_LIB=$(CROSS_SYSROOT)/usr/lib/$(ANDROID_ARCH)/$(ANDROID_NDK)
OBJS+=$(CROSS_LIB)/crtbegin_so.o

${call DDEPS,$(DBUILD),$(DFILES)}

CROSS_LDFLAGS+=--fix-cortex-a53-843419

endif
DCCROSS_FLAGS+=-mtriple=$(TRIPLET)

ifdef SHARED
DCCROSS_FLAGS+=-shared
DCCROSS_FLAGS+=--relocation-model=pic
endif

#-link-defaultlib-shared=false"
