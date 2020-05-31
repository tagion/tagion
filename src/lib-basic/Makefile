include git.mk
REVNO?=$(GIT_REVNO)
HASH?=$(GIT_HASH)


ifndef $(VERBOSE)
PRECMD?=@
endif

DC?=dmd
AR?=ar
include $(REPOROOT)/command.mk

include setup.mk
WORKDIR?=$(REPOROOT)
-include $(WORKDIR)/dfiles.mk

BIN:=$(REPOROOT)/bin/
LDCFLAGS+=$(LINKERFLAG)-L$(BIN)
ARFLAGS:=rcs
BUILD?=$(REPOROOT)/build
#SRC?=$(REPOROOT)
#OBJS=${DFILES:.d=.o}

.SECONDARY: $(TOUCHHOOK)
.PHONY: ddoc makeway

INC+=$(REPOROOT)
INC+=$(P2PLIB)
INC+=$(SECP256K1ROOT)/src/
INC+=$(SECP256K1ROOT)/

INCFLAGS=${addprefix -I,${INC}}



#External libaries
#openssl
#secp256k1 (elliptic curve signature library)
SECP256K1ROOT:=$(REPOROOT)/../secp256k1
SECP256K1LIB:=$(SECP256K1ROOT)/.libs/libsecp256k1.a

P2PLIB:=$(REPOROOT)/../libp2pDWrapper/
#DCFLAGS+=-I$(P2PLIB)

LDCFLAGS+=$(LINKERFLAG)-lssl
LDCFLAGS+=$(LINKERFLAG)-lgmp
LDCFLAGS+=$(LINKERFLAG)-lcrypto

LDCFLAGS+=-L$(P2PLIB)bin/libp2p.a
LDCFLAGS+=-L$(P2PLIB)bin/libp2p_go.a
SECP256K1_LDCFLAGS+=$(LINKERFLAG)-L$(SECP256K1ROOT)/.libs/
SECP256K1_LDCFLAGS+=$(LINKERFLAG)-Lsecp256k1


# CFLAGS
CFLAGS+=-I$(SECP256K1ROOT)/src/
CFLAGS+=-I$(SECP256K1ROOT)/
CFLAGS+=-DUSE_NUM_GMP=1
LDFLAGS+=-L$(SECP256K1ROOT)/.libs/
LDFLAGS+=${SECP256K1LIB}
LDFLAGS+=-lgmp
#${SECP256K1LIB}
#CFLAGS+=-DUSE_FIELD_10X2=1

LIBRARY:=$(BIN)/$(LIBNAME)
LIBOBJ:=${LIBRARY:.a=.o};

REVISION:=$(REPOROOT)/$(SOURCE)/revision.di
.PHONY: $(REVISION)
.SECONDARY: .touch

ifdef COV
RUNFLAGS+=--DRT-covopt="merge:1 dstpath:reports"
DCFLAGS+=-cov
endif


ifndef DFILES
include $(REPOROOT)/source.mk
endif

HELPER:=help-main

help-master: help-main
	@echo "make lib       : Builds $(LIBNAME) library"
	@echo

help-main:
	@echo "Usage "
	@echo
	@echo "make info      : Prints the Link and Compile setting"
	@echo
	@echo "make proper    : Clean all"
	@echo
	@echo "make ddoc      : Creates source documentation"
	@echo
	@echo "make PRECMD=   : Verbose mode"
	@echo "                 make PRECMD= <tag> # Prints the command while executing"
	@echo

info:
	@echo "DFILES  =$(DFILES)"
#	@echo "OBJS    =$(OBJS)"
	@echo "LDCFLAGS=$(LDCFLAGS)"
	@echo "DCFLAGS =$(DCFLAGS)"
	@echo "INCFLAGS=$(INCFLAGS)"

include $(REPOROOT)/revsion.mk

ifndef DFILES
lib: dfiles.mk
	$(MAKE) lib
else
lib: $(REVISION) $(LIBRARY)
endif

define LINK
$(1): $(1).d $(LIBRARY)
	@echo "########################################################################################"
	@echo "## Linking $(1)"
#	@echo "########################################################################################"
	echo prog=$(1)
	echo LDCFLAGS=$(LDCFLAGS)
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

$(DDOCMODULES): $(DFILES)
	$(PRECMD)echo $(DFILES) | scripts/ddocmodule.pl > $@

ddoc: $(DDOCMODULES)
	@echo "########################################################################################"
	@echo "## Creating DDOC"
	${PRECMD}ln -fs ../candydoc ddoc
	$(PRECMD)$(DC) ${INCFLAGS} $(DDOCFLAGS) $(DDOCFILES) $(DFILES) $(DD)$(DDOCROOT)

%.o: %.c
	@echo "########################################################################################"
	@echo "## compile "$(notdir $<)
	$(PRECMD)gcc  -m64 $(CFLAGS) -c $< -o $@

secp256k1_test: secp256k1_test.c
	echo $@
	gcc $(CFLAGS) -o $@ $< ${LDFLAGS}

$(LIBRARY): ${DFILES}
	@echo "########################################################################################"
	@echo "## Library $@"
	@echo "########################################################################################"
	${PRECMD}$(DC) ${INCFLAGS} $(DCFLAGS) $(DFILES) -c $(OUTPUT)$(LIBRARY)

CLEANER+=clean

clean:
	rm -f $(LIBRARY)
	rm -f ${OBJS}

proper: $(CLEANER)
	rm -fR ${WAYS}

$(PROGRAMS):
	$(DC) $(DCFLAGS) $(LDCFLAGS) $(OUTPUT) $@

root:
	@echo ${REPOROOT}
