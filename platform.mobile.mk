PLATFORMS+=MOBILE

ifeq ($(PLATFORM), mobile)

DINC?=${shell find $(DSRC) -maxdepth 1 -type d -path "*src/lib-*" }
# Betterc source files
# DFILES?=${shell find $(DSRC) -type f -name "*.d" -path "*src/lib-betterc/*" -a -not -path "*/tests/*" -a -not -path "*/unitdata/*"}
DFILESSS+=${shell fd -e d . src/lib-mobile}
# LIBSECP=/home/lucas/wrk/tagion/src/wrap-secp256k1/secp256k1/.libs/libsecp256k1_la-secp256k1.o
LIBSECP+=/home/lucas/wrk/tagion/libsecp256k1.a
MTRIPLE=aarch64-android-linux
TARGET?=-mtriple=$(MTRIPLE) 
# DFLAGS+=--relocation-model=pic 
#


# We need the hosts precompiled runtime libraries and linker from android
# LDCHOSTPATH?=/home/lucas/wrk/dondroid/ldc2-1.29.0-android-aarch64/
# NDKPATH?=/home/lucas/wrk/dondroid/android-ndk-r21e/

# DFLAGS+=-defaultlib=phobos2-ldc,druntime-ldc"
# DFLAGS+=-link-defaultlib-shared=false"

# NDK Linux native c compiler
# DFLAGS+=-gcc=$(NDKPATH)/toolchains/llvm/prebuilt/linux-x86_64/bin/aarch64-linux-android21-clang"
# # NDK Linux native linker
# DFLAGS+=-linker=$(NDKPATH)/toolchains/llvm/prebuilt/linux-x86_64/bin/ld.lld

# HACK: not define the arch flags -m32
CROSS_OS=mobile

platform-mobile:
	$(DC) $(TARGET) $(DFLAGS) -i ${addprefix -I,$(DINC)} $(LIBSECP) --shared ${sort $(DFILESSS)} -of=$(DBUILD)/libtagionmobile.so

platform-nolink:
	$(DC) $(TARGET) $(DFLAGS) -c -i ${addprefix -I,$(DINC)} $(LIBSECP) ${sort $(DFILESSS)} -od=$(DBUILD)

platform-main: DFILESSS+=src/lib-mobile/app.d
platform-main: DFLAGS+=-g
platform-main:
	$(DC) $(TARGET) $(DFLAGS) -i ${addprefix -I,$(DINC)} $(LIBSECP) ${sort $(DFILESSS)} -of=$(DBUILD)/d_create_wallet

endif
