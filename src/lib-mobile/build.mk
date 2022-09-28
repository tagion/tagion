CROSS_LD:=$(CROSS_TOOLCHAIN)/ld

LDCRUNTIME:=$(HOME)/work/ldc-runtime/ldc-build-runtime.tmp/lib/
LIBDRUNTIME+=libdruntime-ldc.a
LIBDRUNTIME+=libphobos2-ldc.a
LIBDRUNTIME_STATIC=${addprefix $(LDCRUNTIME),$(LIBDRUNTIME)}

LDC2ALL+=${shell find /home/carsten/work/ldc-runtime/ldc-build-runtime.tmp/CMakeFiles/ -name "*.o" -not -path "*debug*"}

LDC2ALL+=${shell find /home/carsten/work/ldc-runtime/ldc-build-runtime.tmp/objects/ -name "*.o"}


LIBMOBILE:=libmobile.so
LIBMOBILE_SRC_DIR:=$(DSRC)/lib-mobile
LIBMOBILE_SRC:=$(LIBMOBILE_SRC_DIR)/tagion/mobile/package.d
LIBMOBILE:=$(DBIN)/$(LIBMOBILE)
LIBMOBILE_DEPS:=$(LIBMOBILE_SRC_DIR)/gen.configure.lib.mk

LIBMOBILE_TRIAL_DEPS:=$(LIBMOBILE_SRC_DIR)/gen.configure.trial.mk

$(DBIN)/$(PROGRAM): $(DTMP)/libsecp256k1.so

DINC=${shell find $(DSRC) -maxdepth 1 -type d -path "*src/lib-*"}
DINC+=${shell find $(BDD) -maxdepth 1 -type d -path "*bdd" }#

DCFALGS_INC=${addprefix -I,$(DINC)}

#DFILES=${shell find $(DSRC) -name "*.d" -o -name "*.di" }
DFILES=${shell find $(DSRC) -path "*/lib-*" -a -name "*.d" }
BDDFILES=${shell find $(BDD) -path "*" -a -name "*.d" }

libmobileinfo:
	$(PRECMD)
	echo $(DCFLAGS)
	echo $(DC)
	echo $(DINC)
	echo $(DROOT)
	echo $(DSRC)
	echo $(BDD)
	echo DBUILD=$(DBUILD)
	echo DBIN=$(DBIN)
	echo LIBMOBILE=$(LIBMOBILE)
	echo LIBMOBILE_SRC=$(LIBMOBILE_SRC)
	echo DCFALGS_INC=$(DCFALGS_INC)
	echo LDCFLAGS=$(LDCFLAGS)


shared-libmobile: $(LIBMOBILE)

ifeq (,${wildcard $(LIBMOBILE_DEPS)})
DC:=ldc2
$(LIBMOBILE): $(LIBMOBILE_DEPS)
	@echo do not exists
	$(MAKE) $@
else
include $(LIBMOBILE_DEPS)

#$(LIBMOBILE): LDCFLAGS+=$(LINKERFLAG)-L$(DTMP)/libsecp256k1.so


$(LIBMOBILE): LDCFLAGS+=$(LINKERFLAG)-lsecp256k1

#$(LIBMOBILE): LDCFLAGS+=-c

#$(LIBMOBILE): LDCFLAGS+=--shared

#$(LIBMOBILE): LDCFLAGS+=-fpic

$(LIBMOBILE): $(DTMP)/libsecp256k1.so


$(LIBMOBILE): $(LIBMOBILE_SRC)
	$(PRECMD)
	$(DC) -c $(DCFLAGS) $(DCCROSS_FLAGS) $(DCFALGS_INC) ${filter $(DFILES),${abspath $?}} ${filter %.a, $(abspath $?)}  $(LDCFLAGS) -od=/tmp/obj
	$(CROSS_LD) /tmp/obj/*.o $(LDC2ALL) \
        --shared -o $@

#-L-Wl,--whole-archive \
#        $(LIBDRUNTIME_STATIC) \
#        -L-Wl,--no-whole-archive \
#        --shared -o $@

endif


$(LIBMOBILE_DEPS): $(LIBMOBILE_SRC)
	$(PRECMD)
	ldc2 $(DCFLAGS) $(DCFALGS_INC) --o- --makedeps=$@ -of=$(LIBMOBILE) $<

ifeq (,${wildcard $(LIBMOBILE_TRIAL_DEPS)})
#ifeq (,${wildcard $(LIBMOBILE_TRIAL_DEPS).knot})
${LIBMOBILE_TRIAL_DEPS:.mk=.knot.mk}: $(LIBMOBILE_SRC)
	$(PRECMD)
	ldc2 $(DCFLAGS) $(DCFALGS_INC) --o- --makedeps=$@ -of=$@.knot $<
	$(MAKE) $*

%.mk: %.knot.mk

else
include $(LIBMOBILE_TRIAL_DEPS)

endif

DDEPS:=deps.mk

ifeq (,${wildcard $(DDEPS)})
$(DDEPS):
	$(PRECMD)
	ldc2 $(DCFLAGS) $(DCFALGS_INC) --o- -op --makedeps=$@ $(DFILES)
	ldc2 $(DCFLAGS) $(DCFALGS_INC) --o- -op --Xf=ddeps.json $(DFILES)
	ldc2 $(DCFLAGS) $(DCFALGS_INC) --o- -op --deps=ddeps.deps $(DFILES)
else
$(DDEPS):
	echo ok
endif

trail: $(DDEPS)


#${LIBMOBILE_TRIAL_DEPS:.mk=.knot.mk}

xxx:
	@echo $(DFILES)

clean-trail:
	rm -f $(LIBMOBILE_TRIAL_DEPS)

clean-libmobile:
	rm -f $(LIBMOBILE_DEPS)


yyyy:
	@echo $(LDC2ALL)
