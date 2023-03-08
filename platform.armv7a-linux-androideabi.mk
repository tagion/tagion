
ANDROID_ARMV7A = armv7a-linux-androideabi

PLATFORMS+=$(ANDROID_ARMV7A)
ifeq ($(PLATFORM),$(ANDROID_ARMV7A))
#SHARED?=1
ANDROID_ARCH=$(ANDROID_AARCH64)

TRIPLET = $(ANDROID_ARCH)

DCCROSS_FLAGS+=-mtriple=$(TRIPLET)

DINC+=${shell find $(DSRC) -maxdepth 1 -type d -path "*src/lib-*" }
DFILES?=${shell find $(DSRC) -type f -name "*.d" -path "*src/lib-bettec*"}

CROSS_LIB=$(CROSS_SYSROOT)/usr/lib/$(ANDROID_ARCH)/$(ANDROID_NDK)
#OBJS+=$(CROSS_LIB)/crtbegin_so.o

${call DDEPS,$(DBUILD),$(DFILES)}

endif

#-link-defaultlib-shared=false"
