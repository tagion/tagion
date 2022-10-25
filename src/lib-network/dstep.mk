#
# Network DSTEP headers
#
ifdef WOLFSSL
WOLFSSL_POSTCORRECT=${call dir.resolve_1, lib-network/scripts}

WOLFSSL_PACKAGE := tagion.network.wolfssl.c
WOLFSSL_DIROOT := ${call dir.resolve_1, tagion/network/wolfssl/c}

WOLFSSL_DFILES := ${shell find ${call dir.resolve, tagion/network} -name "*.d"}

WOLFSSL_DSTEP_FLAGS+=-I$(DSRC_WOLFSSL)
WOLFSSL_DSTEP_FLAGS+= --global-import=tagion.network.wolfssl.wolfssl_config
WOLFSSL_DSTEP_FLAGS+= -DUSE_FAST_MATH=1
WOLFSSL_DSTEP_FLAGS+= -DWC_CTC_NAME_SIZE=128
#WOLFSSL_DSTEP_FLAGS+= -DCTC_NAME_SIZE=128
WOLFSSL_DSTEP_FLAGS+= -DWC_NO_HARDEN=1
#WOLFSSL_DSTEP_FLAGS+= -DWOLFSSL_PTHREADS=1
WOLFSSL_DSTEP_FLAGS+= -DWOLFSSL_PUB_PEM_TO_DER=1
#WOLFSSL_DSTEP_FLAGS+= -DWOLFSSL_BIGINT_TYPES
#WOLFSSL_DSTEP_FLAGS+= -DFP_64BIT
#WOLFSSL_DSTEP_FLAGS+= -DOPENSSL_EXTRA

#
# Modules in wolfssl/c 
#
#WOLFSSL_HFILES+=$(DSRC_WOLFSSL)/wolfssl/crl.h
#WOLFSSL_HFILES += $(DSRC_WOLFSSL)/wolfssl/ocsp.h
#WOLFSSL_HFILES += $(DSRC_WOLFSSL)/wolfssl/certs_test.h
WOLFSSL_HFILES += $(DSRC_WOLFSSL)/wolfssl/ssl.h
#WOLFSSL_HFILES += $(DSRC_WOLFSSL)/wolfssl/quic.h
WOLFSSL_HFILES += $(DSRC_WOLFSSL)/wolfssl/version.h
#WOLFSSL_HFILES += $(DSRC_WOLFSSL)/wolfssl/internal.h
#WOLFSSL_HFILES += $(DSRC_WOLFSSL)/wolfssl/sniffer_error.h
WOLFSSL_HFILES += $(DSRC_WOLFSSL)/wolfssl/callbacks.h
WOLFSSL_HFILES += $(DSRC_WOLFSSL)/wolfssl/error_ssl.h

$(DSRC_WOLFSSL)/wolfssl/error_ssl.h: $(DSRC_WOLFSSL)/wolfssl/error-ssl.h
	$(LN) $< $@


$(WOLFSSL_DIROOT)/ssl.di: DSTEPFLAGS+=--global-import core.stdc.stdarg 
$(WOLFSSL_DIROOT)/ssl.di: DSTEPFLAGS+=--global-import $(WOLFSSL_PACKAGE).wolfcrypt.settings
$(WOLFSSL_DIROOT)/ssl.di: DSTEPFLAGS+=--global-import $(WOLFSSL_PACKAGE).wolfssl_version
$(WOLFSSL_DIROOT)/ssl.di: DSTEPFLAGS+=--global-import $(WOLFSSL_PACKAGE).wolfcrypt.asn_public
$(WOLFSSL_DIROOT)/ssl.di: DSTEPFLAGS+=--global-import $(WOLFSSL_PACKAGE).wolfcrypt.types
$(WOLFSSL_DIROOT)/ssl.di: DSTEPFLAGS+=--global-import $(WOLFSSL_PACKAGE).wolfcrypt.random
$(WOLFSSL_DIROOT)/ssl.di: DSTEPFLAGS+=--global-import $(WOLFSSL_PACKAGE).callbacks
$(WOLFSSL_DIROOT)/ssl.di: DSTEPFLAGS+=--global-import $(WOLFSSL_PACKAGE).wolfcrypt.wc_port
#$(WOLFSSL_DIROOT)/ssl.di: DSTEPFLAGS+=--global-import $(WOLFSSL_PACKAGE).openssl.evp
$(WOLFSSL_DIROOT)/ssl.di: DSTEPFLAGS+=--global-import $(WOLFSSL_PACKAGE).openssl.compat_types
$(WOLFSSL_DIROOT)/ssl.di: DSTEP_POSTCORRECT+=$(WOLFSSL_POSTCORRECT)/correct_ssl.pl
#
# Modules in wolfssl/c/wolfcrypt
#

${call DSTEP_DO,$(WOLFSSL_PACKAGE),$(DSRC_WOLFSSL)/wolfssl,$(WOLFSSL_DIROOT),$(WOLFSSL_DFILES),$(WOLFSSL_DSTEP_FLAGS), $(WOLFSSL_HFILES)}

WOLFCRYPT_PACKAGE := tagion.network.wolfssl.c.wolfcrypt
WOLFCRYPT_DIROOT := ${call dir.resolve_1, wolfssl/c/wolfcrypt}

WOLFCRYPT_DFILES := ${shell find ${call dir.resolve, tagion/network} -name "*.d"}

WOLFCRYPT_HFILES+=$(DSRC_WOLFSSL)/wolfssl/wolfcrypt/settings.h
WOLFCRYPT_HFILES+=$(DSRC_WOLFSSL)/wolfssl/wolfcrypt/asn_public.h
WOLFCRYPT_HFILES+=$(DSRC_WOLFSSL)/wolfssl/wolfcrypt/types.h
WOLFCRYPT_HFILES+=$(DSRC_WOLFSSL)/wolfssl/wolfcrypt/dsa.h
WOLFCRYPT_HFILES+=$(DSRC_WOLFSSL)/wolfssl/wolfcrypt/random.h
#WOLFCRYPT_HFILES+=$(DSRC_WOLFSSL)/wolfssl/wolfcrypt/callbacks.h
WOLFCRYPT_HFILES+=$(DSRC_WOLFSSL)/wolfssl/wolfcrypt/integer.h
WOLFCRYPT_HFILES+=$(DSRC_WOLFSSL)/wolfssl/wolfcrypt/memory.h
WOLFCRYPT_HFILES+=$(DSRC_WOLFSSL)/wolfssl/wolfcrypt/wc_port.h
WOLFCRYPT_HFILES+=$(DSRC_WOLFSSL)/wolfssl/wolfcrypt/hmac.h
WOLFCRYPT_HFILES+=$(DSRC_WOLFSSL)/wolfssl/wolfcrypt/aes.h
WOLFCRYPT_HFILES+=$(DSRC_WOLFSSL)/wolfssl/wolfcrypt/des3.h
WOLFCRYPT_HFILES+=$(DSRC_WOLFSSL)/wolfssl/wolfcrypt/sha256.h
WOLFCRYPT_HFILES+=$(DSRC_WOLFSSL)/wolfssl/wolfcrypt/md5.h
WOLFCRYPT_HFILES+=$(DSRC_WOLFSSL)/wolfssl/wolfcrypt/sha.h
WOLFCRYPT_HFILES+=$(DSRC_WOLFSSL)/wolfssl/wolfcrypt/arc4.h
WOLFCRYPT_HFILES+=$(DSRC_WOLFSSL)/wolfssl/wolfcrypt/tfm.h
#WOLFCRYPT_HFILES+=$(DSRC_WOLFSSL)/wolfssl/wolfcrypt/hash.h

${call DSTEP_DO,$(WOLFCRYPT_PACKAGE),$(DSRC_WOLFSSL)/wolfssl/wolfcrypt,$(WOLFCRYPT_DIROOT),$(WOLFCRYPT_DFILES),$(WOLFSSL_DSTEP_FLAGS), $(WOLFCRYPT_HFILES)}

$(WOLFSSL_DIROOT)/wolfcrypt/types.di: DSTEP_POSTCORRECT+=$(WOLFSSL_POSTCORRECT)/correct_types.pl
$(WOLFSSL_DIROOT)/wolfcrypt/random.di: DSTEP_POSTCORRECT+=$(WOLFSSL_POSTCORRECT)/correct_number.pl

$(WOLFSSL_DIROOT)/wolfcrypt/asn_public.di: DSTEPFLAGS+=--global-import $(WOLFSSL_PACKAGE).wolfcrypt.types
$(WOLFSSL_DIROOT)/wolfcrypt/asn_public.di: DSTEPFLAGS+=--global-import $(WOLFSSL_PACKAGE).wolfcrypt.dsa
$(WOLFSSL_DIROOT)/wolfcrypt/asn_public.di: DSTEPFLAGS+=--global-import $(WOLFSSL_PACKAGE).wolfcrypt.random
$(WOLFSSL_DIROOT)/wolfcrypt/asn_public.di: DSTEP_POSTCORRECT+=$(WOLFSSL_POSTCORRECT)/correct_asn_public.pl

$(WOLFSSL_DIROOT)/wolfcrypt/dsa.di: DSTEPFLAGS+=--global-import $(WOLFSSL_PACKAGE).wolfcrypt.types
$(WOLFSSL_DIROOT)/wolfcrypt/dsa.di: DSTEPFLAGS+=--global-import $(WOLFSSL_PACKAGE).wolfcrypt.random
$(WOLFSSL_DIROOT)/wolfcrypt/dsa.di: DSTEPFLAGS+=--global-import $(WOLFSSL_PACKAGE).wolfcrypt.integer
$(WOLFSSL_DIROOT)/wolfcrypt/dsa.di: DSTEPFLAGS+=--global-import $(WOLFSSL_PACKAGE).wolfcrypt.tfm
$(WOLFSSL_DIROOT)/wolfcrypt/dsa.di: DSTEPFLAGS+=--global-import $(WOLFSSL_PACKAGE).wolfcrypt.integer
$(WOLFSSL_DIROOT)/wolfcrypt/dsa.di: DSTEP_POSTCORRECT+=$(WOLFSSL_POSTCORRECT)/correct_dsa.pl

$(WOLFSSL_DIROOT)/wolfcrypt/random.di: DSTEPFLAGS+=--global-import $(WOLFSSL_PACKAGE).wolfcrypt.types

$(WOLFSSL_DIROOT)/wolfcrypt/memory.di: DSTEPFLAGS+=--global-import $(WOLFSSL_PACKAGE).wolfcrypt.types
$(WOLFSSL_DIROOT)/wolfcrypt/memory.di: DSTEP_POSTCORRECT+=$(WOLFSSL_POSTCORRECT)/correct_memory.pl

$(WOLFSSL_DIROOT)/wolfcrypt/wc_port.di: DSTEP_POSTCORRECT+=$(WOLFSSL_POSTCORRECT)/correct_wc_port.pl

$(WOLFSSL_DIROOT)/wolfcrypt/hmac.di: DSTEPFLAGS+=--global-import $(WOLFSSL_PACKAGE).wolfcrypt.types
$(WOLFSSL_DIROOT)/wolfcrypt/hmac.di: DSTEPFLAGS+=--global-import $(WOLFSSL_PACKAGE).wolfcrypt.md5
$(WOLFSSL_DIROOT)/wolfcrypt/hmac.di: DSTEPFLAGS+=--global-import $(WOLFSSL_PACKAGE).wolfcrypt.sha256
$(WOLFSSL_DIROOT)/wolfcrypt/hmac.di: DSTEPFLAGS+=--global-import $(WOLFSSL_PACKAGE).wolfcrypt.sha

$(WOLFSSL_DIROOT)/wolfcrypt/aes.di: DSTEPFLAGS+=--global-import $(WOLFSSL_PACKAGE).wolfcrypt.types

$(WOLFSSL_DIROOT)/wolfcrypt/des3.di: DSTEPFLAGS+=--global-import $(WOLFSSL_PACKAGE).wolfcrypt.types
$(WOLFSSL_DIROOT)/wolfcrypt/des3.di: DSTEP_POSTCORRECT+=$(WOLFSSL_POSTCORRECT)/correct_des3.pl

$(WOLFSSL_DIROOT)/wolfcrypt/md5.di: DSTEPFLAGS+=--global-import $(WOLFSSL_PACKAGE).wolfcrypt.types
$(WOLFSSL_DIROOT)/wolfcrypt/md5.di: DSTEP_POSTCORRECT+=$(WOLFSSL_POSTCORRECT)/correct_md5.pl

$(WOLFSSL_DIROOT)/wolfcrypt/sha256.di: DSTEPFLAGS+=--global-import $(WOLFSSL_PACKAGE).wolfcrypt.types

$(WOLFSSL_DIROOT)/wolfcrypt/sha.di: DSTEPFLAGS+=--global-import $(WOLFSSL_PACKAGE).wolfcrypt.types


$(WOLFSSL_DIROOT)/wolfcrypt/tfm.di: DSTEPFLAGS+=--global-import $(WOLFSSL_PACKAGE).wolfcrypt.types
$(WOLFSSL_DIROOT)/wolfcrypt/tfm.di: DSTEPFLAGS+=--global-import $(WOLFSSL_PACKAGE).wolfcrypt.random
$(WOLFSSL_DIROOT)/wolfcrypt/tfm.di: DSTEP_POSTCORRECT+=$(WOLFSSL_POSTCORRECT)/correct_tfm.pl

#
# Modules in wolfssl/c/openssl
#
WOLFSSL_OPENSSL_PACKAGE := tagion.network.wolfssl.c.openssl
WOLFSSL_OPENSSL_DIROOT := ${call dir.resolve_1, wolfssl/c/openssl}

WOLFSSL_OPENSSL_DFILES := ${shell find ${call dir.resolve, tagion/network} -name "*.d"}

#WOLFSSL_OPENSSL_HFILES+=$(DSRC_WOLFSSL)/wolfssl/openssl/evp.h
WOLFSSL_OPENSSL_HFILES+=$(DSRC_WOLFSSL)/wolfssl/openssl/ssl.h
WOLFSSL_OPENSSL_HFILES+=$(DSRC_WOLFSSL)/wolfssl/openssl/compat_types.h
#WOLFSSL_OPENSSL_HFILES+=$(DSRC_WOLFSSL)/wolfssl/openssl/md4.h
#WOLFSSL_OPENSSL_HFILES+=$(DSRC_WOLFSSL)/wolfssl/openssl/md5.h
#WOLFSSL_OPENSSL_HFILES+=$(DSRC_WOLFSSL)/wolfssl/openssl/sha.h
#WOLFSSL_OPENSSL_HFILES+=$(DSRC_WOLFSSL)/wolfssl/openssl/sha3.h
#WOLFSSL_OPENSSL_HFILES+=$(DSRC_WOLFSSL)/wolfssl/openssl/rsa.h
#WOLFSSL_OPENSSL_HFILES+=$(DSRC_WOLFSSL)/wolfssl/openssl/bn.h
#WOLFSSL_OPENSSL_HFILES+=$(DSRC_WOLFSSL)/wolfssl/openssl/dsa.h
#WOLFSSL_OPENSSL_HFILES+=$(DSRC_WOLFSSL)/wolfssl/openssl/sha256.h

${call DSTEP_DO,$(WOLFSSL_OPENSSL_PACKAGE),$(DSRC_WOLFSSL)/wolfssl/openssl,$(WOLFSSL_OPENSSL_DIROOT),$(WOLFSSL_OPENSSL_DFILES),$(WOLFSSL_DSTEP_FLAGS), $(WOLFSSL_OPENSSL_HFILES)}

$(WOLFSSL_DIROOT)/openssl/compat_types.di: DSTEPFLAGS+=--global-import $(WOLFSSL_PACKAGE).wolfcrypt.types
$(WOLFSSL_DIROOT)/openssl/compat_types.di: DSTEPFLAGS+=--global-import $(WOLFSSL_PACKAGE).wolfcrypt.hmac

$(WOLFSSL_DIROOT)/openssl/evp.di: DSTEPFLAGS+=--global-import $(WOLFSSL_PACKAGE).openssl.compat_types
$(WOLFSSL_DIROOT)/openssl/evp.di: DSTEPFLAGS+=--global-import $(WOLFSSL_PACKAGE).openssl.md4
$(WOLFSSL_DIROOT)/openssl/evp.di: DSTEPFLAGS+=--global-import $(WOLFSSL_PACKAGE).openssl.md5
$(WOLFSSL_DIROOT)/openssl/evp.di: DSTEPFLAGS+=--global-import $(WOLFSSL_PACKAGE).openssl.sha
$(WOLFSSL_DIROOT)/openssl/evp.di: DSTEPFLAGS+=--global-import $(WOLFSSL_PACKAGE).openssl.sha3
#$(WOLFSSL_DIROOT)/openssl/evp.di: DSTEPFLAGS+=--global-import $(WOLFSSL_PACKAGE).openssl.rsa
$(WOLFSSL_DIROOT)/openssl/evp.di: DSTEPFLAGS+=--global-import $(WOLFSSL_PACKAGE).wolfcrypt.md5
$(WOLFSSL_DIROOT)/openssl/evp.di: DSTEPFLAGS+=--global-import $(WOLFSSL_PACKAGE).wolfcrypt.sha
$(WOLFSSL_DIROOT)/openssl/evp.di: DSTEPFLAGS+=--global-import $(WOLFSSL_PACKAGE).wolfcrypt.hmac
$(WOLFSSL_DIROOT)/openssl/evp.di: DSTEPFLAGS+=--global-import $(WOLFSSL_PACKAGE).wolfcrypt.aes
$(WOLFSSL_DIROOT)/openssl/evp.di: DSTEPFLAGS+=--global-import $(WOLFSSL_PACKAGE).wolfcrypt.des3
$(WOLFSSL_DIROOT)/openssl/evp.di: DSTEPFLAGS+=--global-import $(WOLFSSL_PACKAGE).wolfcrypt.sha256

$(WOLFSSL_DIROOT)/openssl/md4.di: DSTEP_POSTCORRECT+=$(WOLFSSL_POSTCORRECT)/correct_md4.pl

$(WOLFSSL_DIROOT)/openssl/md5.di: DSTEP_POSTCORRECT+=$(WOLFSSL_POSTCORRECT)/correct_openssl_md5.pl

$(WOLFSSL_DIROOT)/openssl/sha3.di: DSTEP_POSTCORRECT+=$(WOLFSSL_POSTCORRECT)/correct_sha3.pl

$(WOLFSSL_DIROOT)/openssl/rsa.di: DSTEPFLAGS+=--global-import $(WOLFSSL_PACKAGE).wolfcrypt.types
$(WOLFSSL_DIROOT)/openssl/rsa.di: DSTEPFLAGS+=--global-import $(WOLFSSL_PACKAGE).wolfcrypt.tfm
#$(WOLFSSL_DIROOT)/openssl/rsa.di: DSTEPFLAGS+=--global-import $(WOLFSSL_PACKAGE).openssl.bn

find_test=${shell find $(REPOROOT) -type d -path "*wolfcrypt"}


test44:
	echo $(WOLFSSL_DFILES)
	echo $(WOLFCRYPT_DFILES)
	echo $(WOLFSSL_POSTCORRECT)
	echo $(WOLFCRYPT_DIROOT)
	echo 5 $(WOLFSSL_OPENSSL_DIROOT)
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

