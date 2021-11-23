LP2PGOWRAPPER_DIROOT := ${call dir.resolve, p2p/cgo}
LP2PGOWRAPPER_DSTEPINC := $(DTMP_P2PGOWRAPPER)
LP2PGOWRAPPER_DIFILES := $(LP2PGOWRAPPER_DIROOT)/libp2pgowrapper.di $(LP2PGOWRAPPER_DIROOT)/c_helper.di
LP2PGOWRAPPER_DSTEPFLAGS :=
LP2PGOWRAPPER_PACKAGE := p2p.cgo

$(LP2PGOWRAPPER_DIROOT)/libp2pgowrapper.di: $(LP2PGOWRAPPER_DSTEPINC)/libp2pgowrapper.h $(LP2PGOWRAPPER_DIROOT)/%.way
	${call log.kvp, $(@F)}
	${call log.lines, $<}
	${call log.lines, $@}
	$(PRECMD)$(DSTEP) $(LP2PGOWRAPPER) --package "$(LP2PGOWRAPPER_PACKAGE)" --global-import p2p.cgo.helper $< -o $@

$(LP2PGOWRAPPER_DIROOT)/c_helper.di: $(LP2PGOWRAPPER_DSTEPINC)/c_helper.h $(LP2PGOWRAPPER_DIROOT)/%.way
	${call log.kvp, $@(F)}
	${call log.lines, $<}
	${call log.lines, $@}
	$(PRECMD)$(DSTEP) $(LP2PGOWRAPPER) --package "$(LP2PGOWRAPPER_PACKAGE)" $< -o $@

# libp2pgowrapper.h is generated during compilation of go library
$(DTMP_P2PGOWRAPPER)/%.h: $(DTMP)/libp2pgowrapper.a
	@