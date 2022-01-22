DEPS += wrap-p2pgowrapper

PROGRAM := libp2pgowrapper

include ${call dir.resolve, dstep.mk}

ifeq ($(OS),darwin)
# We need these flags on Darwin (possibly only on arm64 macOS)
# because when libp2p-go compiles, it can't find required dependencies.
# This solution was found on StackOverflow
$(DBIN)/$(PROGRAM).test: LDCFLAGS += -L-framework -LCoreFoundation -L-framework -LSecurity
endif


#$(LP2PGOWRAPPER_DFILES): ${addprefix $(DTMP_P2PGOWRAPPER)/, c_helper.h libp2pgowrapper.h}

$(LP2PGOWRAPPER_DFILES): ${addprefix $(LP2PGOWRAPPER_DIROOT)/, c_helper.di libp2pgowrapper.di}

#$(DIFILES.p2p.cgo)

#/home/carsten/work/cross_regression/src/lib-p2pgowrapper/p2p/cgo/c_helper.di

#.SECONDEXPANSION:

test22:
	@echo $(LIBP2PGOWRAPPER)
	@echo $(LP2PGOWRAPPER_DFILES)
	@echo $(DIFILES.p2p.cgo)
	@echo $(addprefix $(LP2PGOWRAPPER_DIROOT), c_helper.di libp2pgowrapper.di)

$(PROGRAM).preconfigure: $(LP2PGOWRAPPER_DIFILES)
$(PROGRAM).configure: SOURCE := p2p/*.d p2p/cgo/*.di

$(DBIN)/$(PROGRAM).test: $(DTMP)/libp2pgowrapper.a

test31:
	@echo $(LIBP2PGOWRAPPER)
	@echo $(HFILES.p2p.cgo)
