LP2PGOWRAPPER_DIROOT := ${call dir.resolve, p2p/cgo}
LP2PGOWRAPPER_DSTEPINC := $(DTMP_P2PGOWRAPPER)
LP2PGOWRAPPER_HFILES := $(DTMP_P2PGOWRAPPER)/helper.h $(DTMP_P2PGOWRAPPER)/libp2pgowrapper.h
LP2PGOWRAPPER_HNOTDIR := ${notdir $(LP2PGOWRAPPER_HFILES)}
LP2PGOWRAPPER_DINOTDIR := $(LP2PGOWRAPPER_HNOTDIR:.h=.di)
LP2PGOWRAPPER_DIFILES := ${addprefix $(LP2PGOWRAPPER_DIROOT)/,$(LP2PGOWRAPPER_DINOTDIR)}
LP2PGOWRAPPER_DSTEPFLAGS :=
LP2PGOWRAPPER_PACKAGE := p2p.cgo

$(LP2PGOWRAPPER_DIROOT)/%.di: $(LP2PGOWRAPPER_HFILES) $(LP2PGOWRAPPER_DIROOT)/%.way
	${call log.kvp, $*.di}
	${call log.lines, $+}
	${call log.lines, $<}
	${call log.lines, $@}
	$(PRECMD)$(DSTEP) $(LP2PGOWRAPPER) --package "$(LP2PGOWRAPPER_PACKAGE)" $< -o $@

# libp2pgowrapper.h is generated during compilation of go library
$(DTMP_P2PGOWRAPPER)/%.h: $(DTMP)/libp2pgowrapper.a
	@