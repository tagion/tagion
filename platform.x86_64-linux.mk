
#
# Linux x86_64
#
LINUX_X86_64:=x86_64-linux

PLATFORMS+=$(LINUX_X86_64)
ifeq ($(PLATFORM),$(LINUX_X86_64))

$(UNITTEST_BIN): $(DFILES)

unittest: proto-unittest-run

build-unittest: proto-unittest-build

ifndef DEBUG_DISABLE
DFLAGS+=$(DDEBUG)
endif

#
# Platform dependant setting for secp256k1
#
CONFIGUREFLAGS_SECP256K1 += --enable-examples 
endif
