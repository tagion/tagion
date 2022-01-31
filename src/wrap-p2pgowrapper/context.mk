DSRC_P2PGOWRAPPER := ${call dir.resolve, src}
DTMP_P2PGOWRAPPER := $(DTMP)/p2pgowrapper

CONFIGUREFLAGS_P2PGOWRAPPER :=

include ${call dir.resolve, cross.mk}


ifdef SHARED
${error shared not implemented yet}
LIBP2PGOWRAPPER:=$(DTMP)/libp2pgowrapper.$(DLLEXT)
else
LIBP2PGOWRAPPER:=$(DTMP)/libp2pgowrapper.$(LIBEXT)
endif

$(UNITTEST_BIN): LIBS+=$(LIBP2PGOWRAPPER)

prebuild: $(LIBP2PGOWRAPPER)

p2pgowrapper: $(LIBP2PGOWRAPPER)

clean-p2pgowrapper:
	$(PRECMD)
	${call log.header, $@ :: p2pgowrapper}
	$(RM) $(LIBP2PGOWRAPPER)

clean: clean-p2pgowrapper

proper-p2pgowrapper: clean-p2pgowrapper
	$(PRECMD)
	${call log.header, $@ :: p2pgowrapper}
	$(RMDIR) $(DTMP_P2PGOWRAPPER)

${addprefix $(DTMP_P2PGOWRAPPER)/, c_helper.h libp2pgowrapper.h}: $(LIBP2PGOWRAPPER)

$(LIBP2PGOWRAPPER): $(DTMP_P2PGOWRAPPER)/.way
	$(PRECMD)
	${call log.kvp, build, $(@F)}
	$(CP) $(DSRC_P2PGOWRAPPER)/* $(DTMP_P2PGOWRAPPER)
	$(CD) $(DTMP_P2PGOWRAPPER); $(GO) build -buildmode=c-archive -o $(DTMP_P2PGOWRAPPER)/libp2pgowrapper.a
	$(CD) $(DTMP_P2PGOWRAPPER); $(MV) $(DTMP_P2PGOWRAPPER)/libp2pgowrapper.a $(LIBP2PGOWRAPPER)

env-p2pgowrapper:
	$(PRECMD)
	${call log.header, $@ :: p2pgowrapper}
	${call log.env, LIBP2PGOWRAPPER, $(LIBP2PGOWRAPPER)}

env: env-p2pgowrapper

help-p2pgowrapper:
	$(PRECMD)
	${call log.header, $@ :: p2pgowrapper}
	${call log.help, "make p2pgowrapper", "Builds libp2pgowrapper library "}
	${call log.help, "make clean-p2pgowrapper", "Cleans the library"}
	${call log.help, "make prober-p2pgowrapper", "Erase all reletated to p2pgowrapper build"}
	${call log.help, "make env-p2pgowrapper", " List all p2pgowrapper build environment"}
	${call log.close}

help: help-p2pgowrapper
