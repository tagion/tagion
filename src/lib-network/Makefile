REPOROOT?=$(shell git root)
REVNO?=$(shell git revno)
HASH?=$(shell git hash)
PROGRAMS+=test

DC?=ldc2
AR?=ar
LIBNAME:=libbakery.a
include $(REPOROOT)/command.mk

include setup.mk
WORKDIR?=$(REPOROOT)
-include $(WORKDIR)/dfiles.mk

BIN:=$(REPOROOT)/bin/
ARFLAGS:=rcs
BUILD?=$(REPOROOT)/build
SRC?=$(REPOROOT)
OBJS:=$(addprefix $(BUILD)/,$(DFILES:.d=.o))
DFILES:=$(addprefix $(REPOROOT)/,$(DFILES))

BUILDROOT:=$(sort $(dir $(OBJS)))
TOUCHHOOK:=$(addsuffix /.touch,$(BUILDROOT))
#MAKEDIRS:=$(foreach dir,$(BUILDROOT), mkdir -p $(dir)\;)

#objs:
#	echo $(OBJS)
#	echo $(BUILDROOT)
#	echo $(MAKEDIRS)

DCFLAGS+=-unittest
DCFLAGS+=-d-debug
DCFLAGS+=-g
DCFLAGS+=-I$(REPOROOT)/
#tango
TANGOROOT:=$(REPOROOT)/../tango-D2/
#DCFLAGS+=-I.
DCFLAGS+=-I$(TANGOROOT)

#vibe
VIBEROOT:=$(REPOROOT)/../vibe/
DCFLAGS+=-I$(VIBEROOT)


#LDCFLAGS+=$(LINKERFLAG)-L.
LDCFLAGS+=$(LINKERFLAG)-L$(TANGOROOT)
LDCFLAGS+=$(LINKERFLAG)-ltango-$(COMPILER)
#LDCFLAGS+=$(LINKERFLAG)-lbarkey

LIBS+=
LIBS+=$(LIBNAME)

REVISION:=$(SRC)/bakery/revision.di
.PHONY: $(REVISION)

ifndef DFILES
include $(REPOROOT)/source.mk
endif

$(REVISION):
	echo "module bakery.revision;" > $@
	echo 'enum REVNO=$(REVNO);' >> $@
	echo 'enum HASH="$(HASH)";' >> $@

all: $(REVISION) $(MAIN)

info:
	@echo "DFILES =$(DFILES)"
	@echo "OBJS   =$(OBJS)"


#$(eval $(call
define COMPILE
$(1): $(OBJS)
	$(DC) $(LDCFLAGS) $(DCFLAGS) $(DFILES) $(1).d $(OBJS) $(OUTPUT)$(BIN)/$(1)

endef
#compile: $(OBJS)
#	$(DC) $(LDCFLAGS) $(DCFLAGS) $(DFILES) $(MAIN).d $(OBJS) $(OUTPUT)bin/$(MAIN)

$(eval $(foreach main,$(MAIN),$(call COMPILE,$(main))))

$(LIBNAME): $(TOUCHHOOK) $(OBJS)
	$(AR) $(ARFLAGS) $@ $(OBJS)

$(BUILD)/%.o:$(SRC)/%.d
	$(DC) $(DCFLAGS) -c $< $(OUTPUT)$@

%.touch:
	mkdir -p $(@D)
	touch $@

clean:
	rm -fR $(BUILD)
	rm -f $(LIBNAME)
ifndef FIX_DFILES
	rm -f dfiles.mk
endif

$(PROGRAMS):
	$(DC) $(DCFLGAS) $(LDCFLAGS) $(OUTPUT) $@
