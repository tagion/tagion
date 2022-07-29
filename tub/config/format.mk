

DFORMAT?=clang-format
DFORMAT_FLAGS+=-style=$(REPOROOT)/.format.config

CHANGED_FILES=${shell git --no-pager diff  --name-only}
CHANGED_DFILES=${filter %.d,$(CHANGED_FILES)}

ALL_DFILES=${shell find $(DSRC) -name "*.d"}

format:
	$(PRECMD)
	$(DFORMAT) -style=file -i $(CHANGED_DFILES)

format-all:
	$(PRECMD)
	$(DFORMAT) -style=file -i $(ALL_DFILES)


help-format:
	$(PRECMD)
	${call log.header, $@ :: help}
	${call log.help, "make format", "Formats changed d-source files"}
	${call log.help, "make format-all", "Formats all d-source files"}
	${call log.help, "make env-format", "List all dstep parameters"}
	${call log.close}


.PHONY: help-format

help: help-format

env-format:
	$(PRECMD)
	$(call log.header, $@ :: env)
	${call log.env, CHANGED_DFILES, $(CHANGED_DFILES)}
	${call log.close}

.PHONY: env-format

env: env-format
