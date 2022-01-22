

LP2PGOWRAPPER_DIROOT := ${call dir.resolve, p2p/cgo}
LP2PGOWRAPPER_DSTEPINC := $(DTMP_P2PGOWRAPPER)
LP2PGOWRAPPER_PACKAGE := p2p.cgo

LP2PGOWRAPPER_DFILES := ${wildcard ${call dir.resolve, p2p}/*.d}

$(LP2PGOWRAPPER_DIROOT)/libp2pgowrapper.di: DSTEPFLAGS += --global-import=$(LP2PGOWRAPPER_PACKAGE).c_helper

${call DSTEP_DO,$(LP2PGOWRAPPER_PACKAGE),$(DTMP_P2PGOWRAPPER),$(LP2PGOWRAPPER_DIROOT),$(LP2PGOWRAPPER_DFILES)}

# libp2pgowrapper.h is generated during compilation of go library
$(DTMP_P2PGOWRAPPER)/%.h: $(DTMP)/libp2pgowrapper.a
