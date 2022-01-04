
PROGRAM:=tagionwave

TAGIONWAVE_SRC_DIR:=$(DSRC)/bin-wave
TAGIONWAVE_SRC:=$(TAGIONWAVE_SRC_DIR)/tagion/wave.d
TAGIONWAVE:=$(DBIN)/tagionwave
TAGIONWAVE_DEPS:=$(TAGIONWAVE_SRC_DIR)/gen.configure.bin.mk

$(DBIN)/$(PROGRAM): $(DTMP)/libsecp256k1.a
$(DBIN)/$(PROGRAM): $(DTMP)/libssl.a
$(DBIN)/$(PROGRAM): $(DTMP)/libcrypto.a
$(DBIN)/$(PROGRAM): $(DTMP)/libp2pgowrapper.a

#define DINCFLAGS
DINC=${shell find $(DSRC) -maxdepth 1 -type d -path "*src/lib-*"}
DCFALGS_INC=${addprefix -I,$(DINC)}

DFILES=${shell find $(DSRC) -name "*.d" -o -name "*.di"}

DCFLAGS+=$(DVERSION)=TINY_AES
#endef


twaveinfo:
	$(PRECMD)
	echo $(DCFLAGS)
	echo $(DC)
	echo $(DINC)
	echo $(DROOT)
	echo $(DSRC)
	echo DBUILD=$(DBUILD)
	echo DBIN=$(DBIN)
	echo TAGIONWAVE=$(TAGIONWAVE)
	echo TAGIONWAVE_SRC=$(TAGIONWAVE_SRC)
	echo DCFALGS_INC=$(DCFALGS_INC)


twave: $(TAGIONWAVE)

ifeq (,${wildcard $(TAGIONWAVE_DEPS)})
DC:=ldc2
$(TAGIONWAVE): $(TAGIONWAVE_DEPS)
	@echo do not exists
	$(MAKE) $@
else
include $(TAGIONWAVE_DEPS)

$(TAGIONWAVE): $(TAGIONWAVE_SRC)
#	@echo ${filter %.a, $(abspath $?)}
#	@echo ${filter $(DFILES),${abspath $?}}
#	@echo $(DC)
	$(DC) $(DCFLAGS) $(DCFALGS_INC) ${filter $(DFILES),${abspath $?}} ${filter %.a, $(abspath $?)} $(OUTPUT)=$@
endif


$(TAGIONWAVE_DEPS): $(TAGIONWAVE_SRC)
	$(PRECMD)
	ldc2 $(DCFLAGS) $(DCFALGS_INC) --o- --makedeps=$@ -of=$(TAGIONWAVE) $<

tclean:
	rm -f $(TAGIONWAVE_DEPS)
