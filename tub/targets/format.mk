export DFORMAT?=dfmt

# The .editorconfig is placed in the REPOROOT
DFORMAT_FLAGS+= -c $(REPOROOT)/

CHANGED_FILES=${shell git --no-pager diff  --name-only}
CHANGED_DFILES=${filter %.d,$(CHANGED_FILES)}
CHANGED_DFILES_TMP=${addsuffix .tmp,$(CHANGED_DFILES)}

ALL_DFILES=${shell find $(DSRC) -name "*.d"}
ALL_DFILES_TMP=${addsuffix .tmp,$(ALL_DFILES)}


format: $(CHANGED_DFILES_TMP)

format-all: $(ALL_DFILES_TMP)

format-%: %.tmp


.PHONY: format format-all


help-format:
	$(PRECMD)
	${call log.header, $@ :: help}
	${call log.help, "make format", "Formats changed d-source files"}
	${call log.help, "make format-all", "Formats all d-source files"}
	${call log.help, "make format-<file>", "Formats only <file>"}
	${call log.help, "make env-format", "List all dstep parameters"}
	${call log.close}


.PHONY: help-format

help: help-format

env-format:
	$(PRECMD)
	${call log.header, $@ :: env}
	${call log.kvp, DFORMAT, $(DFORMAT)}
	${call log.env, DFORMAT_FLAGS, $(DFORMAT_FLAGS)}
	${call log.env, CHANGED_DFILES, $(CHANGED_DFILES)}
	${call log.env, CHANGED_DFILES_TMP, $(CHANGED_DFILES_TMP)}
	${call log.close}

.PHONY: env-format

env: env-format

%.d.tmp: %.d
	$(PRECMD)
	$(DFORMAT) $(DFORMAT_FLAGS) $< >$@
	# Detect platform and use appropriate stat command
	if [ "$(shell uname)" = "Darwin" ]; then \
		size=`stat -f%z $@ 2>/dev/null || echo 0`; \
	else \
		size=`stat -c%s $@ 2>/dev/null || echo 0`; \
	fi; \
	echo "$@ size $stat" > /tmp/$(F@).log
	if [ $$size -ne 0 ]; then
	cp -a $@ $<
	fi
	$(RM) $@