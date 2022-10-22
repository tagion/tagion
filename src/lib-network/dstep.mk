#
# Network DSTEP headers
#
ifdef WOLFSSL
WOLFSSL_POSTCORRECT=${call dir.resolve_1, lib-network/scripts}

WOLFSSL_PACKAGE := tagion.network.wolfssl.c
WOLFSSL_DIROOT := ${call dir.resolve_1, tagion/network/wolfssl/c}

WOLFSSL_DFILES := ${shell find ${call dir.resolve, tagion/network} -name "*.d"}

WOLFSSL_DSTEP_FLAGS+=-I$(DSRC_WOLFSSL)
WOLFSSL_DSTEP_FLAGS++= --global-import=$(WOLFSSL_PACKAGE).wolfssl

#WOLFSSL_HFILES+=$(DSRC_WOLFSSL)/wolfssl/sniffer.h
WOLFSSL_HFILES+=$(DSRC_WOLFSSL)/wolfssl/crl.h
WOLFSSL_HFILES += $(DSRC_WOLFSSL)/wolfssl/ocsp.h
#WOLFSSL_HFILES += $(DSRC_WOLFSSL)/wolfssl/wolfio.h
WOLFSSL_HFILES += $(DSRC_WOLFSSL)/wolfssl/certs_test.h
WOLFSSL_HFILES += $(DSRC_WOLFSSL)/wolfssl/ssl.h
WOLFSSL_HFILES += $(DSRC_WOLFSSL)/wolfssl/quic.h
WOLFSSL_HFILES += $(DSRC_WOLFSSL)/wolfssl/version.h
#WOLFSSL_HFILES += $(DSRC_WOLFSSL)/wolfssl/test.h
WOLFSSL_HFILES += $(DSRC_WOLFSSL)/wolfssl/internal.h
WOLFSSL_HFILES += $(DSRC_WOLFSSL)/wolfssl/sniffer_error.h
WOLFSSL_HFILES += $(DSRC_WOLFSSL)/wolfssl/callbacks.h
WOLFSSL_HFILES += $(DSRC_WOLFSSL)/wolfssl/error-ssl.h



${call DSTEP_DO,$(WOLFSSL_PACKAGE),$(DSRC_WOLFSSL)/wolfssl,$(WOLFSSL_DIROOT),$(WOLFSSL_DFILES),$(WOLFSSL_DSTEP_FLAGS), $(WOLFSSL_HFILES)}

WOLFCRYPT_PACKAGE := tagion.network.wolfssl.c.wolfcrypt
WOLFCRYPT_DIROOT := ${call dir.resolve_1, wolfssl/c/wolfcrypt}

WOLFCRYPT_DFILES := ${shell find ${call dir.resolve, tagion/network} -name "*.d"}

WOLFCRYPT_HFILES+=$(DSRC_WOLFSSL)/wolfssl/wolfcrypt/settings.h
WOLFCRYPT_HFILES+=$(DSRC_WOLFSSL)/wolfssl/wolfcrypt/asn_public.h
WOLFCRYPT_HFILES+=$(DSRC_WOLFSSL)/wolfssl/wolfcrypt/types.h

${call DSTEP_DO,$(WOLFCRYPT_PACKAGE),$(DSRC_WOLFSSL),$(WOLFCRYPT_DIROOT),$(WOLFCRYPT_DFILES),$(WOLFCRYPT_DSTEP_FLAGS), $(WOLFCRYPT_HFILES)}

$(WOLFSSL_DIROOT)/ssl.di: DSTEPFLAGS+=--global-import $(WOLFSSL_PACKAGE).wolfcrypt.settings

$(WOLFSSL_DIROOT)/ssl.di: DSTEPFLAGS+=--global-import $(WOLFSSL_PACKAGE).wolfssl_version
$(WOLFSSL_DIROOT)/ssl.di: DSTEPFLAGS+=--global-import $(WOLFSSL_PACKAGE).wolfcrypt.asn_public
$(WOLFSSL_DIROOT)/ssl.di: DSTEPFLAGS+=--global-import $(WOLFSSL_PACKAGE).wolfcrypt.types

$(WOLFSSL_DIROOT)/wolfcrypt/types.di: DSTEP_POSTCORRECT+=$(WOLFSSL_POSTCORRECT)/correct_types.pl
$(WOLFSSL_DIROOT)/ssl.di: DSTEP_POSTCORRECT+=$(WOLFSSL_POSTCORRECT)/correct_ssl.pl

$(WOLFSSL_DIROOT)/wolfcrypt/asn_public.di: DSTEPFLAGS+=--global-import $(WOLFSSL_PACKAGE).wolfcrypt.types

find_test=${shell find $(REPOROOT) -type d -path "*wolfcrypt"}

test44:
	echo $(WOLFSSL_DFILES)
	echo $(WOLFCRYPT_DFILES)
	echo $(WOLFSSL_POSTCORRECT)
	echo $(WOLFCRYPT_DIROOT)
	echo $(find_test)
	echo $(REPOROOT)
	echo ${call dir.resolve_1, wolfssl/c/wolfcrypt}








#include <wolfssl/wolfcrypt/settings.h>
#include <wolfssl/version.h>
#include <wolfssl/wolfcrypt/asn_public.h>
#include <wolfssl/wolfcrypt/error-crypt.h>
#include <wolfssl/wolfcrypt/logging.h>
#include <wolfssl/wolfcrypt/memory.h>
#include <wolfssl/wolfcrypt/types.h>

#/* For the types */
#include <wolfssl/openssl/compat_types.h>

#ifdef HAVE_WOLF_EVENT
    #include <wolfssl/wolfcrypt/wolfevent.h>
#endif

 #ifdef WOLF_CRYPTO_CB
    #include <wolfssl/wolfcrypt/cryptocb.h>
#endif


endif

