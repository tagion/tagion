#include betterc_setup.mk
LDC?=ldc2
#DC?=/home/carsten/work/tagion_main/tagion_betterc/ldc2-1.20.1-linux-x86_64/bin/ldc2
#LD?=/home/carsten/work/tagion_main/tagion_betterc/../tools/wasi-sdk/bin/wasm-ld
#WAMR_DIR?:=../wasm-micro-runtime/
ANDROID_NDK = $(ANDROID_TOOLS)/android-ndk-r23b

ifdef SHARED
ANDROIDFLAGS+=-shared
ANDROIDFLAGS+=--relocation-model=pic
EXT=so
else
EXT=o
endif

ifdef M64
TRIPLET = aarch64-linux-android
LIBANDROID=$(BIN)/libandroid-arch64.$(EXT)
else
TRIPLET = armv7a-linux-androideabi
LIBANDROID=$(BIN)/libandroid-armv7a.$(EXT)
endif
ANDROID_SYSROOT?=$(ANDROID_NDK)/toolchains/llvm/prebuilt/linux-x86_64/sysroot/
#-isystem $NDK/sysroot/usr/include/$TRIPLE
#-Xcc=--sysroot=$ARMTARGETROOT

ANDROIDFLAGS+=-mtriple=$(TRIPLET)

ANDROIDFLAGS+=-Xcc=--sysroot=$(ANDROID_SYSROOT)
#SHARED=1



DFILES:=${shell find hibon -name "*.d"}
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

all: $(BIN) $(LIBANDROID)

info:
	@echo BIN=$(BIN)
	@echo SRC=$(SRC)
	@echo DFILES=$(DFILES)
	@echo LIBANDROID=$(LIBANDROID)

$(BIN):
	mkdir -p $@

# %.o: $(OBJS)
# 	$(LD) $(WOBJS) $(LDWFLAGS) -o $@

$(LIBANDROID): $(DFILES)
	$(LDC) $(ANDROIDFLAGS) $(DFILES) -c -of$@


clean:
	rm -f $(WASM_MOD)
	rm -fR $(WOBJS)
