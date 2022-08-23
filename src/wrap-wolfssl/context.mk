#openssl
#LIBOPENSSL
DSRC_WOLFSSL := ${call dir.resolve, wolfssl}
DTMP_WOLFSSL := $(DTMP)/wolfssl

CONFIGUREFLAGS_WOLFSSL := --enable-static

.PHONY: wolfssl

LIBWOLFSSL := $(DTMP_WOLFSSL)/src/.libs/libwolfssl.a

proper-wolfssl:
	$(PRECMD)
	${call log.header, $@ :: wolfssl}
	$(RMDIR) $(DTMP_WOLFSSL)

proper: proper-wolfssl

$(LIBWOLFSSL): $(DTMP)/.way
	$(PRECMD)
	${call log.kvp, $@}
	$(CP) $(DSRC_WOLFSSL) $(DTMP_WOLFSSL)
	$(PRECMD)cd $(DTMP_WOLFSSL); sh autogen.sh
	$(PRECMD)cd $(DTMP_WOLFSSL); ./configure $(CONFIGUREFLAGS_WOLFSSL)
	$(PRECMD)cd $(DTMP_WOLFSSL); make

wolfssl: $(LIBWOLFSSL)

