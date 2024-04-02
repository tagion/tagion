
#
# Darwin
#
DARWIN_arm64:=arm64-darwin
PLATFORMS+=$(DARWIN_arm64)

ifeq ($(PLATFORM),$(DARWIN_arm64))

$(UNITTEST_BIN): $(DFILES)

unittest: proto-unittest-run

build-unittest: proto-unittest-build

endif
