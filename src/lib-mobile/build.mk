CROSS_LD:=$(CROSS_TOOLCHAIN)/ld

LIBMOBILE:=libmobile.so
LIBMOBILE_SRC_DIR:=$(DSRC)/lib-mobile
LIBMOBILE_SRC:=$(LIBMOBILE_SRC_DIR)/tagion/mobile/package.d
LIBMOBILE:=$(DBIN)/$(LIBMOBILE)
LIBMOBILE_DEPS:=$(LIBMOBILE_SRC_DIR)/gen.configure.lib.mk

$(DBIN)/$(PROGRAM): $(DTMP)/libsecp256k1.so

DINC=${shell find $(DSRC) -maxdepth 1 -type d -path "*src/lib-*"}
DCFALGS_INC=${addprefix -I,$(DINC)}

DFILES=${shell find $(DSRC) -name "*.d" -o -name "*.di"}

#DCFLAGS+=$(DVERSION)=TINY_AES
#endef


libmobileinfo:
	$(PRECMD)
	echo $(DCFLAGS)
	echo $(DC)
	echo $(DINC)
	echo $(DROOT)
	echo $(DSRC)
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

#/home/carsten/Android/android-ndk-r23b/toolchains/llvm/prebuilt/linux-x86_64/bin/ld
# test77:
# 	echo $(CROSS_TOOLCHAIN)
# 	echo $(MTRIPLE)

$(LIBMOBILE): $(LIBMOBILE_SRC)
	$(PRECMD)
	$(DC) -c $(DCFLAGS) $(DCCROSS_FLAGS) $(DCFALGS_INC) ${filter $(DFILES),${abspath $?}} ${filter %.a, $(abspath $?)}  $(LDCFLAGS) -od=/tmp/obj
	$(CROSS_LD) /tmp/obj/*.o --shared -o $@

	#$(CROSS_LD) /tmp/obj/*.o --shared -o $@

endif


$(LIBMOBILE_DEPS): $(LIBMOBILE_SRC)
	$(PRECMD)
	ldc2 $(DCFLAGS) $(DCFALGS_INC) --o- --makedeps=$@ -of=$(LIBMOBILE) $<

clean-libmobile:
	rm -f $(LIBMOBILE_DEPS)
