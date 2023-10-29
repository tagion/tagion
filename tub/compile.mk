
ifdef COV
DFLAGS+=$(DCOV)
DRTFLAGS+=$(COVOPT)
COVWAY=$(DLOGCOV)/.way
endif
DFLAGS+=$(DIP1000)

ifneq ($(COMPILER),gdc)
DFLAGS+=$(DPREVIEW)=inclusiveincontracts
endif

ifdef VERBOSE_COMPILER_ERRORS
DFLAGS+=$(VERRORS)
endif

DFLAGS+=-J$(DTUB)/logos/

#
# Change extend of the LIB
#
LIBEXT=${if $(SHARED),$(DLLEXT),$(STAEXT)}

#
# D compiler
#/
$(DOBJ)/%.$(OBJEXT): $(DSRC)/%.d
	$(PRECMD)
	${call log.kvp, compile, $(MODE)}
	$(DC) $(DFLAGS) ${addprefix -I,$(DINC)} $< $(DCOMPILE_ONLY) $(OUTPUT)$@

#
# Compile and link or split link
#
ifdef SPLIT_LINKER
$(DOBJ)/lib%.$(OBJEXT): $(DOBJ)/.way
	$(PRECMD)
	${call log.kvp, compile$(MODE)}
	echo ${DFILES}
	$(DC) $(DFLAGS) ${addprefix -I,$(DINC)} ${sort $(DFILES)} $(DCOMPILE_ONLY)  $(OUTPUT)$@

$(DLIB)/lib%.$(DLLEXT): $(DOBJ)/lib%.$(OBJEXT)
	$(PRECMD)
	${call log.kvp, split-link$(MODE)}
	echo ${filter %.$(OBJEXT),$?}
	$(LD) ${LDFLAGS} ${filter %.$(OBJEXT),$?} $(LIBS) $(OBJS) -o$@
else
$(DLIB)/%.$(LIBEXT):
	$(PRECMD)
	${call log.kvp, link$(MODE), $(DMODULE)}
	$(DC) $(DFLAGS) ${addprefix -I,$(DINC)} ${sort $(DFILES)} ${LDFLAGS} $(LIBS) $(OBJS) $(DLIBTYPE) $(OUTPUT)$@
endif

#
# proto targets for binaries
#

$(DBIN)/%:
	$(PRECMD)
	${call log.kvp, bin$(MOD), $*}
	echo ${filter %.d,$^} > /tmp/$*_dfiles_q.mk
	echo $(DFILES) > /tmp/$*_dfiles.mk
	echo $(DFLAGS) $(DFLAGS_DEBUG) > /tmp/$*_dflags.mk
	$(DC) $(DFLAGS_DEBUG) $(DFLAGS) ${addprefix -L,$(LDFLAGS)} ${addprefix -I,$(DINC)} ${sort $(DFILES) ${filter %.d,$^}} $(LIBS) $(OBJS) $(OUTPUT)$@


# Object Clear"
clean-obj:
	$(PRECMD)
	${call log.header, $@ :: obj}
	$(RM) $(DOBJALL)
	$(RM) $(DCIRALL)

clean: clean-obj

env-build:
	$(PRECMD)
	${call log.header, $@ :: env}
	${call log.env, DINC, $(DINC)}

env: env-build

help-cov:
	$(PRECMD)
	${call log.header, $@ :: help}
	${call log.help, "make <target> COV=1", "Enable <target> with code covarage"}
	${call log.close}

help: help-cov

env-cov:
	$(PRECMD)
	${call log.header, $@ :: env}
	${call log.kvp, COVOPT, $(COVOPT)}
	${call log.close}

env: env-cov

.PHONY: env-cov help-cov
