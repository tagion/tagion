# Clone and make according to variables
# Will add support for crossc compilation triplet and choose dest folder automatically.

NAME_OPENSSL := openssl
REPO_OPENSSL ?= https://github.com/openssl/openssl.git
PATH_SRC_OPENSSL := ${dir.self}/$(NAME_OPENSSL)
BRANCH_OPENSSL_STABLE := OpenSSL_0_9_7-stable

check/openssl:
	${call log.line, System check for OPENSSL is not implemented yet}

wrap/openssl: ways ${PATH_SRC_OPENSSL}/build/openssl/lib/libcrypto.a
	${eval WRAPS += opensssl}
	${eval LDCFLAGS += -L-L$(PATH_SRC_OPENSSL)/build/openssl/lib/}
	${eval export LD_LIBRARY_PATH=$(PATH_SRC_OPENSSL)/build/openssl/lib/:$(LD_LIBRARY_PATH)}

${PATH_SRC_OPENSSL}/build/openssl/lib/libcrypto.a: $(PATH_SRC_OPENSSL)/config
	$(PRECMD)mkdir -p ${PATH_SRC_OPENSSL}/build
	$(PRECMD)cd $(PATH_SRC_OPENSSL); ./config --shared --prefix=${PATH_SRC_OPENSSL}/build/openssl --openssldir=${PATH_SRC_OPENSSL}/build/openssl-extras
	$(PRECMD)cd $(PATH_SRC_OPENSSL); make -j8
	$(PRECMD)cd $(PATH_SRC_OPENSSL); make install

$(PATH_SRC_OPENSSL)/config:
	$(PRECMD)git -C $(PATH_SRC_OPENSSL) pull || git clone --depth 1 -b $(BRANCH_OPENSSL_STABLE) $(REPO_OPENSSL) $(PATH_SRC_OPENSSL)