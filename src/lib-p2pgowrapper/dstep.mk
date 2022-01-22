

LP2PGOWRAPPER_DIROOT := ${call dir.resolve, p2p/cgo}
LP2PGOWRAPPER_DSTEPINC = $(DTMP_P2PGOWRAPPER)
LP2PGOWRAPPER_PACKAGE := p2p.cgo

LP2PGOWRAPPER_DFILES := ${wildcard ${call dir.resolve, p2p}/*.d}

$(LP2PGOWRAPPER_DIROOT)/libp2pgowrapper.di: DSTEPFLAGS += --global-import=$(LP2PGOWRAPPER_PACKAGE).c_helper

${call DSTEP_DO,$(LP2PGOWRAPPER_PACKAGE),$(DTMP_P2PGOWRAPPER),$(LP2PGOWRAPPER_DIROOT),$(LP2PGOWRAPPER_DFILES)}

#
# Pre-declare the header files
#
#HFILES.p2p.cgo=${addprefix $(DTMP_P2PGOWRAPPER)/, c_helper.h libp2pgowrapper.h}

#DIFILES.p2p.cgo=${addprefix $(LP2PGOWRAPPER_DIROOT)/, c_helper.di libp2pgowrapper.di}

test34:
	@echo $(LIBP2PGOWRAPPER)
	@echo HFILES.p2p.cgo=$(HFILES.p2p.cgo)
	@echo DIFILES_notdir.p2p.cgo $(DIFILES_notdir.p2p.cgo)
	@echo DTMP_P2PGOWRAPPER=$(DTMP_P2PGOWRAPPER)
	@echo "----" ${addprefix $(DTMP_P2PGOWRAPPER)/, c_helper.h libp2pgowrapper.h}
	@echo $(DIFILES_notdir.p2p.cgo)
	@echo DIFILES.p2p.cgo=$(DIFILES.p2p.cgo)
	@echo LP2PGOWRAPPER_DIROOT = $(LP2PGOWRAPPER_DIROOT)
	@echo ${addprefix $(LP2PGOWRAPPER_DIROOT)/, c_helper.di libp2pgowrapper.di}
