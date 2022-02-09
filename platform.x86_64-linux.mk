
#
# Linux x86_64
#
LINUX_X86_64:=x86_64-linux

PLATFORMS+=$(LINUX_X86_64)
ifeq ($(PLATFORM),$(LINUX_X86_64))

DINC+=${shell find $(DSRC) -maxdepth 1 -type d -path "*src/lib-*" }
ifdef BETTERC
DFILES?=${shell find $(DSRC) -type f -name "*.d" -path "*src/lib-betterc*" -a -not -path "*/tests/*"}
else
DFILES?=${shell find $(DSRC) -type f -name "*.d" -path "*src/lib-*" -a -not -path "*/tests/*"}
endif

prebuild-linux: $(DBUILD)/.way
prebuild-linux: secp256k1 openssl p2pgowrapper
prebuild-linux: dstep
prebuild-linux: $(DBUILD)/gen.ddeps.mk

traget-linux: prebuild-linux
#target-linux: | secp256k1 openssl p2pgowrapper
# target-linux: | secp256k1 p2pgowrapper
# target-linux: dstep
# target-linux: $(DBUILD)/gen.ddeps.mk
#traget-linux: $(DBUILD)/gen.dfiles.mk

unittest: LIBS+=$(LIBOPENSSL)
unittest: LIBS+=$(LIBSECP256K1)
unittest: LIBS+=$(LIBP2PGOWRAPPER)
unittest: prebuild-linux
unittest: $(DFILES)
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


tagionwave: prebuild-linux
tagionwave: target-tagionwave
bin: tagionwave

target-linux:
	@echo DBUILD $(DBUILD)

.PHONY: traget-linux

test-linux:

endif
