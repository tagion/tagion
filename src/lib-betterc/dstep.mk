
# BETTERC_CRYPTO_PACKAGE := tagion.betterC.crypto.c
# BETTERC_CRYPTO_DIROOT := ${call dir.resolve, tagion/betterC/crypto/c}

# BETTERC_CRYPTO_DFILES := ${shell find ${call dir.resolve, tagion/betterC/wallet} -name "*.d"}

# $(BETTERC_CRYPTO_DIROOT): DSTEPFLAGS += --global-import=$(BETTERC_CRYPTO_DIROOT).hash

# ${call DSTEP_DO,$(BETTERC_CRYPTO_PACKAGE),$(DSRC_SECP256K1)/src/hash.h,$(BETTERC_CRYPTO_DIROOT),$(BETTERC_CRYPTO_DFILES)}
