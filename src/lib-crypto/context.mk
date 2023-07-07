
include ${call dir.resolve, dstep.mk}


ifdef TINY_AES
DCFLAGS+=$(DVERSION)=TINY_AES
endif

DFILES_NATIVESECP256K1=${shell find $(DSRC)/lib-crypto -name "*.d"}

SEC256k1_WRAPPER_SRC=$(DSRC)/lib-crypto/tagion/crypto/secp256k1/secp256k1_sha256_wrapper.c
SEC256k1_WRAPPER_OBJ=$(DTMP)/secp256k1_sha256_wrapper.$(OBJEXT)

$(SEC256k1_WRAPPER_OBJ): CFLAGS+=-I $(DSRC)/wrap-secp256k1/secp256k1/src/
$(SEC256k1_WRAPPER_OBJ): CFLAGS+=-I $(DSRC)/wrap-secp256k1/secp256k1/include/

secp256k1-wrapper: $(SEC256k1_WRAPPER_OBJ)

test88:
	echo $(SEC256k1_WRAPPER_OBJ)

$(SEC256k1_WRAPPER_OBJ): $(SEC256k1_WRAPPER_SRC)
	$(CC) $(CFLAGS) -c $< -o $@


#src/lib-crypto/tagion/crypto/secp256k1/secp256k1_sha256_wrapper.c
