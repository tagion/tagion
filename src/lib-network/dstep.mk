#
# Network DSTEP headers
#
ifdef WOLFSSL
NETWORK_PACKAGE := tagion.network.wolfssl.c
NETWORK_DIROOT := ${call dir.resolve, tagion/network/wolfssl/c}

NETWORK_DFILES := ${shell find ${call dir.resolve, tagion/network} -name "*.d"}

NETWORK_DSTEP_FLAGS+=-I$(DSRC_WOLFSSL)
NETWORK_DSTEP_FLAGS++= --global-import=$(NETWORK_PACKAGE).wolfssl

#NETWORK_HFILES+=$(DSRC_WOLFSSL)/wolfssl/sniffer.h
NETWORK_HFILES+=$(DSRC_WOLFSSL)/wolfssl/crl.h
NETWORK_HFILES += $(DSRC_WOLFSSL)/wolfssl/ocsp.h
#NETWORK_HFILES += $(DSRC_WOLFSSL)/wolfssl/wolfio.h
NETWORK_HFILES += $(DSRC_WOLFSSL)/wolfssl/certs_test.h
NETWORK_HFILES += $(DSRC_WOLFSSL)/wolfssl/ssl.h
NETWORK_HFILES += $(DSRC_WOLFSSL)/wolfssl/quic.h
NETWORK_HFILES += $(DSRC_WOLFSSL)/wolfssl/version.h
#NETWORK_HFILES += $(DSRC_WOLFSSL)/wolfssl/test.h
NETWORK_HFILES += $(DSRC_WOLFSSL)/wolfssl/internal.h
NETWORK_HFILES += $(DSRC_WOLFSSL)/wolfssl/sniffer_error.h
NETWORK_HFILES += $(DSRC_WOLFSSL)/wolfssl/callbacks.h
NETWORK_HFILES += $(DSRC_WOLFSSL)/wolfssl/error-ssl.h

${call DSTEP_DO,$(NETWORK_PACKAGE),$(DSRC_WOLFSSL)/wolfssl,$(NETWORK_DIROOT),$(NETWORK_DFILES),$(NETWORK_DSTEP_FLAGS), $(NETWORK_HFILES)}
endif
