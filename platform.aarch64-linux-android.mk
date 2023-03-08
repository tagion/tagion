
#
# Linux aarch64 Android
#

ANDROID_AARCH64=aarch64-linux-android
PLATFORMS+=$(ANDROID_AARCH64)

ifeq ($(PLATFORM),$(ANDROID_AARCH64))
ANDROID_ABI=arm64-v8a
DFLAGS+=$(DVERSION)=TINY_AES
MTRIPLE:=aarch64-linux
TRIPLET:=$(MTRIPLE)-android

CROSS_OS=android
CROSS_GO_ARCH=arm64
CROSS_ARCH=aarch64

SHARED?=1
SPLIT_LINKER?=1

ANDROID_ARCH=$(ANDROID_AARCH64)

TRIPLE = $(ANDROID_ARCH)

DINC+=${shell find $(DSRC) -maxdepth 1 -type d -path "*src/lib-*" }

#ifdef BETTERC
#DFLAGS+=$(DBETTERC)
#
# DFILES include
#
DFILES?=${shell find $(DSRC) -type f -name "*.d" -path "*src/lib-betterc/*" -a -not -path "*/tests/*" -a -not -path "*/unitdata/*"}
#unittest: DFILES+=src/lib-betterc/tests/unittest.d

LIBNAME?=libmobile-$(CROSS_ARCH)
LIBRARY=$(DLIB)/$(LIBNAME).$(LIBEXT)
LIBOBJECT=$(DOBJ)/$(LIBNAME).$(OBJEXT)

MODE:=-lib-mobile

#
# Switch in the betterC flags if has been defined
#

#ANDROID_DFLAGS+=$(DBETTERC)
#
# Swicth off the phobos and druntime
#

ifdef SHARED
ANDROID_LDFLAGS+=-shared
endif

WRAPS+=secp256k1
WRAPS+=druntime

ANDROID_LDFLAGS+=-m aarch64linux
ANDROID_LDFLAGS+=-L$(ANDROID_ROOT)/lib64/clang/$(ANDROID_CLANG_VER)/lib/linux/aarch64
ANDROID_LDFLAGS+=$(ANDROID_ROOT)/lib64/clang/$(ANDROID_CLANG_VER)/lib/linux/libclang_rt.builtins-aarch64-android.a
ANDROID_LDFLAGS+=$(ANDROID_SYSROOT)/usr/lib/$(PLATFORM)/$(ANDROID_API)/crtend_so.o
#ANDROID_LDFLAGS+=${shell find $(DTMP_SECP256K1)/src/.libs -name "*.o"}
else
${error The none betterC version is not implemented yet. Set BETTERC=1}
#XFILES?=${shell find $(DSRC) -type f -name "*.d" -path "*src/lib-betterc*" -not -path "*/tests/*"}
endif

ANDROID_LDFLAGS+=--fix-cortex-a53-843419
#ANDROID_LDFLAGS+=-flto=thin
#
# Link all into one library
#
#ANDROID_LDFLAGS+=-Wl,--whole-archive
ANDROID_DFLAGS+=--defaultlib=libdruntime-ldc-lto.a,libphobos2-ldc-lto.a

ANDROID_DFLAGS+=-L$(LDC_BUILD_RUNTIME_TMP)/lib/
#ANDROID_DFLAGS+=-L/home/carsten/work/ldc-runtime/ldc-build-runtime.tmp/lib/
ANDROID_DFLAGS+=-I$(LDC_BUILD_RUNTIME_TMP)/ldc-src/runtime/phobos/
ANDROID_DFLAGS+=-I$(LDC_BUILD_RUNTIME_TMP)/ldc-src/runtime/druntime/src/
ANDROID_DFLAGS+=--conf=
ANDROID_DFLAGS+=--flto=thin
ANDROID_DFLAGS+=--Oz

#ANDROID_DFLAGS+=--static
target-android: DC=$(TOOLS_LDC_BIN)/ldc2

target-android: LD=$(ANDROID_LD)
target-android: CC=$(ANDROID_CC)
target-android: CPP=$(ANDROID_CPP)

#target-android: DFLAGS+=--flto=thin
target-android: DFLAGS+=-I$(LDC_BUILD_RUNTIME_TMP)/ldc-src/runtime/phobos/
target-android: DFLAGS+=-I$(LDC_BUILD_RUNTIME_TMP)/ldc-src/runtime/druntime/src/
target-android: DFLAGS+=--Oz
target-android: DFLAGS+=--shared
#target-android: DFLAGS+=--singleobj
target-android: DFLAGS+=--defaultlib=libdruntime-ldc.a,libphobos2-ldc.a
#target-android: DFLAGS+=-I/home/carsten/work/tagion/src/lib-basic/ -I/home/carsten/work/tagion/src/lib-crypto/
target-android: DFLAGS+=-mtriple=$(PLATFORM)
target-android: DFLAGS+=-Xcc=--sysroot=$(ANDROID_SYSROOT)
target-android: DFLAGS+=$(DBETTERC)

target-android: LDFLAGS+=$(ANDROID_LDFLAGS)
target-android: LDFLAGS+=-soname $(LIBRARY)

# To make sure that the all has been defined correctly
# The library must be expanded on the second pass
ifdef OPT_ONLY_OBJ
target-android: $$(LIBOBJECT)
else
target-android: $$(LIBRARY)
endif

platform: target-android

#platform: show

env-show:
	@echo LIBEXT=$(LIBEXT)
	@echo SHARED=$(SHARED)
	@echo LIBRARY=$(LIBRARY)
	@echo DLIB=$(DLIB)
	@echo DOBJ=$(DOBJ)
	@echo DFILES=$(DFILES)
	@echo ANDROID_DFLAGS=$(ANDROID_DFLAGS)
	@echo DFLAGS=$(DFLAGS)
	@echo LINKFLAGS -z noexecstack -EL --fix-cortex-a53-843419 --warn-shared-textrel -z now -z relro -z max-page-size=4096 --hash-style=gnu --enable-new-dtags --eh-frame-hdr -m aarch64linux -shared
	@echo ANDROID_LDFLAGS=$(ANDROID_LDFLAGS)
	@echo OBJS=$(OBJS)

clean-android:
	$(PRECMD)
	${call log.header, $@ :: clean}
	$(RM) $(LIBRARY)
	$(RM) $(LIBOBJECT)

.PHONY: clean-android

clean: clean-android

${call DDEPS,$(DBUILD),$(DFILES)}


#endif
