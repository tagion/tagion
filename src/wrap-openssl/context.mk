REPO_OPENSSL ?= git@github.com:tagion/fork-openssl.git
VERSION_OPENSSL := 2e5cdbc18a1a26bfc817070a52689886fa0669c2 # OpenSSL_1_1_1-stable as of 09.09.2021

DSRC_OPENSSL := ${call dir.resolve, src}
DTMP_OPENSSL := $(DTMP)/openssl

DPREFIX_OPENSSL := $(DTMP_OPENSSL)/install-lib
DEXTRA_OPENSSL := $(DTMP_OPENSSL)/install-extra

CONFIGUREFLAGS_OPENSSL += -static 
CONFIGUREFLAGS_OPENSSL += --prefix=$(DPREFIX_OPENSSL)
CONFIGUREFLAGS_OPENSSL += --openssldir=$(DEXTRA_OPENSSL)

openssl.preconfigure: $(DSRC_OPENSSL)/.src
openssl: $(DTMP)/libssl.a $(DTMP)/libcrypto.a
	@

TOCLEAN_OPENSSL += $(DTMP)/libssl.a
TOCLEAN_OPENSSL += $(DTMP)/libcrypto.a
TOCLEAN_OPENSSL += $(DSRC_OPENSSL)
TOCLEAN_OPENSSL += $(DTMP_OPENSSL)

TOCLEAN += $(TOCLEAN_OPENSSL)

clean-openssl: TOCLEAN := $(TOCLEAN_OPENSSL)
clean-openssl: clean
	@

$(DTMP_OPENSSL)/.configured: $(DTMP)/.way $(DSRC_OPENSSL)/.src
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

$(DSRC_OPENSSL)/.src:
	${call log.line, Cloning $(REPO_OPENSSL)...}
	$(PRECMD)git clone --depth 1 $(REPO_OPENSSL) $(DSRC_OPENSSL)
	$(PRECMD)git -C $(DSRC_OPENSSL) fetch --depth 1 $(DSRC_OPENSSL) $(VERSION_OPENSSL)
	$(PRECMD)touch $@

# NOTE: Might need to export, but not sure. Will try without since we static link:
# $(PRECMD)export LD_LIBRARY_PATH=$(DPREFIX_OPENSSL)/:$(LD_LIBRARY_PATH)
# $(PRECMD)export DYLD_LIBRARY_PATH=$(DPREFIX_OPENSSL)/:$(DYLD_LIBRARY_PATH)