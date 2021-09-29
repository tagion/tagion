REPO_OPENSSL ?= https://github.com/openssl/openssl.git
BRANCH_OPENSSL_STABLE := OpenSSL_1_1_1-stable
DIR_OPENSSL_SRC := ${call dir.self, openssl}
DIR_BUILD_OPENSSL := $(DIR_BUILD)/wraps/openssl
DIR_BUILD_OPENSSL_EXTRA := $(DIR_BUILD)/wraps/openssl/extra

WAYS_PERSISTENT += $(DIR_OPENSSL_SRC)/
WAYS_PERSISTENT += $(DIR_BUILD_OPENSSL)/.way 
WAYS_PERSISTENT += $(DIR_BUILD_OPENSSL_EXTRA)/.way

.PHONY: wrap-openssl
wrap-openssl: | ways $(DIR_BUILD_OPENSSL)/lib/libcrypto.a
	${eval WRAPS += opensssl}
	${eval WRAPS_STATIC += $(DIR_BUILD_OPENSSL)/lib/libssl.a}
	${eval WRAPS_STATIC += $(DIR_BUILD_OPENSSL)/lib/libcrypto.a}
	$(PRECMD)export LD_LIBRARY_PATH=$(DIR_BUILD_OPENSSL)/lib/:$(LD_LIBRARY_PATH)
	$(PRECMD)export DYLD_LIBRARY_PATH=$(DIR_BUILD_OPENSSL)/lib/:$(DYLD_LIBRARY_PATH)

$(DIR_BUILD_OPENSSL)/lib/libcrypto.a: $(DIR_OPENSSL_SRC)/config
	$(PRECMD)cd $(DIR_OPENSSL_SRC); ./config --shared --prefix=$(DIR_BUILD_OPENSSL) --openssldir=$(DIR_BUILD_OPENSSL_EXTRA)
	${eval PARALLEL := ${shell [[ "$(MAKEFLAGS)" =~ "jobserver-fds" ]] && echo 1}}
	${if $(PARALLEL), ${eval PARALLEL := -j8}, ${eval PARALLEL :=}}
	$(PRECMD)cd $(DIR_OPENSSL_SRC); make $(PARALLEL)
	$(PRECMD)cd $(DIR_OPENSSL_SRC); make install

$(DIR_OPENSSL_SRC)/config:
	$(PRECMD)git clone --depth 1 -b $(BRANCH_OPENSSL_STABLE) $(REPO_OPENSSL) $(DIR_OPENSSL_SRC) || git -C $(DIR_OPENSSL_SRC) pull