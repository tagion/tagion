#openssl
#LIBOPENSSL
DSRC_WOLFSSL := ${call dir.resolve, wolfssl}
DTMP_WOLFSSL := $(DTMP)/wolfssl

#CONFIGUREFLAGS_WOLFSSL := --enable-opensslextra --enable-static --enable-all --enable-memory --enable-debug --enable-bigcache
CONFIGUREFLAGS_WOLFSSL := --enable-opensslextra --enable-static --enable-all --enable-memory --enable-debug --enable-bigcache
# CONFIGUREFLAGS_WOLFSSL += PTHREAD_CFLAGS="-D_FORTIFY_SOURCE=2 -O2"



ifdef DEBUG 
CONFIGUREFLAGS_WOLFSSL += --enable-debug
endif

.PHONY: wolfssl

LIBWOLFSSL := $(DTMP_WOLFSSL)/src/.libs/libwolfssl.a

proper-wolfssl:
	$(PRECMD)
	${call log.header, $@ :: wolfssl}
	$(RMDIR) $(DTMP_WOLFSSL)

proper: proper-wolfssl

wolfssl: $(LIBWOLFSSL)

$(LIBWOLFSSL): $(DTMP)/.way
	$(PRECMD)
	${call log.kvp, $@}
	$(CP) $(DSRC_WOLFSSL) $(DTMP_WOLFSSL)
	$(PRECMD)cd $(DTMP_WOLFSSL); sh autogen.sh
	$(PRECMD)cd $(DTMP_WOLFSSL); ./configure $(CONFIGUREFLAGS_WOLFSSL)
	$(PRECMD)cd $(DTMP_WOLFSSL); make CFLAGS=-O2

env-wolfssl:
	$(PRECMD)
	${call log.header, $@ :: env}
	${call log.env, CONFIGUREFLAGS_WOLFSSL, $(CONFIGUREFLAGS_WOLFSSL)}
	${call log.kvp, LIBWOLFSSL, $(LIBWOLFSSL)}
	${call log.kvp, DTMP_WOLFSSL, $(DTMP_WOLFSSL)}
	${call log.kvp, DSRC_WOLFSSL, $(DSRC_WOLFSSL)}
	${call log.close}

.PHONY: env-wolfssl

env: env-wolfssl

help-wolfssl:
	$(PRECMD)
	${call log.header, $@ :: help}
	${call log.help, "make help-wolfssl", "Will display this part"}
	${call log.help, "make wolfssl", "Creates the wolfssl library"}
	${call log.help, "make proper-wolfssl", "Remove the wolfssl build"}
	${call log.help, "make env-wolfssl", "Display environment for the wolfbuild"}
	${call log.close}

.PHONY: help-wolfssl

help: help-wolfssl

