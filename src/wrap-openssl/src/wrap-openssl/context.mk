REPO_OPENSSL ?= git@github.com:tagion/fork-openssl.git
VERSION_OPENSSL := 2e5cdbc18a1a26bfc817070a52689886fa0669c2 # OpenSSL_1_1_1-stable as of 09.09.2021

DIR_OPENSSL := $(DIR_BUILD_WRAPS)/openssl

DIR_OPENSSL_PREFIX := $(DIR_OPENSSL)/lib
DIR_OPENSSL_EXTRA := $(DIR_OPENSSL)/extra
DIR_OPENSSL_SRC := $(DIR_OPENSSL)/src

wrap-openssl: $(DIR_OPENSSL_PREFIX)/libcrypto.a $(DIR_OPENSSL_PREFIX)/libssl.a
	@

clean-wrap-openssl:
	${call unit.dep.wrap-openssl}
	${call rm.dir, $(DIR_OPENSSL)}

$(DIR_OPENSSL_PREFIX)/%.a: $(DIR_OPENSSL)/.way
	$(PRECMD)git clone --depth 1 $(REPO_OPENSSL) $(DIR_OPENSSL_SRC) 2> /dev/null || true
	$(PRECMD)git -C $(DIR_OPENSSL_SRC) fetch --depth 1 $(DIR_OPENSSL_SRC) $(VERSION_OPENSSL) &> /dev/null || true
	$(PRECMD)cd $(DIR_OPENSSL_SRC); ./config --shared --prefix=$(DIR_OPENSSL) --openssldir=$(DIR_OPENSSL_EXTRA)
	$(PRECMD)cd $(DIR_OPENSSL_SRC); make $(MAKE_PARALLEL)
	$(PRECMD)cd $(DIR_OPENSSL_SRC); make install

# NOTE: Might need to export, but not sure. Will try without since we static link:
# $(PRECMD)export LD_LIBRARY_PATH=$(DIR_OPENSSL_PREFIX)/:$(LD_LIBRARY_PATH)
# $(PRECMD)export DYLD_LIBRARY_PATH=$(DIR_OPENSSL_PREFIX)/:$(DYLD_LIBRARY_PATH)