
#
# Linux x86_64
#
LINUX_X86_64_BETTERC:=x86_64-linux-betterC

PLATFORMS+=$(LINUX_X86_64_BETTERC)
ifeq ($(PLATFORM),$(LINUX_X86_64_BETTERC))
DFLAGS+=$(DVERSION)=TINY_AES
MTRIPLE:=x86_64-linux
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

endif
