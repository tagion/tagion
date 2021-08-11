# Clone and make according to variables
# Will add support for crossc compilation triplet and choose dest folder automatically.

NAME_OPENSSL := openssl
REPO_OPENSSL ?= https://github.com/openssl/openssl.git
PATH_SRC_OPENSSL := ${dir.self}/$(NAME_OPENSSL)
BRANCH_OPENSSL_STABLE := OpenSSL_0_9_7-stable

check/openssl:
	${call log.line, System check for OPENSSL is not implemented yet}

wrap/openssl: ways ${DIR_BUILD}/wraps/libcrypto.a

${DIR_BUILD}/wraps/libcrypto.a: $(PATH_SRC_OPENSSL)/config
	@echo $(DIR_BUILD)
	$(PRECMD)cd $(PATH_SRC_OPENSSL); ./config --prefix=${DIR_BUILD}/wraps/openssl --openssldir=${PATH_SRC_OPENSSL}/ossl
	$(PRECMD)cd $(PATH_SRC_OPENSSL); make
	$(PRECMD)cd $(PATH_SRC_OPENSSL); make install

$(PATH_SRC_OPENSSL)/config:
	$(PRECMD)git -C $(PATH_SRC_OPENSSL) pull || git clone --depth 1 -b $(BRANCH_OPENSSL_STABLE) $(REPO_OPENSSL) $(PATH_SRC_OPENSSL)