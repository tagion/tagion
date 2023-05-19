

LIBSECP256K1_NAME:=libsecp256k1

# It seems the build creates both the shared and static library regardless of this options being enabled or disabled
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
LIBSECP256K1_OBJ:=$(DTMP_SECP256K1)/src/libsecp256k1_la-secp256k1.o

CONFIGUREFLAGS_SECP256K1 += --enable-module-ecdh
CONFIGUREFLAGS_SECP256K1 += --enable-experimental
CONFIGUREFLAGS_SECP256K1 += --enable-module-recovery
CONFIGUREFLAGS_SECP256K1 += --enable-module-schnorrsig
CONFIGUREFLAGS_SECP256K1 += CRYPTO_LIBS=$(DTMP)/ CRYPTO_CFLAGS=$(DSRC_OPENSSL)/include/
CONFIGUREFLAGS_SECP256K1 += --prefix=$(DLIB)
CONFIGUREFLAGS_SECP256K1 += CFLAGS=-fPIC
include ${call dir.resolve, cross.mk}

secp256k1: $(LIBSECP256K1) $(DSRC_SECP256K1)/include/secp256k1_hash.h

$(DSRC_SECP256K1)/include/secp256k1_hash.h: $(DSRC_SECP256K1)/src/hash.h
	$(PRECMD)
	ln -s $< $@


proper-secp256k1:
	$(PRECMD)
	${call log.header, $@ :: proper}
	$(RM) $(LIBSECP256K1)
	$(RMDIR) $(DTMP_SECP256K1)

$(LIBSECP256K1): $(DTMP)/.way $(DLIB)/.way
	$(PRECMD)
	${call log.kvp, $@}
	$(CP) $(DSRC_SECP256K1) $(DTMP_SECP256K1)
	$(CD) $(DTMP_SECP256K1)
	./autogen.sh
	./configure $(CONFIGUREFLAGS_SECP256K1)
	$(MAKE) clean
	$(MAKE)

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
