
REPOROOT?=$(shell git root)
REVNO?=$(shell git revno)
HASH?=$(shell git hash)


ifndef $(VERBOSE)
PRECMD?=@
endif

-include $(REPOROOT)/localsetup.mk
DC?=dmd
AR?=ar
LIBNAME:=libtagion.a
include $(REPOROOT)/command.mk

include setup.mk
WORKDIR?=$(REPOROOT)
-include $(WORKDIR)/dfiles.mk

BIN:=$(REPOROOT)/bin/
LDCFLAGS+=$(LINKERFLAG)-L$(BIN)
ARFLAGS:=rcs
BUILD?=$(REPOROOT)/build
SRC?=$(REPOROOT)
OBJS:=$(addprefix $(BUILD)/,$(DFILES:.d=.o))
#DFILES:=$(addprefix $(REPOROOT)/,$(DFILES))

BUILDROOT:=$(sort $(dir $(OBJS)))
TOUCHHOOK:=$(addsuffix /.touch,$(BUILDROOT))


.SECONDARY: $(OBJS) $(TOUCHHOOK)
.PHONY: ddoc
#MAKEDIRS:=$(foreach dir,$(BUILDROOT), mkdir -p $(dir)\;)

#objs:
#	echo $(OBJS)
#	echo $(BUILDROOT)
#	echo $(MAKEDIRS)

DCFLAGS+=-I$(REPOROOT)/
#tangose
TANGOROOT:=$(REPOROOT)/../tango-D2/
#openssl
#secp256k1 (elliptic curve signature library)
SECP256K1ROOT:=$(REPOROOT)/../secp256k1
SECP256K1LIB:=$(SECP256K1ROOT)/.libs/libsecp256k1.a

#DCFLAGS+=-I.
DCFLAGS+=-I$(TANGOROOT)


#LDCFLAGS+=$(LINKERFLAG)-L.
LDCFLAGS+=$(LINKERFLAG)-lssl
LDCFLAGS+=$(LINKERFLAG)-lgmp
LDCFLAGS+=$(LINKERFLAG)-lcrypto
#LDCFLAGS+=$(LINKERFLAG)-L$(TANGOROOT)
#LDCFLAGS+=$(LINKERFLAG)-ltango-$(COMPILER)
SECP256K1_LDCFLAGS+=$(LINKERFLAG)-L$(SECP256K1ROOT)/.libs/
SECP256K1_LDCFLAGS+=$(LINKERFLAG)-Lsecp256k1


# CFLAGS
CFLAGS+=-I$(SECP256K1ROOT)/src/
CFLAGS+=-I$(SECP256K1ROOT)/
#CFLAGS+=-I$(SECP256K1ROOT)/include/
CFLAGS+=-DUSE_NUM_GMP=1
LDFLAGS+=-L$(SECP256K1ROOT)/.libs/
LDFLAGS+=${SECP256K1LIB}
LDFLAGS+=-lgmp
#${SECP256K1LIB}
#CFLAGS+=-DUSE_FIELD_10X2=1

LIBRARY:=$(BIN)/$(LIBNAME)

REVISION:=$(SRC)/tagion/revision.di
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
	@echo "make VERBOSE=1 : Verbose mode"
	@echo


info:
	@echo "DFILES  =$(DFILES)"
	@echo "OBJS    =$(OBJS)"
	@echo "LDCFLAGS=$(LDCFLAGS)"
	@echo "DCFLAGS =$(DCFLAGS)"

$(REVISION):
	@echo "########################################################################################"
	@echo "## Linking $(1)"
	$(PRECMD)echo "module tagion.revision;" > $@
	$(PRECMD)echo 'enum REVNO=$(REVNO);' >> $@
	$(PRECMD)echo 'enum HASH="$(HASH)";' >> $@

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
	$(PRECMD)$(DC) $(DCFLAGS) $(1).d $(OUTPUT)$(BIN)/$(1) $(LDCFLAGS)


endef

$(eval $(foreach main,$(MAIN),$(call LINK,$(main))))

%.a: $(TOUCHHOOK) $(OBJS)
	@echo "########################################################################################"
	@echo "## Library $@"
	@echo "########################################################################################"
	$(PRECMD)$(AR) $(ARFLAGS) $@ $(OBJS)

$(BUILD)/%.o:$(SRC)/%.d
	@echo "########################################################################################"
	@echo "## Compile $<"
#	@echo "########################################################################################"
	$(PRECMD)$(DC) $(DCFLAGS) -c $< $(OUTPUT)$@

%.touch:
	@echo "########################################################################################"
	@echo "## Create dir $(@D)"
	$(PRECMD)mkdir -p $(@D)
	$(PRECMD)touch $@

$(DDOCMODULES): $(DFILES)
	$(PRECMD)echo $(DFILES) | script/ddocmodule.pl > $@

ddoc: $(DDOCMODULES)
	@echo "########################################################################################"
	@echo "## Creating DDOC"
	$(PRECMD)$(DC) $(DDOCFLAGS) $(DDOCFILES) $(DFILES) $(DD)$(DDOCROOT)

%.o: %.c
	gcc  -m64 $(CFLAGS) -c $< -o $@


secp256k1_test: secp256k1_test.c
	echo $@
	gcc $(CFLAGS) -o $@ $< ${LDFLAGS}

CLEANER?=proper

clean: $(CLEANER)

proper: $(CLEANER)
	rm -fR build
	rm -f $(LIBRARY)
ifndef FIX_DFILES
	rm -f dfiles.mk
endif


$(PROGRAMS):
	$(DC) $(DCFLAGS) $(LDCFLAGS) $(OUTPUT) $@
