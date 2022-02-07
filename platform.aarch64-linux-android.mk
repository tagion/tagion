
ANDROID_AARCH64=aarch64-linux-android
PLATFORMS+=$(ANDROID_AARCH64)

ifeq ($(PLATFORM),$(ANDROID_AARCH64))

CROSS_OS=android
CROSS_GO_ARCH=arm64

SHARED?=1
SPLIT_LINKER?=1

ANDROID_ARCH=$(ANDROID_AARCH64)

TRIPLE = $(ANDROID_ARCH)

DINC+=${shell find $(DSRC) -maxdepth 1 -type d -path "*src/lib-*" }

ifdef BETTERC
LIBNAME?=libwallet-betterc
LIBARARY=$(DLIB)/$(LIBNAME).$(LIBEXT)
LIBOBJECT=$(DOBJ)/$(LIBNAME).$(OBJEXT)
MODE:=-lib-betterc

DFILES?=${shell find $(DSRC) -type f -name "*.d" -a -not -name "~*" -path "*src/lib-betterc*" -not -path "*/tests/*"}

#
# Switch in the betterC flags if has been defined
#
$(DFILES): DFLAGS+=$(DBETTERC)

else
${error The none betterC version is not implemented yet. Set BETTERC=1}
#XFILES?=${shell find $(DSRC) -type f -name "*.d" -path "*src/lib-betterc*" -not -path "*/tests/*"}
endif

CROSS_LIB=$(CROSS_SYSROOT)/usr/lib/$(ANDROID_ARCH)/$(ANDROID_NDK)
OBJS+=$(CROSS_LIB)/crtbegin_so.o

android-target: LD=$(ANDROID_LD)
android-target: CC=$(ANDROID_CC)
android-target: CPP=$(ANDROID_CPP)
android-target: LDFLAGS=$(ANDROID_LDFLAGS)
android-target: DFLAGS+=$(ANDROID_DFLAGS)

android-target: | secp256k1

# To make sure that the all has been defined correctly
# The libarary must be expanded on the second pass
ifdef OPT_ONLY_OBJ
android-target: $$(LIBOBJECT)
else
android-target: $$(LIBARARY)
endif

platform: android-target
platform: show

show:
	@echo LIBEXT=$(LIBEXT)
	@echo SHARED=$(SHARED)
	@echo LIBARARY=$(LIBARARY)
	@echo DLIB=$(DLIB)
	@echo DOBJ=$(DOBJ)
	@echo DFILES=$(DFILES)


clean-android:
	$(PRECMD)
	${call log.header, $@ :: clean}
	$(RM) $(LIBARARY)
	$(RM) $(LIBOBJECT)

${call DDEPS,$(DBUILD),$(DFILES)}

CROSS_LDFLAGS+=--fix-cortex-a53-843419

endif

#/home/carsten/Android/android-ndk-r23b/toolchains/llvm/prebuilt/linux-x86_64/bin/ld -z noexecstack -EL --warn-shared-textrel -z now -z relro -z max-page-size=4096 -X --hash-style=gnu --enable-new-dtags --eh-frame-hdr -m armelf_linux_eabi -shared -o bin/libtest-armv7a.so /home/carsten/Android/android-ndk-r23b/toolchains/llvm/prebuilt/linux-x86_64/bin/../sysroot/usr/lib/arm-linux-androideabi/30/crtbegin_so.o -L/home/carsten/Android/android-ndk-r23b/toolchains/llvm/prebuilt/linux-x86_64/lib64/clang/12.0.8/lib/linux/arm -L/home/carsten/Android/android-ndk-r23b/toolchains/llvm/prebuilt/linux-x86_64/bin/../lib/gcc/arm-linux-androideabi/4.9.x -L/home/carsten/Android/android-ndk-r23b/toolchains/llvm/prebuilt/linux-x86_64/bin/../sysroot/usr/lib/arm-linux-androideabi/30 -L/home/carsten/Android/android-ndk-r23b/toolchains/llvm/prebuilt/linux-x86_64/bin/../sysroot/usr/lib/arm-linux-androideabi -L/home/carsten/Android/android-ndk-r23b/toolchains/llvm/prebuilt/linux-x86_64/bin/../sysroot/usr/lib/../lib -L/home/carsten/Android/android-ndk-r23b/toolchains/llvm/prebuilt/linux-x86_64/bin/../sysroot/usr/lib/arm-linux-androideabi/../../lib -L/home/carsten/Android/android-ndk-r23b/toolchains/llvm/prebuilt/linux-x86_64/bin/../sysroot/usr/lib -soname bin/libtest-armv7a.so bin/libtest-armv7a.o /home/carsten/Android/android-ndk-r23b/toolchains/llvm/prebuilt/linux-x86_64/lib64/clang/12.0.8/lib/linux/libclang_rt.builtins-arm-android.a -l:libunwind.a -ldl -lc /home/carsten/Android/android-ndk-r23b/toolchains/llvm/prebuilt/linux-x86_64/lib64/clang/12.0.8/lib/linux/libclang_rt.builtins-arm-android.a -l:libunwind.a -ldl /home/carsten/Android/android-ndk-r23b/toolchains/llvm/prebuilt/linux-x86_64/bin/../sysroot/usr/lib/arm-linux-androideabi/30/crtend_so.o
