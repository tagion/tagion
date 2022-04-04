
#
# Linux x86_64
#
LINUX_X86_64_BETTERC:=x86_64-linux-betterC

PLATFORMS+=$(LINUX_X86_64_BETTERC)
ifeq ($(PLATFORM),$(LINUX_X86_64_BETTERC))
ANDROID_ABI=x86_64
DFLAGS+=$(DVERSION)=TINY_AES
MTRIPLE:=x86_64-linux
TRIPLET:=$(MTRIPLE)-android

UNITTEST_FLAGS:=$(DDEBUG) $(DDEBUG_SYMBOLS)
DINC+=${shell find $(DSRC) -maxdepth 1 -type d -path "*src/lib-*" }
ifdef BETTERC
DFLAGS+=$(DBETTERC)
DFILES?=${shell find $(DSRC) -type f -name "*.d" -path "*src/lib-betterc/*" -a -not -path "*/tests/*" -a -not -path "*/unitdata/*"}
unittest: DFILES+=src/lib-betterc/tests/unittest.d

else
DFILES?=${shell find $(DSRC) -type f -name "*.d" \( -path "*src/lib-betterC/*" -o -path "*src/lib-crypto/*" -o -path "*src/lib-hibon/*"  -o -path "*src/lib-utils/*" -o -path "*src/lib-basic/*"  -o -path "*src/lib-logger/*" \) -a -not -path "*/tests/*" -a -not -path "*/unitdata/*"}
#UNITTEST_FLAGS+=$(DUNITTEST) $(DMAIN)
#$(DDEBUG) $(DDEBUG_SYMBOLS)
endif


WRAPS+=secp256k1
WRAPS+=druntime


prebuild-extern-linux: $(DBUILD)/.way

.PHONY: prebuild-linux

#traget-linux: prebuild-linux
#target-linux: | secp256k1 openssl p2pgowrapper
# target-linux: | secp256k1 p2pgowrapper
$(UNITTEST_BIN): $(DFILES)

# unittest: LIBS+=$(LIBOPENSSL)
unittest: LIBS+=$(LIBSECP256K1)
# unittest: LIBS+=$(LIBP2PGOWRAPPER)
unittest: proto-unittest-run

target-android: LD=$(ANDROID_LD)
target-android: CC=$(ANDROID_CC)
target-android: CPP=$(ANDROID_CPP)
#target-android: LDFLAGS=$(ANDROID_LDFLAGS)
target-android: DFLAGS+=$(ANDROID_DFLAGS)
target-android: LIBS+=$(LDC_BUILD_RUNTIME_TMP)/lib/libdruntime-ldc.a
target-android: LIBS+=$(LDC_BUILD_RUNTIME_TMP)/lib/libphobos2-ldc.a


target-android: LDFLAGS+=$(ANDROID_LDFLAGS)

target-android: LDFLAGS+=$(ANDROID_SYSTEM)
target-android: LDFLAGS+=-L/home/carsten/Android/android-ndk-r23b/toolchains/llvm/prebuilt/linux-x86_64/lib64/clang/12.0.8/lib/linux/aarch64
target-android: LDFLAGS+=-L/home/carsten/Android/android-ndk-r23b/toolchains/llvm/prebuilt/linux-x86_64/bin/../lib/gcc/aarch64-linux-android/4.9.x
target-android: LDFLAGS+=-L/home/carsten/Android/android-ndk-r23b/toolchains/llvm/prebuilt/linux-x86_64/bin/../sysroot/usr/lib/aarch64-linux-android/30
target-android: LDFLAGS+=-L/home/carsten/Android/android-ndk-r23b/toolchains/llvm/prebuilt/linux-x86_64/bin/../sysroot/usr/lib/aarch64-linux-android
target-android: LDFLAGS+=-L/home/carsten/Android/android-ndk-r23b/toolchains/llvm/prebuilt/linux-x86_64/bin/../sysroot/usr/lib
target-android: LDFLAGS+=-soname $(LIBRARY)
target-android: LDFLAGS+=/home/carsten/Android/android-ndk-r23b/toolchains/llvm/prebuilt/linux-x86_64/lib64/clang/12.0.8/lib/linux/libclang_rt.builtins-aarch64-android.a
target-android: LDFLAGS+=-l:libunwind.a
target-android: LDFLAGS+=-ldl
target-android: LDFLAGS+=-lc
target-android: LDFLAGS+=-lm
# target-android: LDFLAGS+=/home/carsten/Android/android-ndk-r23b/toolchains/llvm/prebuilt/linux-x86_64/lib64/clang/12.0.8/lib/linux/libclang_rt.builtins-aarch64-android.a
# target-android: LDFLAGS+=-l:libunwind.a
# target-android: LDFLAGS+=-ldl
target-android: LDFLAGS+=/home/carsten/Android/android-ndk-r23b/toolchains/llvm/prebuilt/linux-x86_64/bin/../sysroot

endif
