#include betterc_setup.mk
REPOROOT?=${shell git rev-parse --show-toplevel}
BETTERCROOT=$(REPOROOT)/src/lib-betterc/

ANDROIDFLAGS+=-I$(REPOROOT)/src/lib-basic/
ANDROIDFLAGS+=-I$(REPOROOT)/src/lib-crypto/
include $(BETTERCROOT)/gen.dfiles.mk
LDC?=ldc2
#DC?=/home/carsten/work/tagion_main/tagion_betterc/ldc2-1.20.1-linux-x86_64/bin/ldc2
#LD?=/home/carsten/work/tagion_main/tagion_betterc/../tools/wasi-sdk/bin/wasm-ld
#WAMR_DIR?:=../wasm-micro-runtime/
ANDROID_NDK = $(ANDROID_TOOLS)/android-ndk-r23b

ANDROID_NDK_HOST_TAG=linux-x86_64
CROSS_ROOT=$(ANDROID_NDK)/toolchains/llvm/prebuilt/$(ANDROID_NDK_HOST_TAG)
CROSS_TOOLCHAIN=$(CROSS_ROOT)/bin

ifdef SHARED
ANDROID_LDFLAGS+=-shared
ANDROID_LDFLAGS+=--relocation-model=pic
ANDROIDC_LDFLAGS+=-fpic
ANDROIDC_LDFLAGS+=-shared
#/absolute/
#--shared
#ANDROIDFLAGS+=--fsanitize=pic
EXT=so
else
ANDROIDCFLAGS+= -c
ANDROIDFLAGS+= -c
EXT=o
endif

OBJEXT=o
LIBEXT=so

ifdef M64
ANDROIDFLAGS+=-defaultlib=phobos2-ldc-lto,druntime-ldc-lto
ANDROIDFLAGS+=-link-defaultlib-shared=false
ANDROIDFLAGS+=-flto=full
#ANDROIDFLAGS+=-flto=thin
#ANDROIDFLAGS+=-gcc=/home/carsten/Android/android-ndk-r23b/toolchains/llvm/prebuilt/linux-x86_64/bin/clang
#/home/me/android-ndk-r21/toolchains/llvm/prebuilt/linux-x86_64/bin/aarch64-linux-android21-clan
# ANDROIDFLAGS+=/home/carsten/work/ldc-runtime/ldc-build-runtime.tmp/lib/libdruntime-ldc-lto.a
# ANDROIDFLAGS+=/home/carsten/work/ldc-runtime/ldc-build-runtime.tmp/lib/libphobos2-ldc-lto.a
ANDROIDFLAGS+=/home/carsten/work/tagion/build/aarch64-linux-android/tmp/secp256k1/.libs/libsecp256k1.a

TRIPLET = aarch64-linux-android
LIBANDROID=$(BIN)/libtagion-aarch64.$(LIBEXT)
LIBOBJ=$(BIN)/libtagion-aarch64.$(OBJEXT)
LIBTEST=$(BIN)/libtest-aarch64.$(EXT)
LIBTESTC=$(BIN)/libtestc-aarch64.$(EXT)
ARCH=aarch64linux
ANDROID_EXTRALD_FLAGS+=--fix-cortex-a53-843419
SUB=aarch64-linux-android
ARCH1=aarch64
LINK=/home/carsten/Android/android-ndk-r23b/toolchains/llvm/prebuilt/linux-x86_64/bin/ld -z noexecstack -EL --fix-cortex-a53-843419 --warn-shared-textrel -z now -z relro -z max-page-size=4096 --hash-style=gnu --enable-new-dtags --eh-frame-hdr -m aarch64linux -shared -o bin/libtest-aarch64.so /home/carsten/Android/android-ndk-r23b/toolchains/llvm/prebuilt/linux-x86_64/bin/../sysroot/usr/lib/aarch64-linux-android/30/crtbegin_so.o -L/home/carsten/Android/android-ndk-r23b/toolchains/llvm/prebuilt/linux-x86_64/lib64/clang/12.0.8/lib/linux/aarch64 -L/home/carsten/Android/android-ndk-r23b/toolchains/llvm/prebuilt/linux-x86_64/bin/../lib/gcc/aarch64-linux-android/4.9.x -L/home/carsten/Android/android-ndk-r23b/toolchains/llvm/prebuilt/linux-x86_64/bin/../sysroot/usr/lib/aarch64-linux-android/30 -L/home/carsten/Android/android-ndk-r23b/toolchains/llvm/prebuilt/linux-x86_64/bin/../sysroot/usr/lib/aarch64-linux-android -L/home/carsten/Android/android-ndk-r23b/toolchains/llvm/prebuilt/linux-x86_64/bin/../sysroot/usr/lib -soname bin/libtest-aarch64.so bin/libtest-aarch64.o /home/carsten/Android/android-ndk-r23b/toolchains/llvm/prebuilt/linux-x86_64/lib64/clang/12.0.8/lib/linux/libclang_rt.builtins-aarch64-android.a -l:libunwind.a -ldl -lc /home/carsten/Android/android-ndk-r23b/toolchains/llvm/prebuilt/linux-x86_64/lib64/clang/12.0.8/lib/linux/libclang_rt.builtins-aarch64-android.a -l:libunwind.a -ldl /home/carsten/Android/android-ndk-r23b/toolchains/llvm/prebuilt/linux-x86_64/bin/../sysroot/usr/lib/aarch64-linux-android/30/crtend_so.o

LINK_TAGION=/home/carsten/Android/android-ndk-r23b/toolchains/llvm/prebuilt/linux-x86_64/bin/ld -z noexecstack -EL --fix-cortex-a53-843419 --warn-shared-textrel -z now -z relro -z max-page-size=4096 --hash-style=gnu --enable-new-dtags --eh-frame-hdr -m aarch64linux -shared -o $(LIBANDROID) /home/carsten/Android/android-ndk-r23b/toolchains/llvm/prebuilt/linux-x86_64/bin/../sysroot/usr/lib/aarch64-linux-android/30/crtbegin_so.o -L/home/carsten/Android/android-ndk-r23b/toolchains/llvm/prebuilt/linux-x86_64/lib64/clang/12.0.8/lib/linux/aarch64 -L/home/carsten/Android/android-ndk-r23b/toolchains/llvm/prebuilt/linux-x86_64/bin/../lib/gcc/aarch64-linux-android/4.9.x -L/home/carsten/Android/android-ndk-r23b/toolchains/llvm/prebuilt/linux-x86_64/bin/../sysroot/usr/lib/aarch64-linux-android/30 -L/home/carsten/Android/android-ndk-r23b/toolchains/llvm/prebuilt/linux-x86_64/bin/../sysroot/usr/lib/aarch64-linux-android -L/home/carsten/Android/android-ndk-r23b/toolchains/llvm/prebuilt/linux-x86_64/bin/../sysroot/usr/lib -soname $(LIBANDROID) $(LIBOBJ) /home/carsten/Android/android-ndk-r23b/toolchains/llvm/prebuilt/linux-x86_64/lib64/clang/12.0.8/lib/linux/libclang_rt.builtins-aarch64-android.a -l:libunwind.a -ldl -lc /home/carsten/Android/android-ndk-r23b/toolchains/llvm/prebuilt/linux-x86_64/lib64/clang/12.0.8/lib/linux/libclang_rt.builtins-aarch64-android.a -l:libunwind.a -ldl /home/carsten/Android/android-ndk-r23b/toolchains/llvm/prebuilt/linux-x86_64/bin/../sysroot/usr/lib/aarch64-linux-android/30/crtend_so.o
#/home/carsten/work/tagion/build/aarch64-linux-android/tmp/secp256k1/.libs/libsecp256k1.so
else
ANDROIDFLAGS+= -c

TRIPLET = armv7a-linux-androideabi
LIBANDROID=$(BIN)/libtagion-armv7a.$(LIBEXT)
LIBOBJ=$(BIN)/libtagion-armv7a.$(OBJEXT)
LIBTEST=$(BIN)/libtest-armv7a.$(EXT)
LIBTESTC=$(BIN)/libtestc-armv7a.$(EXT)
ARCH=armelf_linux_eabi
LINK=/home/carsten/Android/android-ndk-r23b/toolchains/llvm/prebuilt/linux-x86_64/bin/ld -z noexecstack -EL --warn-shared-textrel -z now -z relro -z max-page-size=4096 -X --hash-style=gnu --enable-new-dtags --eh-frame-hdr -m armelf_linux_eabi -shared -o bin/libtest-armv7a.so /home/carsten/Android/android-ndk-r23b/toolchains/llvm/prebuilt/linux-x86_64/bin/../sysroot/usr/lib/arm-linux-androideabi/30/crtbegin_so.o -L/home/carsten/Android/android-ndk-r23b/toolchains/llvm/prebuilt/linux-x86_64/lib64/clang/12.0.8/lib/linux/arm -L/home/carsten/Android/android-ndk-r23b/toolchains/llvm/prebuilt/linux-x86_64/bin/../lib/gcc/arm-linux-androideabi/4.9.x -L/home/carsten/Android/android-ndk-r23b/toolchains/llvm/prebuilt/linux-x86_64/bin/../sysroot/usr/lib/arm-linux-androideabi/30 -L/home/carsten/Android/android-ndk-r23b/toolchains/llvm/prebuilt/linux-x86_64/bin/../sysroot/usr/lib/arm-linux-androideabi -L/home/carsten/Android/android-ndk-r23b/toolchains/llvm/prebuilt/linux-x86_64/bin/../sysroot/usr/lib/../lib -L/home/carsten/Android/android-ndk-r23b/toolchains/llvm/prebuilt/linux-x86_64/bin/../sysroot/usr/lib/arm-linux-androideabi/../../lib -L/home/carsten/Android/android-ndk-r23b/toolchains/llvm/prebuilt/linux-x86_64/bin/../sysroot/usr/lib -soname bin/libtest-armv7a.so bin/libtest-armv7a.o /home/carsten/Android/android-ndk-r23b/toolchains/llvm/prebuilt/linux-x86_64/lib64/clang/12.0.8/lib/linux/libclang_rt.builtins-arm-android.a -l:libunwind.a -ldl -lc /home/carsten/Android/android-ndk-r23b/toolchains/llvm/prebuilt/linux-x86_64/lib64/clang/12.0.8/lib/linux/libclang_rt.builtins-arm-android.a -l:libunwind.a -ldl /home/carsten/Android/android-ndk-r23b/toolchains/llvm/prebuilt/linux-x86_64/bin/../sysroot/usr/lib/arm-linux-androideabi/30/crtend_so.o

LINK_TAGION=/home/carsten/Android/android-ndk-r23b/toolchains/llvm/prebuilt/linux-x86_64/bin/ld -z noexecstack -EL --warn-shared-textrel -z now -z relro -z max-page-size=4096 -X --hash-style=gnu --enable-new-dtags --eh-frame-hdr -m armelf_linux_eabi -shared -o $(LIBANDROID) /home/carsten/Android/android-ndk-r23b/toolchains/llvm/prebuilt/linux-x86_64/bin/../sysroot/usr/lib/arm-linux-androideabi/30/crtbegin_so.o -L/home/carsten/Android/android-ndk-r23b/toolchains/llvm/prebuilt/linux-x86_64/lib64/clang/12.0.8/lib/linux/arm -L/home/carsten/Android/android-ndk-r23b/toolchains/llvm/prebuilt/linux-x86_64/bin/../lib/gcc/arm-linux-androideabi/4.9.x -L/home/carsten/Android/android-ndk-r23b/toolchains/llvm/prebuilt/linux-x86_64/bin/../sysroot/usr/lib/arm-linux-androideabi/30 -L/home/carsten/Android/android-ndk-r23b/toolchains/llvm/prebuilt/linux-x86_64/bin/../sysroot/usr/lib/arm-linux-androideabi -L/home/carsten/Android/android-ndk-r23b/toolchains/llvm/prebuilt/linux-x86_64/bin/../sysroot/usr/lib/../lib -L/home/carsten/Android/android-ndk-r23b/toolchains/llvm/prebuilt/linux-x86_64/bin/../sysroot/usr/lib/arm-linux-androideabi/../../lib -L/home/carsten/Android/android-ndk-r23b/toolchains/llvm/prebuilt/linux-x86_64/bin/../sysroot/usr/lib -soname $(LIBANDROID) $(LIBOBJ) /home/carsten/Android/android-ndk-r23b/toolchains/llvm/prebuilt/linux-x86_64/lib64/clang/12.0.8/lib/linux/libclang_rt.builtins-arm-android.a -l:libunwind.a -ldl -lc /home/carsten/Android/android-ndk-r23b/toolchains/llvm/prebuilt/linux-x86_64/lib64/clang/12.0.8/lib/linux/libclang_rt.builtins-arm-android.a -l:libunwind.a -ldl /home/carsten/Android/android-ndk-r23b/toolchains/llvm/prebuilt/linux-x86_64/bin/../sysroot/usr/lib/arm-linux-androideabi/30/crtend_so.o


endif

ifdef SHARED
ANDROIDC_LDFLAGS+=-shared
ANDROIDC_LDFLAGS+=-Wl,-soname,$(LIBTESTC)
#ANDROID_LDFLAGS+=-shared
ANDROID_LDFLAGS+=-L-Wl,-soname,$(LIBTEST)
ANDROID_LDFLAGS+=-L-v
ANDROID_LDFLAGS+=-L--sysroot=$(ANDROID_SYSROOT)
ANDROID_LDFLAGS+=-L-fsanitize=undefined
#ANDROID_LDFLAGS+=-L-Wa,-march=$(TRIPLET)
#ANDROID_LDFLAGS+=-L-triple=$(TRIPLET)

endif
#linker=arm-linux-androideabi-gcc
LIBTEST_OBJ=${LIBTEST:.so=.o}

CROSS_ANDROID_API = 30
CC=$(CROSS_TOOLCHAIN)/$(TRIPLET)$(CROSS_ANDROID_API)-clang

ANDROID_SYSROOT?=$(ANDROID_NDK)/toolchains/llvm/prebuilt/linux-x86_64/sysroot/

ANDROIDFLAGS+=-mtriple=$(TRIPLET)
ANDROIDFLAGS+=-Xcc=--sysroot=$(ANDROID_SYSROOT)

ANDROINDHEADER+=-HCd=$(BIN)/include/
ANDROINDHEADER+=-betterC
# --target=aarch64-linux-gnu
#ANDROIDCFLAGS+=-mtriple=$(TRIPLET)
#ANDROIDCFLAGS+=-Wformat -Werror=format-security

DFILES?=${shell find tagion -name "*.d"}


# OBJS:=${DFILES:.d=.o}

# OBJS:=${addprefix $(BIN)/,$(OBJS)}
#WASM_MOD:=${addsuffix .wasm,$(BIN)/$(MAIN)}

#WASMFLAGS+=-mtriple=wasm32-unknown-unknown-was
ANDROIDFLAGS+=--betterC
#LDWFLAGS+=-z stack-size=4096
#LDWFLAGS+=--initial-memory=65536
#LDWFLAGS+=--sysroot=${WAMR_DIR}/wamr-sdk/app/libc-builtin-sysroot
#LDWFLAGS+=--allow-undefined-file=${WAMR_DIR}/wamr-sdk/app/libc-builtin-sysroot/share/defined-symbols.txt
#LDWFLAGS+=--no-threads,--strip-all,--no-entry -nostdlib
#LDWFLAGS+=${addprefix --export=,$(SYMBOLS)}
#DWFLAGS+=--allow-undefined

#.secondary: $(WOBJS)

SRC?=src
BIN?=bin
vpath %.d $(SRC)

all: $(BIN)/include $(LIBANDROID)

obj: $(BIN)/include $(LIBOBJ)

all-test: $(BIN)/include $(LIBTEST)

all-testc: $(BIN)/include $(LIBTESTC)


info:
	@echo BIN=$(BIN)
	@echo SRC=$(SRC)
	@echo DFILES=$(DFILES)
	@echo LIBANDROID=$(LIBANDROID)

$(BIN)/include:
	mkdir -p $@

# %.o: $(OBJS)
# 	$(LD) $(WOBJS) $(LDWFLAGS) -o $@

$(LIBOBJ): $(DFILES)
	export SYSROOT=$(ANDROID_SYSROOT)
	$(LDC) $(ANDROIDFLAGS) $(DFILES) -c -of$@

$(LIBANDROID): $(LIBOBJ)
	export SYSROOT=$(ANDROID_SYSROOT)
	$(LINK_TAGION)

$(LIBTEST): DFILES:=tests/libtest.d

$(LIBTEST): $(DFILES)
	export SYSROOT=$(ANDROID_SYSROOT)
	$(LDC) $(ANDROIDFLAGS) $(ANDROID_LDFLAGS) $(DFILES) -c -of$(LIBTEST_OBJ)




#	/usr/bin/ld.bfd -plugin /usr/lib/gcc/x86_64-linux-gnu/9/liblto_plugin.so -plugin-opt=/usr/lib/gcc/x86_64-linux-gnu/9/lto-wrapper -plugin-opt=-fresolution=/tmp/cc2j4mBJ.res -plugin-opt=-pass-through=-lgcc -plugin-opt=-pass-through=-lgcc_s -plugin-opt=-pass-through=-lc -plugin-opt=-pass-through=-lgcc -plugin-opt=-pass-through=-lgcc_s --sysroot=/home/carsten/Android/android-ndk-r23b/toolchains/llvm/prebuilt/linux-x86_64/sysroot/ --build-id --eh-frame-hdr -m elf_x86_64 --hash-style=gnu --as-needed -shared -z relro -o $@ /usr/lib/gcc/x86_64-linux-gnu/9/../../../x86_64-linux-gnu/crti.o /usr/lib/gcc/x86_64-linux-gnu/9/crtbeginS.o -L/home/carsten/bin/ldc2-1.26.0-linux-x86_64/bin/../lib -L/usr/lib/gcc/x86_64-linux-gnu/9 -L/usr/lib/gcc/x86_64-linux-gnu/9/../../../x86_64-linux-gnu -L/usr/lib/gcc/x86_64-linux-gnu/9/../../../../lib -L/home/carsten/Android/android-ndk-r23b/toolchains/llvm/prebuilt/linux-x86_64/sysroot/usr/lib/../lib -L/usr/lib/gcc/x86_64-linux-gnu/9/../../.. -L/home/carsten/Android/android-ndk-r23b/toolchains/llvm/prebuilt/linux-x86_64/sysroot/usr/lib $(LIBTEST_OBJ) -soname $@ -v --sysroot=/home/carsten/Android/android-ndk-r23b/toolchains/llvm/prebuilt/linux-x86_64/sysroot/ -fsanitize=undefined -rpath /home/carsten/bin/ldc2-1.26.0-linux-x86_64/bin/../lib --gc-sections -ldl -lm -lgcc --push-state --as-needed -lgcc_s --pop-state -lc -lgcc --push-state --as-needed -lgcc_s --pop-state /usr/lib/gcc/x86_64-linux-gnu/9/crtendS.o /usr/lib/gcc/x86_64-linux-gnu/9/../../../x86_64-linux-gnu/crtn.o

$(LIBTESTC): CFILES:=tests/libtest.c

$(LIBTESTC): $(CFILES)
	export SYSROOT=$(ANDROID_SYSROOT)
	$(CC) $(ANDROIDCFLAGS) $(ANDROIDC_LDFLAGS) $(CFILES) -o $@ -v

#	$(LDC) $(ANDROINDHEADER) hibon/Document.d -o- -c

clean:
	rm -f $(WASM_MOD)
	rm -fR $(WOBJS)
