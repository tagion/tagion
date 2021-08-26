REPO_OPENSSL ?= https://github.com/openssl/openssl.git
BRANCH_OPENSSL_STABLE := OpenSSL_1_1_1-stable
DIR_OPENSSL_SRC := ${call dir.self, openssl}
DIR_INSTALL_OPENSSL := ${call dir.self, local}/$(ARCH)/openssl
DIR_INSTALL_OPENSSL_EXTRA := ${call dir.self, local}/$(ARCH)/openssl-extra
DIR_BUILD_OPENSSL := $(DIR_BUILD)/wraps/openssl

WAYS += $(DIR_INSTALL_OPENSSL)/.way 
WAYS += $(DIR_BUILD_OPENSSL)/.way

wrap/openssl: | ways ${DIR_BUILD_OPENSSL}/libcrypto.a $(DIR_BUILD_OPENSSL)/libssl.a
	${eval WRAPS += opensssl}
	${eval LDCFLAGS += -L-L$(DIR_OPENSSL_SRC)/build/openssl/lib/}
	${eval export LD_LIBRARY_PATH=$(DIR_INSTALL_OPENSSL)/lib/:$(LD_LIBRARY_PATH)}

$(DIR_BUILD_OPENSSL)/libcrypto.a: $(DIR_INSTALL_OPENSSL)/lib/libcrypto.a
	$(PRECMD)cp $(DIR_INSTALL_OPENSSL)/lib/libcrypto.a $(DIR_BUILD_OPENSSL)

$(DIR_BUILD_OPENSSL)/libssl.a: $(DIR_INSTALL_OPENSSL)/lib/libcrypto.a
	$(PRECMD)cp $(DIR_INSTALL_OPENSSL)/lib/libssl.a $(DIR_BUILD_OPENSSL)

$(DIR_INSTALL_OPENSSL)/lib/libcrypto.a: $(DIR_OPENSSL_SRC)/config
	$(PRECMD)cd $(DIR_OPENSSL_SRC); ./config --shared --prefix=$(DIR_INSTALL_OPENSSL) --openssldir=$(DIR_INSTALL_OPENSSL_EXTRA)
	${eval PARALLEL := ${shell [[ "$(MAKEFLAGS)" =~ "jobserver-fds" ]] && echo 1}}
	${if $(PARALLEL), PARALLEL :=, ${eval PARALLEL := -j8}}
	$(PRECMD)cd $(DIR_OPENSSL_SRC); make $(PARALLEL)
	$(PRECMD)cd $(DIR_OPENSSL_SRC); make install

$(DIR_OPENSSL_SRC)/config:
	$(PRECMD)git -C $(DIR_OPENSSL_SRC) pull || git clone --depth 1 -b $(BRANCH_OPENSSL_STABLE) $(REPO_OPENSSL) $(DIR_OPENSSL_SRC)