

LIBSECP256K1_NAME:=libsecp256k1

ifdef SHARED
LIBSECP256K1_FILE:=$(LIBSECP256K1_NAME).$(DLLEXT)
CONFIGUREFLAGS_SECP256K1 += --enable-shared=yes
else
LIBSECP256K1_FILE:=$(LIBSECP256K1_NAME).$(STAEXT)
CONFIGUREFLAGS_SECP256K1 += --enable-shared=on
endif


DSRC_SECP256K1 := ${call dir.resolve, secp256k1}
DTMP_SECP256K1 := $(DTMP)/secp256k1
LIBSECP256K1:=$(DTMP_SECP256K1)/.libs/$(LIBSECP256K1_FILE)
LIBSECP256K1_STATIC:=$(DTMP_SECP256K1)/.libs/$(LIBSECP256K1_NAME).$(STAEXT)
LIBSECP256K1_SHARED:=$(DTMP_SECP256K1)/.libs/$(LIBSECP256K1_NAME).$(DLLEXT)
LIBSECP256K1_OBJ:=$(DTMP_SECP256K1)/src/libsecp256k1_la-secp256k1.o

ifdef USE_SYSTEM_LIBS
LD_SECP256K1+=${shell pkg-config --libs libsecp256k1}
else
LD_SECP256K1+=$(LIBSECP256K1)
endif

CONFIGUREFLAGS_SECP256K1 += --enable-module-ecdh
CONFIGUREFLAGS_SECP256K1 += --enable-experimental
CONFIGUREFLAGS_SECP256K1 += --enable-module-recovery
CONFIGUREFLAGS_SECP256K1 += --enable-module-schnorrsig
CONFIGUREFLAGS_SECP256K1 += --enable-module-musig
# CONFIGUREFLAGS_SECP256K1 += --enable-examples # Android builds don't work work with examples
CONFIGUREFLAGS_SECP256K1 += --prefix=$(DLIB)
CONFIGUREFLAGS_SECP256K1 += CFLAGS=-fPIC
ifdef SECP256K1_DEBUG
CONFIGUREFLAGS_SECP256K1 += CFLAGS=-g
endif

SECP256K1_HEAD := $(REPOROOT)/.git/modules/src/wrap-secp256k1/secp256k1/HEAD 
SECP256K1_GIT_MODULE := $(DSRC_SECP256K1)/.git

include ${call dir.resolve, cross.mk}

ifdef USE_SYSTEM_LIBS
secp256k1: # NOTHING TO BUILD
.PHONY: secp256k1
else
secp256k1: $(LIBSECP256K1) $(DSRC_SECP256K1)/include/secp256k1_hash.h
endif

$(DSRC_SECP256K1)/src/hash.h: $(SECP256K1_GIT_MODULE)
$(DSRC_SECP256K1)/include/secp256k1_hash.h: $(DSRC_SECP256K1)/src/hash.h
	$(PRECMD)
	ln -s $< $@


proper-secp256k1:
	$(PRECMD)
	${call log.header, $@ :: proper}
	$(RM) $(LIBSECP256K1)
	$(RMDIR) $(DTMP_SECP256K1)

$(SECP256K1_GIT_MODULE):
	git submodule update --init --depth=1 $(DSRC_SECP256K1)

$(SECP256K1_HEAD): $(SECP256K1_GIT_MODULE)
build_secp256k1: $(DTMP)/.way $(DLIB)/.way $(SECP256K1_HEAD)
	$(PRECMD)
	${call log.kvp, $@}
	$(CP) $(DSRC_SECP256K1) $(DTMP_SECP256K1)
	$(CD) $(DTMP_SECP256K1)
	./autogen.sh
	./configure $(CONFIGUREFLAGS_SECP256K1)
	$(MAKE) clean
	$(MAKE)

$(LIBSECP256K1_STATIC): build_secp256k1
$(LIBSECP256K1_SHARED): build_secp256k1

env-secp256k1:
	$(PRECMD)
	${call log.header, $@ :: env}
	${call log.env, CONFIGUREFLAGS_SECP256K1, $(CONFIGUREFLAGS_SECP256K1)}
	${call log.kvp, LIBSECP256K1, $(LIBSECP256K1)}
	${call log.kvp, DTMP_SECP256K1, $(DTMP_SECP256K1)}
	${call log.kvp, DSRC_SECP256K1, $(DSRC_SECP256K1)}
	${call log.close}

env: env-secp256k1

help-secp256k1:
	$(PRECMD)
	${call log.header, $@ :: help}
	${call log.help, "make secp256k1", "Creates the secp256k1 library"}
	${call log.help, "make help-secp256k1", "Will display this part"}
	${call log.help, "make proper-secp256k1", "Erase all secp256k1 objects and libraries"}
	${call log.help, "make env-secp256k1", "List all secp256k1 build environment"}
	${call log.close}

help: help-secp256k1
