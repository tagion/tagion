include git.mk

DC?=dmd
AR?=ar
include $(REPOROOT)/command.mk

include setup.mk

-include $(REPOROOT)/dfiles.mk

BIN:=bin/
LDCFLAGS+=$(LINKERFLAG)-L$(BIN)
ARFLAGS:=rcs
BUILD?=$(REPOROOT)/build
#SRC?=$(REPOROOT)

.SECONDARY: $(TOUCHHOOK)
.PHONY: makeway


INCFLAGS=${addprefix -I,${INC}}

LIBRARY:=$(BIN)/$(LIBNAME)
LIBOBJ:=${LIBRARY:.a=.o};

REVISION:=$(REPOROOT)/$(SOURCE)/revision.di
.PHONY: $(REVISION)
.SECONDARY: .touch

ifdef COV
RUNFLAGS+=--DRT-covopt="merge:1 dstpath:reports"
DCFLAGS+=-cov
endif



HELP+=help-main

help: $(HELP)
	@echo "make lib       : Builds $(LIBNAME) library"
	@echo
	@echo "make unittest  : Run the unittests"
	@echo

help-main:
	@echo "Usage "
	@echo
	@echo "make info      : Prints the Link and Compile setting"
	@echo
	@echo "make proper    : Clean all"
	@echo
	@echo "make PRECMD=   : Verbose mode"
	@echo "                 make PRECMD= <tag> # Prints the command while executing"
	@echo

ifndef DFILES
include $(REPOROOT)/source.mk
endif

info:
	@echo "WAYS    =$(WAYS)"
	@echo "DFILES  =$(DFILES)"
#	@echo "OBJS    =$(OBJS)"
	@echo "LDCFLAGS=$(LDCFLAGS)"
	@echo "DCFLAGS =$(DCFLAGS)"
	@echo "INCFLAGS=$(INCFLAGS)"

include $(REPOROOT)/revision.mk

ifndef DFILES
lib: $(REVISION) dfiles.mk
	$(MAKE) lib

unittest: dfiles.mk
	$(MAKE) unittest
else
lib: $(REVISION) $(LIBRARY)

unittest: $(UNITTEST)
	export LD_LIBRARY_PATH=$(LIBBRARY_PATH); $(UNITTEST)

$(UNITTEST): $(LIBS) $(WAYS)
	$(PRECMD)$(DC) $(DCFLAGS) $(INCFLAGS) $(DFILES) $(TESTDCFLAGS) $(OUTPUT)$@
#$(LDCFLAGS)

endif

define LINK
$(1): $(1).d $(LIBRARY)
	@echo "########################################################################################"
	@echo "## Linking $(1)"
#	@echo "########################################################################################"
	$(PRECMD)$(DC) $(DCFLAGS) $(INCFLAGS) $(1).d $(OUTPUT)$(BIN)/$(1) $(LDCFLAGS)
endef

$(eval $(foreach main,$(MAIN),$(call LINK,$(main))))

makeway: ${WAYS}

include $(REPOROOT)/makeway.mk
$(eval $(foreach dir,$(WAYS),$(call MAKEWAY,$(dir))))

%.touch:
	@echo "########################################################################################"
	@echo "## Create dir $(@D)"
	$(PRECMD)mkdir -p $(@D)
	$(PRECMD)touch $@


include $(DDOCBUILDER)

$(LIBRARY): ${DFILES}
	@echo "########################################################################################"
	@echo "## Library $@"
	@echo "########################################################################################"
	${PRECMD}$(DC) ${INCFLAGS} $(DCFLAGS) $(DFILES) -c $(OUTPUT)$(LIBRARY)

CLEANER+=clean

clean:
	rm -f $(LIBRARY)
	rm -f ${OBJS}
	rm -f $(UNITTEST) $(UNITTEST).o

proper: $(CLEANER)
	rm -fR $(WAYS)

%.a:
# Find the root of the %.a repo
# and calls the lib tag
	make -C${call GITROOT,${dir $(@D)}} lib

$(PROGRAMS):
	$(DC) $(DCFLAGS) $(LDCFLAGS) $(OUTPUT) $@
