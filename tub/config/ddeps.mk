# D ddeps macro function
# Param $1 sets the platform path
define DDEPS
${eval

$$(PLATFORM)_DFILES = $2

$1/gen.dfiles.mk: DFILES=$$($$(PLATFORM)_DFILES)

$1/gen.ddeps.json: $(PREBUILD)


$1/gen.ddeps.json: $1/gen.dfiles.mk

$1/gen.ddeps.json: $1/.way

$1/gen.ddeps.json: DFILES=$$($$(PLATFORM)_DFILES)

proper-ddeps-$$(PLATFORM):
	$(PRECMD)
	$${call log.header, $$@ :: proper}
	$(RM) $1/gen.ddeps.mk
	$(RM) $1/gen.ddeps.json

.PHONY: proper-ddeps-$$(PLATFORM)

proper-ddeps: proper-ddeps-$$(PLATFORM)

ddeps: $1/gen.ddeps.mk

help-ddeps-$$(PLATFORM):
	$(PRECMD)
	${call log.header, $$@ :: $$(PLATFORM)}
	${call log.help, "make $$@", "Will display this part"}
	${call log.close}

help-ddeps: help-ddeps-$$(PLATFORM)

.PHONY: help-ddeps-$$(PLATFORM)

ifdef DOBJ
env-ddeps-$$(PLATFORM):
	$$(PRECMD)
	$${call log.header, $$@ :: env}
	$${call log.kvp, DOBJ, $(DOBJ)}
	$${call log.kvp, DSRC, $(DSRC)}
	$${call log.line}
	$${call log.env, DCIRALL, $$(DCIRSALL)}
	$${call log.line}
	$${call log.env, DWAYSALL, $$(DWAYSALL)}
	$${call log.line}
	$${call log.env, DSRCALL, $$(DSRCALL)}
	$${call log.line}
	$${call log.env, DOBJALL, $$(DOBJALL)}
	$${call log.close}
else
env-ddeps-$$(PLATFORM):
	$$(PRECMD)
	$${call log.header, $$@ :: env}
	$${call log.kvp, DBUILD, $(DBUILD)}
	$${call log.kvp, DSRC, $(DSRC)}
	$${call log.printf, "DFILES+= %s\n" $$($$(PLATFORM)_DFILES)}
	$${call log.close}
endif

env-ddeps: env-ddeps-$$(PLATFORM)

.PHONY: env-ddeps-$$(PLATFORM)

}
endef


%/gen.ddeps.json:
	$(PRECMD)
	${call log.kvp, $(@F), $(PLATFORM)}
	$(DC) $(DFLAGS) $(UNITTEST_FLAGS) ${addprefix -I,$(DINC)} --o- $(NO_OBJ)  $(DJSON)=$@ $(DFILES)

%/gen.ddeps.mk: %/gen.ddeps.json
	$(PRECMD)
	${call log.kvp, $(@F), $(PLATFORM)}
	$(DTUB)/ddeps.d  --srcdir=DSRC --objdir=DOBJ $< -o$@

env: env-ddeps

help-ddeps:
	$(PRECMD)
	${call log.header, $@ :: help}
	${call log.help, "make help-ddeps", "Will display this part"}
	${call log.help, "make ddeps", "Generated all .di via dstep"}
	${call log.help, "make dstep-<platform>",
	"Generate the dep file for the  <platform>"}
	${call log.help, "", "Ex. make dstep-linux-x86_64"}
	${call log.help, "make proper-ddeps", "Erase the ddep files"}
	${call log.help, "make proper-ddeps-<platform>"}
	${call log.help, "", "Ex. make proper-ddeps-linux-x86_64"}
	${call log.help, "make env-ddeps", "List all dstep parameters"}
	${call log.close}

help: help-ddeps

prebuild2: $(DBUILD)/gen.dfiles.mk

dfiles: $(DBUILD)/gen.dfiles.mk

.PHONY: env-ddeps help-ddeps dfiles

ifdef ${strip DFILES}
$(DBUILD)/gen.dfiles.mk:
	$(PRECMD)
	echo ifdef load.$@ > $@
	echo load.$@=1 >> $@
	printf "%s += %s\n" ${addprefix DFILES , $(DFILES)} >> $@
	echo endif >>$@
endif



# echo ifdef load.$@ > $@

# echo load.$@=1 >> $@

# echo endif >>$@

gen.test.mk:
	echo "Hello" > $@
