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

proper: proper-openssl

$(DTMP_OPENSSL)/.configured: $(DTMP)/.way
	$(PRECMD)$(CP) $(DSRC_OPENSSL) $(DTMP_OPENSSL)
	$(PRECMD)cd $(DTMP_OPENSSL); ./config $(CONFIGUREFLAGS_OPENSSL)
	$(PRECMD)cd $(DTMP_OPENSSL); make build_generated
	$(PRECMD)touch $@

$(DTMP)/libcrypto.a: $(DTMP_OPENSSL)/.configured
	$(PRECMD)cd $(DTMP_OPENSSL); make libcrypto.a
	$(PRECMD)cp $(DTMP_OPENSSL)/libcrypto.a $(DTMP)/libcrypto.a


$(DTMP)/libssl.a: $(DTMP_OPENSSL)/.configured
	$(PRECMD)cd $(DTMP_OPENSSL); make libssl.a
	$(PRECMD)cp $(DTMP_OPENSSL)/libssl.a $(DTMP)/libssl.a
