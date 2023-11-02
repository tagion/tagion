#
# Network DSTEP headers
#
ifdef WOLFSSL
WOLFSSL_POSTCORRECT=${call dir.match, lib-network/scripts}

WOLFSSL_PACKAGE := tagion.network.wolfssl.c
WOLFSSL_DIROOT := ${call dir.match, tagion/network/wolfssl/c}

# WOLFSSL_DFILES := ${shell find ${call dir.resolve, tagion/network} -name "*.d" -a -not -path "*/wolfssl/*" }

WOLFSSL_DSTEP_FLAGS+=-I$(DSRC_WOLFSSL)
WOLFSSL_DSTEP_FLAGS+= -DUSE_FAST_MATH=1
WOLFSSL_DSTEP_FLAGS+= -DWC_NO_HARDEN=1
WOLFSSL_DSTEP_FLAGS+= -DWOLFSSL_PUB_PEM_TO_DER=1

#
# Modules in wolfssl/c
#
WOLFSSL_HFILES += $(DSRC_WOLFSSL)/wolfssl/ssl.h
WOLFSSL_HFILES += $(DSRC_WOLFSSL)/wolfssl/wolfssl_version.h
WOLFSSL_HFILES += $(DSRC_WOLFSSL)/wolfssl/callbacks.h
WOLFSSL_HFILES += $(DSRC_WOLFSSL)/wolfssl/error_ssl.h

$(DSRC_WOLFSSL)/wolfssl/error_ssl.h: $(DSRC_WOLFSSL)/wolfssl/error-ssl.h
	$(PRECMD)
	$(LN) $< $@

$(DSRC_WOLFSSL)/wolfssl/wolfssl_version.h: $(DSRC_WOLFSSL)/wolfssl/version.h
	$(PRECMD)
	$(LN) $< $@

$(DSRC_WOLFSSL)/wolfssl/wolfcrypt/error_crypt.h: $(DSRC_WOLFSSL)/wolfssl/wolfcrypt/error-crypt.h
	$(PRECMD)
	$(LN) $< $@

$(WOLFSSL_DIROOT)/%.d: $(WOLFSSL_DIROOT)/%.di
	$(PRECMD)
	$(LN) $< $@

clean-wolfssl-link:
	$(RM) $(DSRC_WOLFSSL)/wolfssl/error_ssl.h
	$(RM) $(DSRC_WOLFSSL)/wolfssl/wolfssl_version.h
	$(RM) $(DSRC_WOLFSSL)/wolfssl/wolfcrypt/error_crypt.h


.PHONY: clean-wolfssl-link

clean-dstep: clean-wolfssl-link

xxxx:
	echo ok

$(WOLFSSL_DIROOT)/ssl.di: DSTEP_DLINK=1
$(WOLFSSL_DIROOT)/ssl.di: DSTEPFLAGS+=--collision-action=ignore
$(WOLFSSL_DIROOT)/ssl.di: DSTEPFLAGS+=--global-import core.stdc.stdarg
$(WOLFSSL_DIROOT)/ssl.di: DSTEPFLAGS+=--global-import $(WOLFSSL_PACKAGE).wolfcrypt.settings
$(WOLFSSL_DIROOT)/ssl.di: DSTEPFLAGS+=--global-import $(WOLFSSL_PACKAGE).wolfssl_version
$(WOLFSSL_DIROOT)/ssl.di: DSTEPFLAGS+=--global-import $(WOLFSSL_PACKAGE).wolfcrypt.asn_public
$(WOLFSSL_DIROOT)/ssl.di: DSTEPFLAGS+=--global-import $(WOLFSSL_PACKAGE).wolfcrypt.types
$(WOLFSSL_DIROOT)/ssl.di: DSTEPFLAGS+=--global-import $(WOLFSSL_PACKAGE).wolfcrypt.random
$(WOLFSSL_DIROOT)/ssl.di: DSTEPFLAGS+=--global-import $(WOLFSSL_PACKAGE).callbacks
$(WOLFSSL_DIROOT)/ssl.di: DSTEPFLAGS+=--global-import $(WOLFSSL_PACKAGE).wolfcrypt.wc_port
$(WOLFSSL_DIROOT)/ssl.di: DSTEPFLAGS+=--global-import $(WOLFSSL_PACKAGE).openssl.compat_types
$(WOLFSSL_DIROOT)/ssl.di: DSTEP_POSTCORRECT+=$(WOLFSSL_POSTCORRECT)/correct_ssl.pl

#
# Modules in wolfssl/c/wolfcrypt
#
${call DSTEP_DO,$(WOLFSSL_PACKAGE),$(DSRC_WOLFSSL)/wolfssl,$(WOLFSSL_DIROOT),$(WOLFSSL_DFILES),$(WOLFSSL_DSTEP_FLAGS), $(WOLFSSL_HFILES)}

WOLFCRYPT_PACKAGE := tagion.network.wolfssl.c.wolfcrypt
WOLFCRYPT_DIROOT := ${call dir.match, wolfssl/c/wolfcrypt}

# WOLFCRYPT_DFILES := ${shell find ${call dir.resolve, tagion/network} -name "*.d" -a -not -path "*/wolfssl/*" }

WOLFCRYPT_HFILES+=$(DSRC_WOLFSSL)/wolfssl/wolfcrypt/settings.h
WOLFCRYPT_HFILES+=$(DSRC_WOLFSSL)/wolfssl/wolfcrypt/asn_public.h
WOLFCRYPT_HFILES+=$(DSRC_WOLFSSL)/wolfssl/wolfcrypt/types.h
WOLFCRYPT_HFILES+=$(DSRC_WOLFSSL)/wolfssl/wolfcrypt/dsa.h
WOLFCRYPT_HFILES+=$(DSRC_WOLFSSL)/wolfssl/wolfcrypt/random.h
WOLFCRYPT_HFILES+=$(DSRC_WOLFSSL)/wolfssl/wolfcrypt/integer.h
WOLFCRYPT_HFILES+=$(DSRC_WOLFSSL)/wolfssl/wolfcrypt/wc_port.h
WOLFCRYPT_HFILES+=$(DSRC_WOLFSSL)/wolfssl/wolfcrypt/tfm.h
WOLFCRYPT_HFILES+=$(DSRC_WOLFSSL)/wolfssl/wolfcrypt/error_crypt.h

${call DSTEP_DO,$(WOLFCRYPT_PACKAGE),$(DSRC_WOLFSSL)/wolfssl/wolfcrypt,$(WOLFCRYPT_DIROOT),$(WOLFCRYPT_DFILES),$(WOLFSSL_DSTEP_FLAGS), $(WOLFCRYPT_HFILES)}

$(WOLFSSL_DIROOT)/wolfcrypt/types.di: DSTEP_DLINK=1
$(WOLFSSL_DIROOT)/wolfcrypt/types.di: DSTEP_POSTCORRECT+=$(WOLFSSL_POSTCORRECT)/correct_types.pl
$(WOLFSSL_DIROOT)/wolfcrypt/types.di: DSTEPFLAGS+=--global-import core.stdc.string

$(WOLFSSL_DIROOT)/wolfcrypt/random.di: DSTEP_DLINK=1
$(WOLFSSL_DIROOT)/wolfcrypt/random.di: DSTEP_POSTCORRECT+=$(WOLFSSL_POSTCORRECT)/correct_number.pl

$(WOLFSSL_DIROOT)/wolfcrypt/asn_public.di: DSTEP_DLINK=1
$(WOLFSSL_DIROOT)/wolfcrypt/asn_public.di: DSTEPFLAGS+=--global-import $(WOLFSSL_PACKAGE).wolfcrypt.types
$(WOLFSSL_DIROOT)/wolfcrypt/asn_public.di: DSTEPFLAGS+=--global-import $(WOLFSSL_PACKAGE).wolfcrypt.dsa
$(WOLFSSL_DIROOT)/wolfcrypt/asn_public.di: DSTEPFLAGS+=--global-import $(WOLFSSL_PACKAGE).wolfcrypt.random
$(WOLFSSL_DIROOT)/wolfcrypt/asn_public.di: DSTEP_POSTCORRECT+=$(WOLFSSL_POSTCORRECT)/correct_asn_public.pl

$(WOLFSSL_DIROOT)/wolfcrypt/dsa.di: DSTEP_DLINK=1
$(WOLFSSL_DIROOT)/wolfcrypt/dsa.di: DSTEPFLAGS+=--global-import $(WOLFSSL_PACKAGE).wolfcrypt.types
$(WOLFSSL_DIROOT)/wolfcrypt/dsa.di: DSTEPFLAGS+=--global-import $(WOLFSSL_PACKAGE).wolfcrypt.random
$(WOLFSSL_DIROOT)/wolfcrypt/dsa.di: DSTEPFLAGS+=--global-import $(WOLFSSL_PACKAGE).wolfcrypt.integer
$(WOLFSSL_DIROOT)/wolfcrypt/dsa.di: DSTEPFLAGS+=--global-import $(WOLFSSL_PACKAGE).wolfcrypt.tfm
$(WOLFSSL_DIROOT)/wolfcrypt/dsa.di: DSTEPFLAGS+=--global-import $(WOLFSSL_PACKAGE).wolfcrypt.integer
$(WOLFSSL_DIROOT)/wolfcrypt/dsa.di: DSTEP_POSTCORRECT+=$(WOLFSSL_POSTCORRECT)/correct_dsa.pl

$(WOLFSSL_DIROOT)/wolfcrypt/random.di: DSTEP_DLINK=1
$(WOLFSSL_DIROOT)/wolfcrypt/random.di: DSTEPFLAGS+=--global-import $(WOLFSSL_PACKAGE).wolfcrypt.types

$(WOLFSSL_DIROOT)/wolfcrypt/wc_port.di: DSTEP_DLINK=1
$(WOLFSSL_DIROOT)/wolfcrypt/wc_port.di: DSTEP_POSTCORRECT+=$(WOLFSSL_POSTCORRECT)/correct_wc_port.pl

$(WOLFSSL_DIROOT)/wolfcrypt/aes.di: DSTEP_DLINK=1
$(WOLFSSL_DIROOT)/wolfcrypt/aes.di: DSTEPFLAGS+=--global-import $(WOLFSSL_PACKAGE).wolfcrypt.types

$(WOLFSSL_DIROOT)/wolfcrypt/tfm.di: DSTEP_DLINK=1
$(WOLFSSL_DIROOT)/wolfcrypt/tfm.di: DSTEPFLAGS+=--global-import $(WOLFSSL_PACKAGE).wolfcrypt.types
$(WOLFSSL_DIROOT)/wolfcrypt/tfm.di: DSTEPFLAGS+=--global-import $(WOLFSSL_PACKAGE).wolfcrypt.random
$(WOLFSSL_DIROOT)/wolfcrypt/tfm.di: DSTEP_POSTCORRECT+=$(WOLFSSL_POSTCORRECT)/correct_tfm.pl

$(WOLFSSL_DIROOT)/wolfcrypt/error_crypt.di: DSTEP_POSTCORRECT+=$(WOLFSSL_POSTCORRECT)/correct_error_crypt.pl

#
# Modules in wolfssl/c/openssl
#
WOLFSSL_OPENSSL_PACKAGE := tagion.network.wolfssl.c.openssl
WOLFSSL_OPENSSL_DIROOT := ${call dir.match, wolfssl/c/openssl}

# WOLFSSL_OPENSSL_DFILES := ${shell find ${call dir.resolve, tagion/network} -name "*.d" -a -not -path "*/wolfssl/*" }

WOLFSSL_OPENSSL_HFILES+=$(DSRC_WOLFSSL)/wolfssl/openssl/compat_types.h

${call DSTEP_DO,$(WOLFSSL_OPENSSL_PACKAGE),$(DSRC_WOLFSSL)/wolfssl/openssl,$(WOLFSSL_OPENSSL_DIROOT),$(WOLFSSL_OPENSSL_DFILES),$(WOLFSSL_DSTEP_FLAGS), $(WOLFSSL_OPENSSL_HFILES)}

$(WOLFSSL_DIROOT)/openssl/compat_types.di: DSTEP_DLINK=1
$(WOLFSSL_DIROOT)/openssl/compat_types.di: DSTEPFLAGS+=--global-import $(WOLFSSL_PACKAGE).wolfcrypt.types
$(WOLFSSL_DIROOT)/openssl/compat_types.di: DSTEP_POSTCORRECT+=$(WOLFSSL_POSTCORRECT)/correct_compat_types.pl

find_test=${shell find $(REPOROOT) -type d -path "*wolfcrypt"}

#
# Adds the .di files as .d modules. For some reason some of the file here need a __ModuleInfo symbol
#
# DFILES+=${shell find $(WOLFSSL_DIROOT) -name "*.d"}

endif
