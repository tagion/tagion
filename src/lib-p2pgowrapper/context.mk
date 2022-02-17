DEPS += wrap-p2pgowrapper

PROGRAM := libp2pgowrapper

include ${call dir.resolve, dstep.mk}

ifeq ($(OS),darwin)
# We need these flags on Darwin (possibly only on arm64 macOS)
# because when libp2p-go compiles, it can't find required dependencies.
# This solution was found on StackOverflow
$(DBIN)/$(PROGRAM).test: LDCFLAGS += -L-framework -LCoreFoundation -L-framework -LSecurity
endif

LP2PGOWRAPPER_DIFILES:=${addprefix $(LIBP2PGOWRAPPER_DIROOT)/, c_helper.di libp2pgowrapper.di}
#
# D files requires c_helper.di libp2pgowrapper.di
#
$(LIBP2PGOWRAPPER_DFILES): ${addprefix $(LIBP2PGOWRAPPER_DIROOT)/, c_helper.di libp2pgowrapper.di}


# $(PROGRAM).preconfigure: $(LP2PGOWRAPPER_DIFILES)
# $(PROGRAM).configure: SOURCE := p2p/*.d p2p/cgo/*.di

# $(DBIN)/$(PROGRAM).test: $(DTMP)/libp2pgowrapper.a
