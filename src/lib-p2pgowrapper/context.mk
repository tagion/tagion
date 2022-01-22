DEPS += wrap-p2pgowrapper

PROGRAM := libp2pgowrapper

include ${call dir.resolve, dstep.mk}

ifeq ($(OS),darwin)
# We need these flags on Darwin (possibly only on arm64 macOS)
# because when libp2p-go compiles, it can't find required dependencies.
# This solution was found on StackOverflow
$(DBIN)/$(PROGRAM).test: LDCFLAGS += -L-framework -LCoreFoundation -L-framework -LSecurity
endif


$(DIFILES.p2p.cgo): $(LIBP2PGOWRAPPER)

$(LP2PGOWRAPPER_DFILES): $(DIFILES.p2p.cgo)

#.SECONDEXPANSION:

test22: $(DIFILES.p2p.cgo)
	@echo $(LIBP2PGOWRAPPER)
	@echo $(LP2PGOWRAPPER_DFILES)
	@echo $(DIFILES.p2p.cgo)

#$()
$(PROGRAM).preconfigure: $(LP2PGOWRAPPER_DIFILES)
$(PROGRAM).configure: SOURCE := p2p/*.d p2p/cgo/*.di

$(DBIN)/$(PROGRAM).test: $(DTMP)/libp2pgowrapper.a

test31:
	@echo $(LIBP2PGOWRAPPER)
	@echo $(HFILES.p2p.cgo)
