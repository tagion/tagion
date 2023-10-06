DSRC_OPENSSL := ${call dir.resolve, openssl}
DTMP_OPENSSL := $(DTMP)/openssl

DPREFIX_OPENSSL := $(DTMP_OPENSSL)/install-lib
DEXTRA_OPENSSL := $(DTMP_OPENSSL)/install-extra

CONFIGUREFLAGS_OPENSSL += -static
CONFIGUREFLAGS_OPENSSL += --prefix=$(DPREFIX_OPENSSL)
CONFIGUREFLAGS_OPENSSL += --openssldir=$(DEXTRA_OPENSSL)

include ${call dir.resolve, cross.mk}
LIBOPENSSL+=$(DTMP)/libssl.a
LIBOPENSSL+=$(DTMP)/libcrypto.a

openssl: $(LIBOPENSSL)

.PHONY: openssl

LIBOPENSSL+=$(DTMP)/libcrypto.a
LIBOPENSSL+=$(DTMP)/libssl.a

proper-openssl:
	$(PRECMD)
	${call log.header, $@ :: openssl}
	$(RM) $(LIBOPENSSL)
	$(RMDIR) $(DTMP_OPENSSL)

OPENSSL_HEAD := $(REPOROOT)/.git/modules/src/wrap-openssl/openssl/HEAD 
OPENSSL_GIT_MODULE := $(DSRC_OPENSSL)/.git

$(OPENSSL_GIT_MODULE):
	git submodule update --init --depth=1 $(DSRC_OPENSSL)

$(DTMP_OPENSSL)/.configured: $(DTMP)/.way $(OPENSSL_HEAD) $(OPENSSL_GIT_MODULE)
	$(PRECMD)
	$(CP) $(DSRC_OPENSSL) $(DTMP_OPENSSL)
	$(CD) $(DTMP_OPENSSL)
	./config $(CONFIGUREFLAGS_OPENSSL)
	$(MAKE) build_generated
	touch $@

$(DTMP)/libcrypto.a: $(DTMP_OPENSSL)/.configured
	$(PRECMD)
	$(CD) $(DTMP_OPENSSL); make libcrypto.a
	$(CP) $(DTMP_OPENSSL)/libcrypto.a $(DTMP)/libcrypto.a


$(DTMP)/libssl.a: $(DTMP_OPENSSL)/.configured
	$(PRECMD)
	$(CD) $(DTMP_OPENSSL); make libssl.a
	$(CP) $(DTMP_OPENSSL)/libssl.a $(DTMP)/libssl.a
