ANDROID_NDK = $(ANDROID_TOOLS)/android-ndk-r23b
TRIPLET = armv7a-linux-androideabi
#aarch64-linux-android
#SHARED=1

DCCROSS_FLAGS+=-mtriple=$(TRIPLET)

ifdef SHARED
DCCROSS_FLAGS+=-shared
DCCROSS_FLAGS+=--relocation-model=pic
endif

#-link-defaultlib-shared=false"
