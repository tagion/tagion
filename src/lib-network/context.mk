# DEPS += lib-hibon
# DEPS += wrap-wolfssl

ifdef WOLFSSL
DCFLAGS+=$(DVERSION)=WOLFSSL
endif

include ${call dir.resolve, dstep.mk}
