
#
# Linux aarch64 Android
#

ANDROID_AARCH64=aarch64-linux-android
PLATFORMS+=$(ANDROID_AARCH64)

ifeq ($(PLATFORM),$(ANDROID_AARCH64))

MTRIPLE:=aarch64-linux
TRIPLET:=$(MTRIPLE)-android

# Go can not cross compile due to some cgo problem
CROSS_OS=android
CROSS_GO_ARCH=arm64
CROSS_ARCH=aarch64

ANDROID_ARCH=$(ANDROID_AARCH64)
DFLAGS+=-mtriple=$(PLATFORM)

${call DDEPS,$(DBUILD),$(DFILES)}

endif
