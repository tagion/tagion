
# D ddeps macro function
# Param $1 sets the platform path
define DDEPS
${eval
# $1/gen.ddeps.mk: $1/gen.ddeps.json
# 	$$(PRECMD)
# 	$$(DTUB)/ddeps.d --srcdir=DSRC --objdir=DOBJ $$< -o$$@

$$(PLATFORM)_DFILES = $${shell find $$(DSRC) -path "*/lib-*" -a -name "*.d" }

$1/gen.ddeps.json: DFILES+=$$($$(PLATFORM)_DFILES)

clean-$$(PLATFORM):
	$(PRECMD)
	$(RM) $1/gen.ddeps.mk
	$(RM) $1/gen.ddeps.json

clean-ddeps: clean-$$(PLATFORM)

clean: clean-ddeps

ddeps: $1/gen.ddeps.mk

ifdef DOBJ
env-ddeps-$$(PLATFORM):
	$$(PRECMD)
	$${call log.header, $$@ :: env-ddeps}
	$${call log.kvp, DOBJ, $(DOBJ)}
	$${call log.kvp, DSRC, $(DSRC)}
	$${call log.line}
	$${call log.printf, "DCIRALL+= %s\n" $$(DCIRSALL)}
	$${call log.line}
	$${call log.printf, "DWAYSALL+= %s\n" $$(DWAYSALL)}
	$${call log.line}
	$${call log.printf, "DSRCALL+= %s\n" $$(DSRCALL)}
	$${call log.line}
	$${call log.printf, "DOBJALL+= %s\n" $$(DOBJALL)}
	$${call log.close}
else
env-ddeps-$$(PLATFORM):
	$$(PRECMD)
	$${call log.header, $$@ :: env-ddeps}
	$${call log.kvp, DBUILD, $(DBUILD)}
	$${call log.kvp, DSRC, $(DSRC)}
	$${call log.printf, "DFILES+= %s\n" $$($$(PLATFORM)_DFILES)}
	$${call log.close}
endif

env-ddeps: env-ddeps-$$(PLATFORM)

}
endef

%/gen.ddeps.json:
	$(PRECMD)
	ldc2 $(DCFLAGS) ${addprefix -I,$(DINC)} --o- -op --Xf=$@ $(DFILES)

%/gen.ddeps.mk: %/gen.ddeps.json
	$(PRECMD)
	$(DTUB)/ddeps.d  --srcdir=DSRC --objdir=DOBJ $< -o$@

env: env-ddeps
