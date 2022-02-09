#
# Secp256k1 DSTEP headers
#
LCRYPTO_PACKAGE := tagion.crypto.secp256k1.c
LCRYPTO_DIROOT := ${call dir.resolve, tagion/crypto/secp256k1/c}

CRYPTO_DFILES := ${shell find ${call dir.resolve, tagion/crypto} -name "*.d"}

$(LCRYPTO_DIROOT)/secp256k1_ecdh.di: DSTEPFLAGS += --global-import=$(LCRYPTO_PACKAGE).secp256k1

${call DSTEP_DO,$(LCRYPTO_PACKAGE),$(DSRC_SECP256K1)/include,$(LCRYPTO_DIROOT),$(CRYPTO_DFILES)}




#$(DIFILES_tagion.crypto.secp256k1.c)

test33: /home/carsten/work/cross_regression/src/lib-crypto/tagion/crypto/SecureNet.d

test34: $(DIFILES_tagion.crypto.secp256k1.c)

test57:
	@echo $(DSRC_SECP256K1)/include
	@echo HFILES.tagion.crypto.secp256k1.c=$(HFILES.tagion.crypto.secp256k1.c)
	@echo DIFILES.tagion.crypto.secp256k1.c=$(DIFILES.tagion.crypto.secp256k1.c)
	@echo LCRYPTO_DIROOT=$(LCRYPTO_DIROOT)
	@echo CRYPTO_DFILES $(CRYPTO_DFILES)

#env-crypto:
# 	$(PRECMD)
# 	${call log.header, $@ :: env}
# 	${call $(DSRC_SECP256K1)
