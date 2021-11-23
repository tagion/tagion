include ${call dir.resolve, dstep.mk}

ifeq ($(OS),darwin)
# We need these flags on Darwin (possibly only on arm64 macOS)
# because when libp2p-go compiles, it can't find required dependencies.
# This solution was found on StackOverflow
$(DBIN)/libp2pgowrapper.test: LDCFLAGS += -L-framework -LCoreFoundation -L-framework -LSecurity
endif

DEPS += wrap-p2pgowrapper

libp2pgowrapper.preconfigure: $(LP2PGOWRAPPER_DIFILES)
libp2pgowrapper.configure: SOURCE := p2p/*.d p2p/cgo/*.di

$(DBIN)/libp2pgowrapper.test: $(DTMP)/libp2pgowrapper.a

