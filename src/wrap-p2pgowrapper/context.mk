DSRC_P2PGOWRAPPER := ${call dir.resolve, p2pwrapper}
DTMP_P2PGOWRAPPER := $(DTMP)/p2pgowrapper


ifdef SHARED
#${error shared not implemented yet}
LIBP2PGOWRAPPER:=$(DTMP)/libp2pgowrapper.$(DLLEXT)
$(LIBP2PGOWRAPPER): GO_FLAGS= build -buildmode=c-shared
else
LIBP2PGOWRAPPER:=$(DTMP)/libp2pgowrapper.$(STAEXT)
$(LIBP2PGOWRAPPER): GO_FLAGS= build -buildmode=c-archive
endif

prebuild1: $(LIBP2PGOWRAPPER)

libp2p: $(LIBP2PGOWRAPPER)
p2pgowrapper: $(LIBP2PGOWRAPPER)

proper-libp2p: proper-p2pgowrapper
proper-p2pgowrapper:
	$(PRECMD)
	${call log.header, $@ :: proper}
	$(RMDIR) $(DTMP_P2PGOWRAPPER)
	$(RM) $(LIBP2PGOWRAPPER)


.PHONY: proper-p2pgowrapper

${addprefix $(DTMP_P2PGOWRAPPER)/, c_helper.h libp2pgowrapper.h}: $(LIBP2PGOWRAPPER)

P2PGOWRAPPER_HEAD := $(REPOROOT)/.git/modules/src/wrap-p2pgowrapper/p2pwrapper/HEAD
P2PGOWRAPPER_GIT_MODULE := $(DSRC_P2PGOWRAPPER)/.git

$(P2PGOWRAPPER_GIT_MODULE): 
	git submodule update --init --depth=1 $(DSRC_P2PGOWRAPPER)

$(LIBP2PGOWRAPPER): | $(DTMP_P2PGOWRAPPER)/.way $(P2PGOWRAPPER_HEAD) $(P2PGOWRAPPER_GIT_MODULE)
	$(PRECMD)
	${call log.kvp, build, $(@F)}
	$(CP) $(DSRC_P2PGOWRAPPER)/* $(DTMP_P2PGOWRAPPER)
	$(CD) $(DTMP_P2PGOWRAPPER); $(GO) $(GO_FLAGS) -o $(LIBP2PGOWRAPPER)
	$(MV) $(DTMP)/libp2pgowrapper.h $(DTMP_P2PGOWRAPPER)

env-p2pgowrapper:
	$(PRECMD)
	${call log.header, $@ :: env}
	${call log.kvp, GOOS, $(GOOS)}
	${call log.kvp, GOARCH, $(GOARCH)}
	${call log.kvp, DSRC_P2PGOWRAPPER, $(DSRC_P2PGOWRAPPER)}
	${call log.kvp, DTMP_P2PGOWRAPPER, $(DTMP_P2PGOWRAPPER)}
	${call log.env, LIBP2PGOWRAPPER, $(LIBP2PGOWRAPPER)}
	${call log.close}

env: env-p2pgowrapper

help-p2pgowrapper:
	$(PRECMD)
	${call log.header, $@ :: help}
	${call log.help, "make p2pgowrapper", "Builds libp2pgowrapper library "}
	${call log.help, "make proper-p2pgowrapper", "Erase all reletated to p2pgowrapper build"}
	${call log.help, "make env-p2pgowrapper", " List all p2pgowrapper build environment"}
	${call log.close}

help: help-p2pgowrapper
