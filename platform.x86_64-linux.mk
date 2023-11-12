
#
# Linux x86_64
#
LINUX_X86_64:=x86_64-linux

PLATFORMS+=$(LINUX_X86_64)
ifeq ($(PLATFORM),$(LINUX_X86_64))
DINC+=${shell find $(DSRC) -maxdepth 1 -type d -path "*src/lib-*" }
#DFILES?=${shell find $(DSRC) -type f -name "*.d" -path "*src/lib-*" -a -not -path "*/tests/*" -a -not -path "*/c/*" -a -not -path "*/unitdata/*"}

$(UNITTEST_BIN): $(DFILES)

proto-unittest-build: LIBS+=$(LIBSECP256K1)
proto-unittest-build: LIBS+=$(LIBNNG)

unittest: proto-unittest-run

build-unittest: proto-unittest-build

DFLAGS+=$(DDEBUG)

#
# Platform dependend setting for secp256k1
#
CONFIGUREFLAGS_SECP256K1 += --enable-examples 
endif
