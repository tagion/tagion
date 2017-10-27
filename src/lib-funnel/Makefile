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
MAIN:=baker

ifndef DFILES
include source.mk
endif

all: compile

run: compile
	./bin/$(MAIN)

compile: $(OBJS)
	$(DC) $(LDCFLAGS) $(DCFLAGS) $(DFILES) $(MAIN).d $(OBJS) $(OUTPUT)bin/$(MAIN)

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
