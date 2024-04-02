
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

ifdef SPLIT_LINKER
# dmd already sets this when it invokes the linker
LDFLAGS+=-lphobos2
# Assume that phobos is located in lib directory 1 up from compiler
LDFLAGS+=-L$(dir $(shell which $(DC)))/../lib
endif

#
# Change extend of the LIB
#
LIBEXT=${if $(SHARED),$(DLLEXT),$(STAEXT)}

#
# D compiler
#
$(DOBJ)/%.$(OBJEXT): $(DSRC)/%.d
	$(PRECMD)
	$(call log.header, $*.$(OBJEXT) :: compile)
	${call log.kvp, compile, $(MODE)}
	$(DC) $(DFLAGS) ${addprefix -I,$(DINC)} $<  $(OUTPUT)$@

#
# Compile and link or split link
#
ifdef SPLIT_LINKER
$(DOBJ)/lib%.$(OBJEXT): $(DOBJ)/.way
	$(PRECMD)
	${call log.kvp, compile$(MODE)}
	echo ${DFILES}
	$(DC) $(DFLAGS) ${addprefix -I,$(DINC)} ${sort $(DFILES)} $(DCOMPILE_ONLY)  $(OUTPUT)$@

$(DLIB)/lib%.$(LIBEXT): $(DOBJ)/lib%.$(OBJEXT)
	$(PRECMD)
	${call log.kvp, split-link$(MODE)}
	echo ${filter %.$(OBJEXT),$?}
	$(LD) ${LDFLAGS} ${filter %.$(OBJEXT),$?} $(LIBS) $(OBJS) -o$@
else
$(DLIB)/%.$(LIBEXT):
	$(PRECMD)
	${call log.kvp, link$(MODE), $(DMODULE)}
	$(DC) $(DINCIMPORT) $(DFLAGS) ${addprefix -I,$(DINC)} ${sort $(DFILES)} ${addprefix -L,$(LDFLAGS)} $(LIBS) $(OBJS) $(DLIBTYPE) $(OUTPUT)$@
endif

#
# proto targets for binaries
#
ifdef SPLIT_LINKER
$(DOBJ)/bin%.$(OBJEXT): $(DOBJ)/.way
	$(PRECMD)
	${call log.kvp, compile$(MODE)}
	echo $(DFILES) > /tmp/$*_dfiles.mk
	$(DC) $(DCOMPILE_ONLY) $(DFLAGS_DEBUG) $(DFLAGS) ${addprefix -I,$(DINC)} ${sort $(DFILES) ${filter %.d,$^}} $(OUTPUT)$@

$(DBIN)/%: $(DOBJ)/bin%.$(OBJEXT)
	$(PRECMD)
	${call log.kvp, split-link$(MODE)}
	echo ${filter %.$(OBJEXT),$?}
	$(LD) ${LDFLAGS} ${filter %.$(OBJEXT),$?} $(LIBS) $(OBJS) -o$@
else
ifndef DBIN_EXCLUDE
$(DBIN)/%:
	$(PRECMD)
	$(call log.header, $* :: bin)
	$(call log.env, DFILES, $(DFILES))
	$(DC) $(DINCIMPORT) $(DFLAGS_DEBUG) $(DFLAGS) ${addprefix -L,$(LDFLAGS)} ${addprefix -I,$(DINC)} $(DFILES) $(LIBS) $(OBJS) $(OUTPUT)$@
endif
endif

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
	${call log.help, "make <target> COV=1", "Enable <target> with code coverage"}
	${call log.close}

help: help-cov

env-cov:
	$(PRECMD)
	${call log.header, $@ :: env}
	${call log.kvp, COVOPT, $(COVOPT)}
	${call log.close}

env: env-cov

.PHONY: env-cov help-cov
