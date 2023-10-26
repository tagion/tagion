#
# Secp256k1 DSTEP headers
#
LCRYPTO_PACKAGE := tagion.crypto.secp256k1.c
LCRYPTO_DIROOT := ${call dir.resolve, tagion/crypto/secp256k1/c}

CRYPTO_DFILES := ${shell find ${call dir.resolve, tagion/crypto} -name "*.d"}

$(LCRYPTO_DIROOT)/secp256k1_ecdh.di: DSTEPFLAGS += --global-import=$(LCRYPTO_PACKAGE).secp256k1
$(LCRYPTO_DIROOT)/secp256k1_schnorrsig.di: DSTEPFLAGS += --global-import=$(LCRYPTO_PACKAGE).secp256k1
$(LCRYPTO_DIROOT)/secp256k1_schnorrsig.di: DSTEPFLAGS += --global-import=$(LCRYPTO_PACKAGE).secp256k1_extrakeys
$(LCRYPTO_DIROOT)/secp256k1_extrakeys.di: DSTEPFLAGS += --global-import=$(LCRYPTO_PACKAGE).secp256k1
$(LCRYPTO_DIROOT)/secp256k1_musig.di: DSTEPFLAGS += --global-import=$(LCRYPTO_PACKAGE).secp256k1
$(LCRYPTO_DIROOT)/secp256k1_musig.di: DSTEPFLAGS += --global-import=$(LCRYPTO_PACKAGE).secp256k1_schnorrsig
$(LCRYPTO_DIROOT)/secp256k1_musig.di: DSTEPFLAGS += --global-import=$(LCRYPTO_PACKAGE).secp256k1_extrakeys

${call DSTEP_DO,$(LCRYPTO_PACKAGE),$(DSRC_SECP256K1)/include,$(LCRYPTO_DIROOT),$(CRYPTO_DFILES)}

