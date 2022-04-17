
#
# Linux x86_64
#
LINUX_X86_64:=x86_64-linux

PLATFORMS+=$(LINUX_X86_64)
ifeq ($(PLATFORM),$(LINUX_X86_64))
ANDROID_ABI=x86_64
DINC+=${shell find $(DSRC) -maxdepth 1 -type d -path "*src/lib-*" }
# ifdef BETTERC
# DFILES?=${shell find $(DSRC) -type f -name "*.d" -path "*src/lib-betterc*" -a -not -path "*/tests/*"}
# else
DFILES?=${shell find $(DSRC) -type f -name "*.d" -path "*src/lib-*" -a -not -path "*/tests/*" -a -not -path "*/unitdata/*"}
# endif

WRAPS+=secp256k1 p2pgowrapper openssl

prebuild-extern-linux: $(DBUILD)/.way

.PHONY: prebuild-linux

#traget-linux: prebuild-linux
#target-linux: | secp256k1 openssl p2pgowrapper
# target-linux: | secp256k1 p2pgowrapper
$(UNITTEST_BIN): $(DFILES)

unittest: LIBS+=$(LIBOPENSSL)
unittest: LIBS+=$(LIBSECP256K1)
unittest: LIBS+=$(LIBP2PGOWRAPPER)
unittest: proto-unittest-run

endif
