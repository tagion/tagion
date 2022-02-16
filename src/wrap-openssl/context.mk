DSRC_OPENSSL := ${call dir.resolve, src}
DTMP_OPENSSL := $(DTMP)/openssl

DPREFIX_OPENSSL := $(DTMP_OPENSSL)/install-lib
DEXTRA_OPENSSL := $(DTMP_OPENSSL)/install-extra

CONFIGUREFLAGS_OPENSSL += -static 
CONFIGUREFLAGS_OPENSSL += --prefix=$(DPREFIX_OPENSSL)
CONFIGUREFLAGS_OPENSSL += --openssldir=$(DEXTRA_OPENSSL)

include ${call dir.resolve, cross.mk}

openssl: $(DTMP)/libssl.a $(DTMP)/libcrypto.a
	@

TOCLEAN_OPENSSL += $(DTMP)/libssl.a
TOCLEAN_OPENSSL += $(DTMP)/libcrypto.a
TOCLEAN_OPENSSL += $(DTMP_OPENSSL)

clean-openssl: TOCLEAN := $(TOCLEAN_OPENSSL)
clean-openssl: clean
	@

$(DTMP_OPENSSL)/.configured: $(DTMP)/.way 
	$(PRECMD)$(CP) $(DSRC_OPENSSL) $(DTMP_OPENSSL)
	$(PRECMD)cd $(DTMP_OPENSSL); ./config $(CONFIGUREFLAGS_OPENSSL)
	$(PRECMD)cd $(DTMP_OPENSSL); make build_generated $(SUBMAKE_PARALLEL)
	$(PRECMD)touch $@

$(DTMP)/libcrypto.a: $(DTMP_OPENSSL)/.configured
	$(PRECMD)cd $(DTMP_OPENSSL); make libcrypto.a $(SUBMAKE_PARALLEL)
	$(PRECMD)cp $(DTMP_OPENSSL)/libcrypto.a $(DTMP)/libcrypto.a


$(DTMP)/libssl.a: $(DTMP_OPENSSL)/.configured
	$(PRECMD)cd $(DTMP_OPENSSL); make libssl.a $(SUBMAKE_PARALLEL)
	$(PRECMD)cp $(DTMP_OPENSSL)/libssl.a $(DTMP)/libssl.a

# NOTE: Might need to export, but not sure. Will try without since we static link:
# $(PRECMD)export LD_LIBRARY_PATH=$(DPREFIX_OPENSSL)/:$(LD_LIBRARY_PATH)
# $(PRECMD)export DYLD_LIBRARY_PATH=$(DPREFIX_OPENSSL)/:$(DYLD_LIBRARY_PATH)