
# D ddeps macro function
# Param $1 sets the platform path
define DDEPS
${eval
$1/gen.ddeps.mk: $1/gen.ddeps.json
	$$(PRECMD)
	$$(DTUB)/ddeps.d $$< -o$$@

$$(PLATFORM)_DFILES = $${shell find $$(DSRC) -path "*/lib-*" -a -name "*.d" }

$1/gen.ddeps.json: DFILES+=$$($$(PLATFORM)_DFILES)

CLEANER+=clean-$$(PLATFORM)

clean-$$(PLATFORM):
	$(PRECMD)
	$(RM) $1/gen.ddeps.mk
	$(RM) $1/gen.ddeps.json

MAKE_ENV += env-ddeps-$$(PLATFORM)

env-ddeps-$$(PLATFORM):
	$$(PRECMD)
	$${call log.header, env :: ddeps-$$(PLATFORM)}
	$${call log.kvp, DFILES, $$($$(PLATFORM)_DFILES)}
	$${call log.close}
}
endef

%/gen.ddeps.json:
	$(PRECMD)
	ldc2 $(DCFLAGS) ${addprefix -I,$(DINC)} --o- -op --Xf=$@ $(DFILES)

%/gen.ddeps.mk: %/gen.ddeps.json
	$(PRECMD)
	$(DTUB)/ddeps.d $< -o$@
