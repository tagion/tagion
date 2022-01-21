

ifdef SHARED
LIBSECP256K1_NAME:=libsecp256k1.$(DLLEXT)
CONFIGUREFLAGS_SECP256K1 += --enable-shared=yes
else
LIBSECP256K1_NAME:=libsecp256k1.$(LIBEXT)
CONFIGUREFLAGS_SECP256K1 += --enable-shared=on
endif

LIBSECP256K1:=$(DTMP)/$(LIBSECP256K1_NAME)

DEPS += wrap-openssl
DSRC_SECP256K1 := ${call dir.resolve, src}
DTMP_SECP256K1 := $(DTMP)/secp256k1

CONFIGUREFLAGS_SECP256K1 += --enable-module-ecdh
CONFIGUREFLAGS_SECP256K1 += --enable-experimental
CONFIGUREFLAGS_SECP256K1 += --enable-module-recovery
CONFIGUREFLAGS_SECP256K1 += --enable-module-schnorrsig
CONFIGUREFLAGS_SECP256K1 += CRYPTO_LIBS=$(DTMP)/ CRYPTO_CFLAGS=$(DSRC_OPENSSL)/include/
CONFIGUREFLAGS_SECP256K1 += --prefix=$(DLIB)
include ${call dir.resolve, cross.mk}

secp256k1: $(LIBSECP256K1)
	@

clean-secp256k1:
	$(RM) $(LIBSECP256K1)
	$(RMDIR) $(DTMP_SECP256K1)

proper: clean-secp256k1


$(LIBSECP256K1): $(DTMP)/.way $(DLIB)/.way
	$(PRECMD)
	${call log.kvp, $@}
	$(CP) $(DSRC_SECP256K1) $(DTMP_SECP256K1)
	$(CD) $(DTMP_SECP256K1)
	./autogen.sh
	./configure $(CONFIGUREFLAGS_SECP256K1)
	$(MAKE) clean
	$(MAKE) $(SUBMAKE_PARALLEL)
#	ln -s .libs/lib* $(@D)

env-secp256k1:
	$(PRECMD)
	$(call log.header, env :: secp256k1)
	$(call log.kvp, $(CONFIGUREFLAGS_SECP256K1))
	$(call log.close)

env: env-secp256k1

help-secp256k1:
	$(PRECMD)
	${call log.header, $@ :: env}
	${call log.help, "make help-secp256k1", "Will display this part"}
	${call log.help, "make clean-secp256k1", "Clean all secp256k1 objects and libraries"}
	${call log.help, "make env-secp256k1", "List all secp256k1 build environment"}
	${call log.help, "make prober", "Also executes make clean-secp256k1"}
	${call log.close}

help: help-secp256k1
