
DSTEP_ATTRIBUTES+= --global-attribute=nothrow
DSTEP_ATTRIBUTES+= --global-attribute=@nogc


#
# $1 D Package
# $2 Include directory for the .h c-header files
# $3 Target directory for the .di files
# $4 .d files which depends on the the .di files
#
define DSTEP_DO
${eval
HFILES_$1= $${wildcard $2/*.h}
DIFILES_notdir_$1 = $${notdir $$(HFILES_$1)}
DIFILES_$1 = $${addprefix $3/,$${DIFILES_notdir_$1:.h=.di}}
DESTROOT_$1 = $3
HPATH_$1 = $2

$$(DESTROOT_$1)/%.di: $$(HPATH_$1)/%.h | $$(DESTROOT_$1)
	$$(PRECMD)${call log.kvp, dstep, $$(@F)}
	$$(DSTEP) $$(DSTEP_ATTRIBUTES) $$(DSTEPFLAGS) --package $1 $$< -o $$@

MAKE_SHOW_ENV += env-libcrypto-$1

$$(DESTROOT_$1):
	$$(PRECMD)mkdir -p $$@

$4: | dstep-$1

dstep-$1: $$(DIFILES_$1)

dstep: dstep-$1

env-dstep-$1:
	$$(PRECMD)
	$$(call log.header, env :: $1 :: dstep)
	$${call log.kvp, HFILES, $$(HFILES_$1)}
	$${call log.kvp, DESTROOT, $$(DESTROOT_$1)}
	$${call log.kvp, DFILES, $4}
	$${call log.kvp, DIFILES, $$(DIFILES_$1)}
	$${call log.kvp, DSTEP_ATTRIBUTES, $$(DSTEP_ATTRIBUTES)}
	$${call log.kvp, DSTEPFLAGS, $$(DSTEPFLAGS)}
	$$(call log.close)

env-dstep: env-dstep-$1

clean: clean-dstep-$1

clean-dstep-$1:
	$$(RM) $$(DIFILES_$1)

clean-dstep: clean-dstep-$1

}
endef

help-dstep:
	$(PRECMD)
	${call log.header, help :: dstep}
	${call log.help, "make dstep", "Generated all .di via dstep"}
	${call log.help, "make dstep-<module>", "Generate the <module>"}
	${call log.help, "", "Ex make dstep-tagion.crypto.secp256k1.c"}
	${call log.help, "make clean-dstep", "Clean all generated .di files"}
	${call log.help, "make env-dstep", "List all dstep parameters"}
	${call log.close}

help: help-dstep
