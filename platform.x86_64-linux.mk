
#
# Linux x86_64
#
LINUX_X86_64:=x86_64-linux

PLATFORMS+=$(LINUX_X86_64)
ifeq ($(PLATFORM),$(LINUX_X86_64))
ANDROID_ABI=x86_64
DINC+=${shell find $(DSRC) -maxdepth 1 -type d -path "*src/lib-*" }
DINC+=${shell find $(DBDD) -maxdepth 1 -type d -path "*bdd" }


DFILES?=${shell find $(DSRC) -type f -name "*.d" -path "*src/lib-*" -a -not -path "*/tests/*" -a -not -path "*/unitdata/*"}
DBDDFILES?=${shell find $(DBDD) -type f -name "*.d" -path "*bdd/tagion/testbench*"}

WRAPS+=secp256k1 p2pgowrapper openssl

.PHONY: prebuild-linux

$(UNITTEST_BIN): $(DFILES)

unittest: LIBS+=$(LIBOPENSSL)
unittest: LIBS+=$(LIBSECP256K1)
unittest: LIBS+=$(LIBP2PGOWRAPPER)
unittest: proto-unittest-run

endif
