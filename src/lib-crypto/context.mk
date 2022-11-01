
include ${call dir.resolve, dstep.mk}


ifdef TINY_AES
DCFLAGS+=$(DVERSION)=TINY_AES
endif

DFILES_NATIVESECP256K1=${shell find $(DSRC)/lib-crypto -name "*.d"}
