
#
# Linux x86_64
#
LINUX_X86_64_BETTERC:=x86_64-linux-betterC

PLATFORMS+=$(LINUX_X86_64_BETTERC)
ifeq ($(PLATFORM),$(LINUX_X86_64_BETTERC))
DFLAGS+=$(DVERSION)=TINY_AES
MTRIPLE:=x86_64-linux
UNITTEST_FLAGS+=$(DDEBUG) $(DDEBUG_SYMBOLS)
DINC+=${shell find $(DSRC) -maxdepth 1 -type d -path "*src/lib-*" }
ifdef BETTERC
DFLAGS+=$(DBETTERC)
DFILES?=${shell find $(DSRC) -type f -name "*.d" -path "*src/lib-betterc/*" -a -not -path "*/tests/*" -a -not -path "*/unitdata/*"}
else
DFILES?=${shell find $(DSRC) -type f -name "*.d" \( -path "*src/lib-betterC/*" -o -path "*src/lib-crypto/*" -o -path "*src/lib-hibon/*"  -o -path "*src/lib-utils/*" -o -path "*src/lib-basic/*"  -o -path "*src/lib-logger/*" \) -a -not -path "*/tests/*" -a -not -path "*/unitdata/*"}
UNITTEST_FLAGS+=$(DUNITTEST) $(DMAIN)
#$(DDEBUG) $(DDEBUG_SYMBOLS)
endif


#DFILES+=src/lib-betterc/tests/unittest.d
WRAPS+=secp256k1

prebuild-extern-linux: $(DBUILD)/.way
#prebuild-extern-linux: secp256k1 openssl p2pgowrapper
#dstep: prebuild-extern-linux
#prebuild-linux: |prebuild-extern-linux
#prebuild-linux: dstep
#prebuild-linux: dstep
#.PHONY: prebuild-extern-linux

#prebuild-linux: $(DBUILD)/gen.ddeps.mk
.PHONY: prebuild-linux

#traget-linux: prebuild-linux
#target-linux: | secp256k1 openssl p2pgowrapper
# target-linux: | secp256k1 p2pgowrapper
$(UNITTEST_BIN): $(DFILES)

# unittest: LIBS+=$(LIBOPENSSL)
unittest: LIBS+=$(LIBSECP256K1)
# unittest: LIBS+=$(LIBP2PGOWRAPPER)
unittest: proto-unittest-run

hibonutil: prebuild-linux
hibonutil: target-hibonutil
bin: hibonutil

dartutil: prebuild-linux
dartutil: target-dartutil
bin: dartutil

wasnutil: prebuild-linux
wasmutil: target-wasmutil
bin: wasmutil

wallet: prebuild-linux
wallet: target-wallet
bin: wallet


tagionwave: |prebuild-linux
tagionwave: target-tagionwave
bin: tagionwave

target-linux:
	@echo DBUILD $(DBUILD)

.PHONY: traget-linux

test-linux:

endif
