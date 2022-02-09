#
# Secp256k1 DSTEP headers
#
LCRYPTO_PACKAGE := tagion.crypto.secp256k1.c
LCRYPTO_DIROOT := ${call dir.resolve, tagion/crypto/secp256k1/c}

CRYPTO_DFILES := ${shell find ${call dir.resolve, tagion/crypto} -name "*.d"}

$(LCRYPTO_DIROOT)/secp256k1_ecdh.di: DSTEPFLAGS += --global-import=$(LCRYPTO_PACKAGE).secp256k1

${call DSTEP_DO,$(LCRYPTO_PACKAGE),$(DSRC_SECP256K1)/include,$(LCRYPTO_DIROOT),$(CRYPTO_DFILES)}
