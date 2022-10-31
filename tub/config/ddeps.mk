# D ddeps macro function
# $(DBUILD)/gen.ddeps.json: $(DBUILD)/.way

# $(DBUILD)/gen.ddeps.json: $(DBUILD)/gen.dfiles.mk

# $(DBUILD)/gen.ddeps.mk: $(DBUILD)/gen.ddeps.json

$(DBUILD)/gen.dfiles.mk:
	@echo dfiles $@
	if [ ! -f "$@" ]; then
	$(PRECMD)
	printf "%s += %s\n" ${addprefix DFILES , ${sort $(DFILES)}} >> $@
	fi
	if [ "$(BDDFILES)" != "" ]; then
	printf "%s += %s\n" ${addprefix DFILES , $(BDDFILES)} >> $@
	fi

$(DBUILD)/gen.ddeps.json: $(DBUILD)/gen.dfiles.mk
	$(PRECMD)
	if [ ! -f "$@" ]; then
	${call log.kvp, $(@F), $(PLATFORM)}
	$(DC) $(DFLAGS) $(UNITTEST_FLAGS) ${addprefix -I,$(DINC)} --o- $(NO_OBJ)  $(DJSON)=$@ ${sort $(DFILES)}
	fi

ddeps: $(DBUILD)/gen.ddeps.json
	$(PRECMD)
	if [ ! -f "$@" ]; then
	${call log.kvp, $(@F), $(PLATFORM)}
	$(DTUB)/ddeps.d  --srcdir=DSRC --objdir=DOBJ $< -o$(DBUILD)/gen.ddeps.mk
	fi

proper-ddeps:
	$(PRECMD)
	${call log.header, $@ :: proper}
	$(RM) $(DBUILD)/gen.ddeps.mk
	$(RM) $(DBUILD)/gen.ddeps.json

proper-dfiles: proper-ddeps
	$(PRECMD)
	${call log.header, $@ :: proper}
	$(RM) $(DBUILD)/gen.dfiles.mk


.PHONY: proper-ddeps proper-dfiles

env-ddeps:
	$(PRECMD)
	${call log.header, $@ :: env}
	${call log.kvp, DOBJ, $(DOBJ)}
	${call log.kvp, DSRC, $(DSRC)}
	${call log.line}
	${call log.env, DCIRALL, $(DCIRSALL)}
	${call log.line}
	${call log.env, DWAYSALL, $(DWAYSALL)}
	${call log.line}
	${call log.env, DSRCALL, $(DSRCALL)}
	${call log.line}
	${call log.env, DOBJALL, $(DOBJALL)}
	${call log.close}

env: env-ddeps

help-ddeps:
	$(PRECMD)
	${call log.header, $@ :: help}
	${call log.help, "make help-ddeps", "Will display this part"}
	${call log.help, "make ddeps", "Generated all .di via dstep"}
	${call log.help, "make proper-ddeps", "Erase the ddep files"}
	${call log.help, "", "Ex. make proper-ddeps-linux-x86_64"}
	${call log.help, "make env-ddeps", "List all dstep parameters"}
	${call log.close}

help: help-ddeps

# ddeps: $(DBUILD)/gen.ddeps.mk

dfiles: $(DBUILD)/gen.dfiles.mk

.PHONY: env-ddeps help-ddeps
