include ${call dir.resolve, dstep.mk}

DEPS += wrap-p2pgowrapper

libp2pgowrapper.preconfigure: $(LP2PGOWRAPPER_DIFILES)
libp2pgowrapper.configure: SOURCE := p2p/*.d

$(DBIN)/libp2pgowrapper.test: $(DTMP)/libp2pgowrapper.a

