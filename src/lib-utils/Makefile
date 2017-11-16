REPOROOT?=$(shell git root)
PROGRAMS+=test

DC?=ldc2
AR?=ar
LIBNAME:=libbakery.a
include $(REPOROOT)/command.mk

-include dfiles.mk


ARFLAGS:=rcs
BUILD:=build
OBJS:=$(addprefix $(BUILD)/,$(DFILES:.d=.o))

BUILDROOT:=$(sort $(dir $(OBJS)))
TOUCHHOOK:=$(addsuffix /.touch,$(BUILDROOT))
#MAKEDIRS:=$(foreach dir,$(BUILDROOT), mkdir -p $(dir)\;)

#objs:
#	echo $(OBJS)
#	echo $(BUILDROOT)
#	echo $(MAKEDIRS)

DCFLAGS+=-unittest
DCFLAGS+=-g
TANGOROOT:=$(REPOROOT)/../Tango-D2/
#DCFLAGS+=-I.
DCFLAGS+=-I$(TANGOROOT)
#LDCFLAGS+=$(LINKERFLAG)-L.
LDCFLAGS+=$(LINKERFLAG)-L$(TANGOROOT)
LDCFLAGS+=$(LINKERFLAG)-ltango-$(COMPILER)
#LDCFLAGS+=$(LINKERFLAG)-lbarkey

LIBS+=
LIBS+=$(LIBNAME)
#MAIN:=baker
MAIN+=test_script
MAIN+=test_bigint


ifndef DFILES
include source.mk
endif

all: $(MAIN)

run: $(MAIN)
	./bin/$(MAIN)

info:
	@echo "DFILES =$(DFILES)"
	@echo "OBJS   =$(OBJS)"


#$(eval $(call
define COMPILE
$(1): $(OBJS)
	$(DC) $(LDCFLAGS) $(DCFLAGS) $(DFILES) $(1).d $(OBJS) $(OUTPUT)bin/$(1)

endef
#compile: $(OBJS)
#	$(DC) $(LDCFLAGS) $(DCFLAGS) $(DFILES) $(MAIN).d $(OBJS) $(OUTPUT)bin/$(MAIN)

$(eval $(foreach main,$(MAIN),$(call COMPILE,$(main))))

$(LIBNAME): $(TOUCHHOOK) $(OBJS)
	$(AR) $(ARFLAGS) $@ $(OBJS)

$(BUILD)/%.o:%.d
	$(DC) $(DCFLAGS) -c $< $(OUTPUT) $@

%.touch:
	mkdir -p $(@D)
	touch $@

clean:
	rm -fR $(BUILD)
	rm -f $(LIBNAME)
	rm -f dfiles.mk

$(PROGRAMS):
	$(DC) $(DCFLGAS) $(LDCFLAGS) $(OUTPUT) $@
