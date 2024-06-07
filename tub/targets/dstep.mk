
DSTEP_ATTRIBUTES+= --global-attribute=nothrow
DSTEP_ATTRIBUTES+= --global-attribute=@nogc


define DI2DLINK
echo $${$1:.di=.d}
endef

#
# This macro produce a .di file from .h
#
# $1 D Package
# $2 Include directory for the .h c-header files
# $3 Target directory for the .di files
# $4 .d files which depends on the the .di files
# $5 Custom dstep flags
# $6 HFILES
#
# Environment for the .di target
# DSTEPFLAGS sets the args for dstep command
# DSTEP_POSTCORRECT Sets a list of post-correct scripts
#
define DSTEP_DO
${eval
ifdef 6
HFILES.$1 = $6
else
HFILES.$1= $${wildcard $2/*.h}
endif
DIFILES_notdir.$1 = $${notdir $$(HFILES.$1)}
DIFILES.$1 = $${addprefix $3/,$${DIFILES_notdir.$1:.h=.di}}
DESTROOT.$1 = $3
HPATH.$1 = $2
DSTEPFLAGS.$1 = $5

DIFILES+=$$(DIFILES.$1)

DIFILES_DEPS+=$4

#ifdef ($(DSTEP))

$$(DESTROOT.$1)/%.di: $$(HPATH.$1)/%.h | $$(DESTROOT.$1)
	$$(PRECMD)${call log.kvp, dstep, $$(@F)}
	$$(DSTEP) $$(DSTEP_ATTRIBUTES) $$(DSTEPFLAGS.$1) $$(DSTEPFLAGS) --package $1 $$< -o $$@
	$${foreach post_correct, $$(DSTEP_POSTCORRECT), $$(post_correct) $$@}
	if [ -n "$$(DSTEP_DLINK)" ]; then
	cd $$(@D)
	$$(LN) $$(@F) $$(basename $$(@F)).d 
	fi

#endif # End dstep tool is available

$$(DESTROOT.$1):
	$$(PRECMD)mkdir -p $$@

$4: $$(DIFILES.$1)

dstep-$1: $$(DIFILES.$1)

dstep: dstep-$1


env-dstep-$1:
	$$(PRECMD)
	$${call log.header, $$@ :: env}
	$${call log.kvp, PACKAGE,$1}
	$${call log.kvp, SRCDIR,$2}
	$${call log.kvp, DESTDIR,$3}
	$${call log.env, HFILES.$1, $$(HFILES.$1)}
	$${call log.kvp, HPATH.$1, $$(HPATH.$1)}
	$${call log.kvp, DESTROOT.$1, $$(DESTROOT.$1)}
	$${call log.env, DFILES, $4}
	$${call log.env, DIFILES.$1, $$(DIFILES.$1)}
	$${call log.env, DSTEP_ATTRIBUTES, $$(DSTEP_ATTRIBUTES)}
	$${call log.env, DSTEPFLAGS.$1, $$(DSTEPFLAGS.$1)}
	$${call log.close}

env-dstep: env-dstep-$1

env: env-dstep

# clean: clean-dstep-$1

clean-dstep-$1:
	$$(PRECMD)
	$${call log.header, $$@ :: $1}
	$$(RM) $$(DIFILES.$1)

clean-dstep: clean-dstep-$1

}
endef

help-dstep:
	$(PRECMD)
	${call log.header, $@ :: help}
	${call log.help, "make help-dstep", "Will display this part"}
	${call log.help, "make dstep", "Generated all .di via dstep"}
	${call log.help, "make dstep-<module>", "Generate the <module>"}
	${call log.help, "", "Ex. make dstep-tagion.crypto.secp256k1.c"}
	${call log.help, "make clean-dstep", "Clean all generated .di files"}
	${call log.help, "make env-dstep", "List all dstep parameters"}
	${call log.close}


env-dstep:
	$(PRECMD)
	$(call log.header, $@ :: env)
	${call log.env, DIFILES, $(DIFILES)}
	${call log.close}

help: help-dstep
