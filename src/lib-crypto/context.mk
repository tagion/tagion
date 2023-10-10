
include ${call dir.resolve, dstep.mk}


DFILES_NATIVESECP256K1=${shell find $(DSRC)/lib-crypto -name "*.d"}

ifdef SECP256K1_HASH
SEC256k1_WRAPPER_SRC=$(DSRC)/lib-crypto/tagion/crypto/secp256k1/secp256k1_sha256_wrapper.c
SEC256k1_WRAPPER_OBJ=$(DTMP)/secp256k1_sha256_wrapper.$(OBJEXT)

$(SEC256k1_WRAPPER_OBJ): CFLAGS+=-I $(DSRC)/wrap-secp256k1/secp256k1/src/
$(SEC256k1_WRAPPER_OBJ): CFLAGS+=-I $(DSRC)/wrap-secp256k1/secp256k1/include/

secp256k1-sha256: $(SEC256k1_WRAPPER_OBJ)

$(SEC256k1_WRAPPER_OBJ): $(SEC256k1_WRAPPER_SRC)
	$(PRECMD)
	$(call log.header, $(@F) :: compile)
	$(CC) $(CFLAGS) -c $< -o $@


proper-secp256k1-sha256:
	$(PRECMD)
	${call log.header, $@ :: proper}
	$(RM) $(SEC256k1_WRAPPER_OBJ)

.PHONY: proper-secp256k1-sha256

secp256k1: $(SEC256k1_WRAPPER_OBJ)

endif
