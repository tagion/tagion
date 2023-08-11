
#
# Linux x86_64
#
LINUX_X86_64:=x86_64-linux

PLATFORMS+=$(LINUX_X86_64)
ifeq ($(PLATFORM),$(LINUX_X86_64))
ANDROID_ABI=x86_64
DINC+=${shell find $(DSRC) -maxdepth 1 -type d -path "*src/lib-*" }
#DFILES?=${shell find $(DSRC) -type f -name "*.d" -path "*src/lib-*" -a -not -path "*/tests/*" -a -not -path "*/c/*" -a -not -path "*/unitdata/*"}

WRAPS+=secp256k1 p2pgowrapper $(SSLIMPLEMENTATION) $(ZMQIMPLEMENTATION) 


.PHONY: prebuild-linux

$(UNITTEST_BIN): $(DFILES)

proto-unittest-build: LIBS+=$(SSLIMPLEMENTATION)
proto-unittest-build: LIBS+=$(LIBSECP256K1)
proto-unittest-build: LIBS+=$(LIBP2PGOWRAPPER)
proto-unittest-build: LIBS+=$(LIBNNG)

unittest: proto-unittest-run

build-unittest: proto-unittest-build

endif
