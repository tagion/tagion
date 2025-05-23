
#
# Linux x86_64
#
LINUX_X86_64:=x86_64-linux
export DEB_ARCH:=amd64

PLATFORMS+=$(LINUX_X86_64)
ifeq ($(PLATFORM),$(LINUX_X86_64))

$(UNITTEST_BIN): $(DFILES)

unittest: proto-unittest-run

build-unittest: proto-unittest-build

LD_EXPORT_DYN?=-export-dynamic
LD_STRIP:=-s

#
# Platform dependant setting for secp256k1
#
CONFIGUREFLAGS_SECP256K1 += --enable-examples 
endif
