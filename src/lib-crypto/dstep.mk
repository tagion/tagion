#
# Secp256k1 DSTEP headers
#
LCRYPTO_PACKAGE := tagion.crypto.secp256k1.c
LCRYPTO_DIROOT := ${call dir.resolve, tagion/crypto/secp256k1/c}

CRYPTO_DFILES := ${wildcard ${call dir.resolve, tagion/crypto}/*.d}

$(LCRYPTO_DIROOT)/secp256k1_ecdh.di: DSTEPFLAGS += --global-import=$(LCRYPTO_PACKAGE).secp256k1

${call DSTEP_DO,$(LCRYPTO_PACKAGE),$(DSRC_SECP256K1)/include,$(LCRYPTO_DIROOT),$(CRYPTO_DFILES)}




#$(DIFILES_tagion.crypto.secp256k1.c)

test33: /home/carsten/work/cross_regression/src/lib-crypto/tagion/crypto/SecureNet.d

test34: $(DIFILES_tagion.crypto.secp256k1.c)

test77:
	@echo $(DSRC_SECP256K1)/include
	@echo $(HFILES_tagion.crypto.secp256k1.c)
	@echo $(DIFILES_tagion.crypto.secp256k1.c)
	@echo $(LCRYPTO_DIROOT)
	@echo CRYPTO_DFILES $(CRYPTO_DFILES)
