# DEPS += lib-hibon
# DEPS += wrap-wolfssl

ifdef WOLFSSL
DCFLAGS+=$(DVERSION)=WOLFSSL
DCFLAGS+=$(DVERSION)=TINY_AES
endif

include ${call dir.resolve, dstep.mk}
